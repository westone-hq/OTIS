package com.otis.vibration_checker.verify

import android.content.Context
import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.EventChannel
import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.util.Locale

/**
 * 일반 FASTEST와 FASTEST+HandlerThread를 동시에 실행한다.
 *
 * 반환 파일:
 * - fastestRaw / fastest256
 * - handlerRaw / handler256
 * - requested256 / requested128 / requested64
 *
 * 이 파일의 역할:
 * 1. 일반 FASTEST·HandlerThread·주파수별 독립 요청 Core의 콜백을 연결한다.
 * 2. 측정 중에는 본문을 cache의 임시 파일에 계속 기록한다.
 * 3. 중지하면 통계 헤더와 본문을 합쳐 7개 txt 경로를 Flutter에 반환한다.
 * 4. 약 1초마다 EventChannel로 화면 통계를 보낸다.
 *
 * 센서 수신·통계·보간 계산 자체는 각 Core에 있고, 이 Handler는 연결과 출력만 담당한다.
 */
class FastestVerifyHandler(
    private val context: Context,
) : EventChannel.StreamHandler {
    companion object {
        const val TARGET_HZ = 256
        private const val MPS2_TO_MG = 101.97162129779283
    }

    /** 한 측정 방식의 원본 파일과 256Hz 파일에 필요한 임시/최종 출력 묶음이다. */
    private data class OutputSet(
        val originalBody: File,
        val processedBody: File,
        val originalOutput: File,
        val processedOutput: File,
        var originalWriter: BufferedWriter,
        var processedWriter: BufferedWriter,
        var processedCount: Long = 0,
        var lastStatsNs: Long = 0,
    )

    /** 256/128/64Hz 독립 요청 원본 파일 하나에 필요한 출력 상태다. */
    private data class RequestedOutput(
        val body: File,
        val output: File,
        var writer: BufferedWriter,
    )

    /** 별도 요청 결과 파일 헤더에 기록할 센서 하나의 실측 통계다. */
    private data class RequestedSensorStats(
        val count: Long,
        val meanUs: Double,
        val minUs: Double,
        val maxUs: Double,
        val measuredHz: Double,
    )

    // EventChannel은 Flutter UI와 연결되므로 메인 스레드에서 success를 호출한다.
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var fastestCore: Fastest256Core? = null
    private var handlerCore: HandlerThread256Core? = null
    private var requested256Core: Requested256HzCore? = null
    private var requested128Core: Requested128HzCore? = null
    private var requested64Core: Requested64HzCore? = null
    private var fastestOutput: OutputSet? = null
    private var handlerOutput: OutputSet? = null
    private val requestedOutputs = linkedMapOf<Int, RequestedOutput>()

    fun start(targetHz: Int): Boolean {
        // 이전 측정이 남아 있으면 정리하고 모든 출력 파일을 같은 stamp로 연다.
        stop()
        val stamp = System.currentTimeMillis()
        fastestOutput = openOutputSet("fastest", stamp) ?: return false
        handlerOutput =
            openOutputSet("handler_thread", stamp)
                ?: run {
                    closeAndDelete(fastestOutput)
                    fastestOutput = null
                    return false
                }
        if (!openRequestedOutputs(stamp)) {
            closeAndDelete(fastestOutput)
            closeAndDelete(handlerOutput)
            fastestOutput = null
            handlerOutput = null
            return false
        }

        fastestCore =
            Fastest256Core(
                context = context,
                onOriginal = ::writeFastestOriginal,
                onResampled = ::writeFastestProcessed,
            )
        handlerCore =
            HandlerThread256Core(
                context = context,
                onOriginal = ::writeHandlerOriginal,
                onResampled = ::writeHandlerProcessed,
            )
        // 세 주파수는 FASTEST 원본을 공유하지 않고 각자 SensorManager에 별도 등록한다.
        requested256Core = Requested256HzCore(context, ::writeRequested256Original)
        requested128Core = Requested128HzCore(context, ::writeRequested128Original)
        requested64Core = Requested64HzCore(context, ::writeRequested64Original)

        // 일곱 출력 흐름을 같은 검증 구간에 시작한다.
        val fastestStarted = fastestCore?.start() == true
        val handlerStarted = handlerCore?.start() == true
        val requested256Started = requested256Core?.start() == true
        val requested128Started = requested128Core?.start() == true
        val requested64Started = requested64Core?.start() == true
        if (
            !fastestStarted ||
            !handlerStarted ||
            !requested256Started ||
            !requested128Started ||
            !requested64Started
        ) {
            fastestCore?.stop()
            handlerCore?.stop()
            requested256Core?.stop()
            requested128Core?.stop()
            requested64Core?.stop()
            fastestCore = null
            handlerCore = null
            requested256Core = null
            requested128Core = null
            requested64Core = null
            closeAndDelete(fastestOutput)
            closeAndDelete(handlerOutput)
            closeAndDeleteRequestedOutputs()
            fastestOutput = null
            handlerOutput = null
            return false
        }
        return true
    }

    fun stop(): Map<String, String> {
        val activeFastest = fastestCore
        val activeHandler = handlerCore
        val activeRequested256 = requested256Core
        val activeRequested128 = requested128Core
        val activeRequested64 = requested64Core
        if (
            activeFastest == null &&
            activeHandler == null &&
            activeRequested256 == null &&
            activeRequested128 == null &&
            activeRequested64 == null
        ) {
            return emptyMap()
        }

        // Writer를 닫기 전에 센서 콜백부터 중단해 기록 중 충돌을 막는다.
        activeFastest?.stop()
        activeHandler?.stop()
        activeRequested256?.stop()
        activeRequested128?.stop()
        activeRequested64?.stop()
        fastestCore = null
        handlerCore = null
        requested256Core = null
        requested128Core = null
        requested64Core = null
        closeOutput(fastestOutput)
        closeOutput(handlerOutput)
        closeRequestedOutputs()

        // 임시 본문 앞에 통계/컬럼 헤더를 붙여 최종 txt를 만든다.
        val fastestRaw =
            buildFastestOriginal(activeFastest, fastestOutput)
        val fastest256 =
            buildProcessed("SENSOR_DELAY_FASTEST 원본의 256Hz 보간", fastestOutput)
        val handlerRaw =
            buildHandlerOriginal(activeHandler, handlerOutput)
        val handler256 =
            buildProcessed("FASTEST+HandlerThread 원본의 256Hz 보간", handlerOutput)
        val requested256 = buildRequested256(activeRequested256)
        val requested128 = buildRequested128(activeRequested128)
        val requested64 = buildRequested64(activeRequested64)

        cleanupBodies(fastestOutput)
        cleanupBodies(handlerOutput)
        cleanupRequestedOutputs()
        fastestOutput = null
        handlerOutput = null

        // 7개 중 하나라도 실패하면 일부 경로를 성공처럼 반환하지 않는다.
        return if (
            fastestRaw != null &&
            fastest256 != null &&
            handlerRaw != null &&
            handler256 != null &&
            requested256 != null &&
            requested128 != null &&
            requested64 != null
        ) {
            linkedMapOf(
                "fastestRaw" to fastestRaw,
                "fastest256" to fastest256,
                "handlerRaw" to handlerRaw,
                "handler256" to handler256,
                "requested256" to requested256,
                "requested128" to requested128,
                "requested64" to requested64,
            )
        } else {
            emptyMap()
        }
    }

    private fun openOutputSet(prefix: String, stamp: Long): OutputSet? {
        // 측정 중에는 헤더 통계가 확정되지 않으므로 본문만 .tmp에 먼저 쓴다.
        val originalBody = File(context.cacheDir, "${prefix}_original_$stamp.tmp")
        val processedBody = File(context.cacheDir, "${prefix}_256_$stamp.tmp")
        return try {
            OutputSet(
                originalBody = originalBody,
                processedBody = processedBody,
                originalOutput = File(context.cacheDir, "${prefix}_original_$stamp.txt"),
                processedOutput = File(context.cacheDir, "${prefix}_256_$stamp.txt"),
                originalWriter = BufferedWriter(FileWriter(originalBody)),
                processedWriter = BufferedWriter(FileWriter(processedBody)),
            )
        } catch (_: Exception) {
            originalBody.delete()
            processedBody.delete()
            null
        }
    }

    private fun openRequestedOutputs(stamp: Long): Boolean {
        // 세 요청은 서로 다른 원본 Writer를 사용한다.
        requestedOutputs.clear()
        return try {
            for (rate in intArrayOf(256, 128, 64)) {
                val body = File(context.cacheDir, "requested_${rate}_$stamp.tmp")
                requestedOutputs[rate] =
                    RequestedOutput(
                        body = body,
                        output = File(context.cacheDir, "requested_${rate}_$stamp.txt"),
                        writer = BufferedWriter(FileWriter(body)),
                    )
            }
            true
        } catch (_: Exception) {
            closeAndDeleteRequestedOutputs()
            false
        }
    }

    private fun writeFastestOriginal(sample: Fastest256Core.OriginalSample) {
        val output = fastestOutput ?: return
        // enum을 txt 첫 번째 열에 들어갈 읽기 쉬운 문자열로 바꾼다.
        val type =
            when (sample.kind) {
                Fastest256Core.SensorKind.RAW -> "raw"
                Fastest256Core.SensorKind.GRAVITY -> "gravity"
                Fastest256Core.SensorKind.LINEAR -> "linear"
            }
        writeOriginalLine(
            output,
            type,
            sample.timestampNs,
            sample.intervalNs,
            sample.x,
            sample.y,
            sample.z,
        )
        // 매 센서 이벤트마다 Flutter에 보내지 않고 linear 기준 약 1초마다 보낸다.
        if (
            sample.kind == Fastest256Core.SensorKind.LINEAR &&
            sample.timestampNs - output.lastStatsNs >= 1_000_000_000L
        ) {
            sendFastestStats()
            output.lastStatsNs = sample.timestampNs
        }
    }

    private fun writeRequested256Original(sample: Requested256HzCore.OriginalSample) {
        val type =
            when (sample.kind) {
                Requested256HzCore.SensorKind.RAW -> "raw"
                Requested256HzCore.SensorKind.GRAVITY -> "gravity"
                Requested256HzCore.SensorKind.LINEAR -> "linear"
            }
        writeRequestedOriginal(
            256,
            type,
            sample.timestampNs,
            sample.intervalNs,
            sample.x,
            sample.y,
            sample.z,
        )
    }

    private fun writeRequested128Original(sample: Requested128HzCore.OriginalSample) {
        val type =
            when (sample.kind) {
                Requested128HzCore.SensorKind.RAW -> "raw"
                Requested128HzCore.SensorKind.GRAVITY -> "gravity"
                Requested128HzCore.SensorKind.LINEAR -> "linear"
            }
        writeRequestedOriginal(
            128,
            type,
            sample.timestampNs,
            sample.intervalNs,
            sample.x,
            sample.y,
            sample.z,
        )
    }

    private fun writeRequested64Original(sample: Requested64HzCore.OriginalSample) {
        val type =
            when (sample.kind) {
                Requested64HzCore.SensorKind.RAW -> "raw"
                Requested64HzCore.SensorKind.GRAVITY -> "gravity"
                Requested64HzCore.SensorKind.LINEAR -> "linear"
            }
        writeRequestedOriginal(
            64,
            type,
            sample.timestampNs,
            sample.intervalNs,
            sample.x,
            sample.y,
            sample.z,
        )
    }

    private fun writeRequestedOriginal(
        rateHz: Int,
        type: String,
        timestampNs: Long,
        intervalNs: Long,
        x: Float,
        y: Float,
        z: Float,
    ) {
        val output = requestedOutputs[rateHz] ?: return
        output.writer.write(
            String.format(
                Locale.US,
                "%s %d %d %.9f %.9f %.9f%n",
                type,
                timestampNs / 1000L,
                intervalNs / 1000L,
                x * MPS2_TO_MG,
                y * MPS2_TO_MG,
                z * MPS2_TO_MG,
            ),
        )
    }

    private fun writeHandlerOriginal(sample: HandlerThread256Core.OriginalSample) {
        val output = handlerOutput ?: return
        val type =
            when (sample.kind) {
                HandlerThread256Core.SensorKind.RAW -> "raw"
                HandlerThread256Core.SensorKind.GRAVITY -> "gravity"
                HandlerThread256Core.SensorKind.LINEAR -> "linear"
            }
        writeOriginalLine(
            output,
            type,
            sample.timestampNs,
            sample.intervalNs,
            sample.x,
            sample.y,
            sample.z,
        )
        if (
            sample.kind == HandlerThread256Core.SensorKind.LINEAR &&
            sample.timestampNs - output.lastStatsNs >= 1_000_000_000L
        ) {
            sendHandlerStats()
            output.lastStatsNs = sample.timestampNs
        }
    }

    private fun writeOriginalLine(
        output: OutputSet,
        type: String,
        timestampNs: Long,
        intervalNs: Long,
        x: Float,
        y: Float,
        z: Float,
    ) {
        // Android m/s² 값을 사람이 비교하기 쉬운 mg 단위로 변환한다.
        output.originalWriter.write(
            String.format(
                Locale.US,
                "%s %d %d %.9f %.9f %.9f%n",
                type,
                timestampNs / 1000L,
                intervalNs / 1000L,
                x * MPS2_TO_MG,
                y * MPS2_TO_MG,
                z * MPS2_TO_MG,
            ),
        )
    }

    private fun writeFastestProcessed(sample: Fastest256Core.ResampledSample) {
        writeProcessedLine(
            fastestOutput,
            sample.timestampNs,
            sample.linearX,
            sample.linearY,
            sample.linearZ,
            sample.rawX,
            sample.rawY,
            sample.rawZ,
            sample.gravityX,
            sample.gravityY,
            sample.gravityZ,
        )
    }

    private fun writeHandlerProcessed(sample: HandlerThread256Core.ResampledSample) {
        writeProcessedLine(
            handlerOutput,
            sample.timestampNs,
            sample.linearX,
            sample.linearY,
            sample.linearZ,
            sample.rawX,
            sample.rawY,
            sample.rawZ,
            sample.gravityX,
            sample.gravityY,
            sample.gravityZ,
        )
    }

    private fun writeProcessedLine(
        outputSet: OutputSet?,
        timestampNs: Long,
        linearX: Double,
        linearY: Double,
        linearZ: Double,
        rawX: Double,
        rawY: Double,
        rawZ: Double,
        gravityX: Double,
        gravityY: Double,
        gravityZ: Double,
    ) {
        val output = outputSet ?: return
        // 보간 결과 한 행에는 동일 timestamp의 linear/raw/gravity 3축이 들어간다.
        output.processedCount++
        output.processedWriter.write(
            String.format(
                Locale.US,
                "%d %.9f %.9f %.9f %.9f %.9f %.9f %.9f %.9f %.9f%n",
                timestampNs / 1000L,
                linearX * MPS2_TO_MG,
                linearY * MPS2_TO_MG,
                linearZ * MPS2_TO_MG,
                rawX * MPS2_TO_MG,
                rawY * MPS2_TO_MG,
                rawZ * MPS2_TO_MG,
                gravityX * MPS2_TO_MG,
                gravityY * MPS2_TO_MG,
                gravityZ * MPS2_TO_MG,
            ),
        )
    }

    private fun sendFastestStats() {
        val active = fastestCore ?: return
        sendStats(
            lane = "fastest",
            rawCount = active.rawStats.count,
            gravityCount = active.gravityStats.count,
            linearCount = active.linearStats.count,
            hz = active.linearStats.measuredHz,
            mean = active.linearStats.meanIntervalMs,
            min = active.linearStats.minIntervalMs,
            max = active.linearStats.maxIntervalMs,
            processedCount = fastestOutput?.processedCount ?: 0,
        )
    }

    private fun sendHandlerStats() {
        val active = handlerCore ?: return
        sendStats(
            lane = "handlerThread",
            rawCount = active.rawStats.count,
            gravityCount = active.gravityStats.count,
            linearCount = active.linearStats.count,
            hz = active.linearStats.measuredHz,
            mean = active.linearStats.meanIntervalMs,
            min = active.linearStats.minIntervalMs,
            max = active.linearStats.maxIntervalMs,
            processedCount = handlerOutput?.processedCount ?: 0,
        )
    }

    private fun sendStats(
        lane: String,
        rawCount: Long,
        gravityCount: Long,
        linearCount: Long,
        hz: Double,
        mean: Double,
        min: Double,
        max: Double,
        processedCount: Long,
    ) {
        // lane 이름으로 Flutter 화면의 FASTEST/HandlerThread 카드를 구분한다.
        val event =
            mapOf(
                "type" to "stats",
                "lane" to lane,
                "rawCount" to rawCount,
                "gravityCount" to gravityCount,
                "linearCount" to linearCount,
                "rawHz" to hz,
                "meanDtMs" to mean,
                "minDtMs" to min,
                "maxDtMs" to max,
                "resampledCount" to processedCount,
                "resampledHz" to TARGET_HZ.toDouble(),
            )
        mainHandler.post { eventSink?.success(event) }
    }

    private fun buildFastestOriginal(
        active: Fastest256Core?,
        outputSet: OutputSet?,
    ): String? {
        if (active == null) return null
        return buildOriginal(
            outputSet,
            "SENSOR_DELAY_FASTEST",
            active.rawStats.count,
            active.gravityStats.count,
            active.linearStats.count,
            active.linearStats.meanIntervalMs,
            active.linearStats.minIntervalMs,
            active.linearStats.maxIntervalMs,
            active.linearStats.measuredHz,
        )
    }

    private fun buildHandlerOriginal(
        active: HandlerThread256Core?,
        outputSet: OutputSet?,
    ): String? {
        if (active == null) return null
        return buildOriginal(
            outputSet,
            "SENSOR_DELAY_FASTEST + HandlerThread",
            active.rawStats.count,
            active.gravityStats.count,
            active.linearStats.count,
            active.linearStats.meanIntervalMs,
            active.linearStats.minIntervalMs,
            active.linearStats.maxIntervalMs,
            active.linearStats.measuredHz,
        )
    }

    private fun buildOriginal(
        outputSet: OutputSet?,
        label: String,
        rawCount: Long,
        gravityCount: Long,
        linearCount: Long,
        mean: Double,
        min: Double,
        max: Double,
        hz: Double,
    ): String? {
        val output = outputSet ?: return null
        return buildFile(output.originalOutput, output.originalBody) { writer ->
            writer.write("# 요청: $label\n")
            writer.write("# raw 총개수: $rawCount\n")
            writer.write("# gravity 총개수: $gravityCount\n")
            writer.write("# linear 총개수: $linearCount\n")
            writer.write(
                String.format(
                    Locale.US,
                    "# linear 간격(ms): 평균=%.6f 최소=%.6f 최대=%.6f 실측Hz=%.3f%n",
                    mean,
                    min,
                    max,
                    hz,
                ),
            )
            writer.write("# columns: type tsUs dtUs x_mg y_mg z_mg\n")
        }
    }

    private fun buildProcessed(label: String, outputSet: OutputSet?): String? {
        val output = outputSet ?: return null
        return buildFile(output.processedOutput, output.processedBody) { writer ->
            writer.write("# $label\n")
            writer.write("# 가공 총개수: ${output.processedCount}\n")
            writer.write(
                "# columns: tsUs linearX_mg linearY_mg linearZ_mg " +
                    "rawX_mg rawY_mg rawZ_mg gravityX_mg gravityY_mg gravityZ_mg\n",
            )
        }
    }

    private fun buildRequested256(active: Requested256HzCore?): String? =
        if (active == null) {
            null
        } else {
            buildRequestedFile(
                rateHz = Requested256HzCore.REQUESTED_HZ,
                samplingPeriodUs = Requested256HzCore.SAMPLING_PERIOD_US,
                raw =
                    RequestedSensorStats(
                        active.rawStats.count,
                        active.rawStats.meanIntervalUs,
                        active.rawStats.minIntervalUs,
                        active.rawStats.maxIntervalUs,
                        active.rawStats.measuredHz,
                    ),
                gravity =
                    RequestedSensorStats(
                        active.gravityStats.count,
                        active.gravityStats.meanIntervalUs,
                        active.gravityStats.minIntervalUs,
                        active.gravityStats.maxIntervalUs,
                        active.gravityStats.measuredHz,
                    ),
                linear =
                    RequestedSensorStats(
                        active.linearStats.count,
                        active.linearStats.meanIntervalUs,
                        active.linearStats.minIntervalUs,
                        active.linearStats.maxIntervalUs,
                        active.linearStats.measuredHz,
                    ),
            )
        }

    private fun buildRequested128(active: Requested128HzCore?): String? =
        if (active == null) {
            null
        } else {
            buildRequestedFile(
                rateHz = Requested128HzCore.REQUESTED_HZ,
                samplingPeriodUs = Requested128HzCore.SAMPLING_PERIOD_US,
                raw =
                    RequestedSensorStats(
                        active.rawStats.count,
                        active.rawStats.meanIntervalUs,
                        active.rawStats.minIntervalUs,
                        active.rawStats.maxIntervalUs,
                        active.rawStats.measuredHz,
                    ),
                gravity =
                    RequestedSensorStats(
                        active.gravityStats.count,
                        active.gravityStats.meanIntervalUs,
                        active.gravityStats.minIntervalUs,
                        active.gravityStats.maxIntervalUs,
                        active.gravityStats.measuredHz,
                    ),
                linear =
                    RequestedSensorStats(
                        active.linearStats.count,
                        active.linearStats.meanIntervalUs,
                        active.linearStats.minIntervalUs,
                        active.linearStats.maxIntervalUs,
                        active.linearStats.measuredHz,
                    ),
            )
        }

    private fun buildRequested64(active: Requested64HzCore?): String? =
        if (active == null) {
            null
        } else {
            buildRequestedFile(
                rateHz = Requested64HzCore.REQUESTED_HZ,
                samplingPeriodUs = Requested64HzCore.SAMPLING_PERIOD_US,
                raw =
                    RequestedSensorStats(
                        active.rawStats.count,
                        active.rawStats.meanIntervalUs,
                        active.rawStats.minIntervalUs,
                        active.rawStats.maxIntervalUs,
                        active.rawStats.measuredHz,
                    ),
                gravity =
                    RequestedSensorStats(
                        active.gravityStats.count,
                        active.gravityStats.meanIntervalUs,
                        active.gravityStats.minIntervalUs,
                        active.gravityStats.maxIntervalUs,
                        active.gravityStats.measuredHz,
                    ),
                linear =
                    RequestedSensorStats(
                        active.linearStats.count,
                        active.linearStats.meanIntervalUs,
                        active.linearStats.minIntervalUs,
                        active.linearStats.maxIntervalUs,
                        active.linearStats.measuredHz,
                    ),
            )
        }

    private fun buildRequestedFile(
        rateHz: Int,
        samplingPeriodUs: Int,
        raw: RequestedSensorStats,
        gravity: RequestedSensorStats,
        linear: RequestedSensorStats,
    ): String? {
        val requestedOutput = requestedOutputs[rateHz] ?: return null
        return buildFile(requestedOutput.output, requestedOutput.body) { writer ->
            writer.write("# ${rateHz}Hz 별도 센서 요청 측정\n")
            writer.write("# samplingPeriodUs: $samplingPeriodUs\n")
            writer.write(
                String.format(
                    Locale.US,
                    "# raw: 개수=%d 평균=%.3fus 최소=%.3fus 최대=%.3fus 실측Hz=%.3f%n",
                    raw.count,
                    raw.meanUs,
                    raw.minUs,
                    raw.maxUs,
                    raw.measuredHz,
                ),
            )
            writer.write(
                String.format(
                    Locale.US,
                    "# gravity: 개수=%d 평균=%.3fus 최소=%.3fus 최대=%.3fus 실측Hz=%.3f%n",
                    gravity.count,
                    gravity.meanUs,
                    gravity.minUs,
                    gravity.maxUs,
                    gravity.measuredHz,
                ),
            )
            writer.write(
                String.format(
                    Locale.US,
                    "# linear: 개수=%d 평균=%.3fus 최소=%.3fus 최대=%.3fus 실측Hz=%.3f%n",
                    linear.count,
                    linear.meanUs,
                    linear.minUs,
                    linear.maxUs,
                    linear.measuredHz,
                ),
            )
            writer.write("# columns: type tsUs dtUs x_mg y_mg z_mg\n")
        }
    }

    private fun buildFile(
        output: File,
        body: File,
        header: (BufferedWriter) -> Unit,
    ): String? =
        try {
            // 최종 파일은 "측정 종료 후 확정된 헤더 + 측정 중 쌓은 본문" 순서다.
            BufferedWriter(FileWriter(output)).use { writer ->
                header(writer)
                body.forEachLine { writer.write("$it\n") }
            }
            output.absolutePath
        } catch (_: Exception) {
            null
        }

    private fun closeOutput(output: OutputSet?) {
        if (output == null) return
        try { output.originalWriter.flush(); output.originalWriter.close() } catch (_: Exception) {}
        try { output.processedWriter.flush(); output.processedWriter.close() } catch (_: Exception) {}
    }

    private fun closeRequestedOutputs() {
        for (output in requestedOutputs.values) {
            try { output.writer.flush(); output.writer.close() } catch (_: Exception) {}
        }
    }

    private fun cleanupBodies(output: OutputSet?) {
        output?.originalBody?.delete()
        output?.processedBody?.delete()
    }

    private fun cleanupRequestedOutputs() {
        for (output in requestedOutputs.values) output.body.delete()
        requestedOutputs.clear()
    }

    private fun closeAndDelete(output: OutputSet?) {
        closeOutput(output)
        cleanupBodies(output)
    }

    private fun closeAndDeleteRequestedOutputs() {
        closeRequestedOutputs()
        cleanupRequestedOutputs()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // Flutter가 화면 스트림 구독을 시작하면 통계 전달 통로를 보관한다.
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        // 화면이 스트림 구독을 끝내면 더 이상 UI 이벤트를 보내지 않는다.
        eventSink = null
    }
}
