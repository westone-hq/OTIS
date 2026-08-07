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
 * [FixedRate256Core]를 실제 앱에 연결하고 출력 파일 네 개를 만든다.
 *
 * - 1ms_원본.txt / 1ms_256Hz.txt
 * - 3ms_원본.txt / 3ms_256Hz.txt
 *
 * 처리 흐름:
 * [start] 네 임시/최종 파일 준비 및 Core 시작
 * → Core의 원본·보간 콜백을 1ms/3ms Writer로 분리
 * → [stop] 통계 헤더와 임시 본문을 합쳐 네 최종 파일 경로 반환.
 *
 * 이 Handler는 파일·Flutter 통신을 담당하고 센서 등록과 보간은 [FixedRate256Core]가 담당한다.
 */
class FixedRateVerifyHandler(
    private val context: Context,
) : EventChannel.StreamHandler {
    companion object {
        const val TARGET_HZ = FixedRate256Core.TARGET_HZ
        private const val MPS2_TO_MG = 101.97162129779283
    }

    /** 요청 주기 하나의 원본/256Hz 임시 본문과 최종 파일 상태다. */
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

    // 센서 콜백 스레드와 관계없이 Flutter 통계는 메인 스레드에서 보낸다.
    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var core: FixedRate256Core? = null
    private var oneMsOutput: OutputSet? = null
    private var threeMsOutput: OutputSet? = null

    fun start(targetHz: Int): Boolean {
        // 재시작 전에 기존 Core와 Writer를 정리한다.
        stop()
        // 한 측정에서 생성한 네 파일임을 알 수 있도록 같은 stamp를 사용한다.
        val stamp = System.currentTimeMillis()
        oneMsOutput = openOutputSet("one_ms", stamp) ?: return false
        threeMsOutput =
            openOutputSet("three_ms", stamp)
                ?: run {
                    closeOutputSet(oneMsOutput)
                    oneMsOutput = null
                    return false
                }

        // Core가 만든 원본/256Hz 결과를 아래 Writer 함수에 직접 연결한다.
        core =
            FixedRate256Core(
                context = context,
                onOriginal = ::writeOriginal,
                onResampled = ::writeProcessed,
            )
        val started = core?.start() == true
        if (!started) {
            core?.stop()
            core = null
            closeOutputSet(oneMsOutput)
            closeOutputSet(threeMsOutput)
            cleanupOutputSet(oneMsOutput)
            cleanupOutputSet(threeMsOutput)
            oneMsOutput = null
            threeMsOutput = null
        }
        return started
    }

    fun stop(): Map<String, String> {
        val activeCore = core ?: return emptyMap()
        // 새 콜백이 Writer에 들어오지 않도록 센서를 먼저 멈춘 뒤 Writer를 닫는다.
        activeCore.stop()
        core = null
        closeOutputSet(oneMsOutput)
        closeOutputSet(threeMsOutput)

        // 종료 시점에 확정된 통계 헤더를 임시 본문 앞에 붙인다.
        val oneRaw =
            buildOriginalFile(
                outputSet = oneMsOutput,
                label = "samplingPeriodUs=1000 (1ms 요청)",
                stats = activeCore.oneMsStats,
            )
        val one256 =
            buildProcessedFile(
                outputSet = oneMsOutput,
                label = "1ms 요청 원본의 256Hz 선형 보간",
            )
        val threeRaw =
            buildOriginalFile(
                outputSet = threeMsOutput,
                label = "samplingPeriodUs=3000 (3ms 요청)",
                stats = activeCore.threeMsStats,
            )
        val three256 =
            buildProcessedFile(
                outputSet = threeMsOutput,
                label = "3ms 요청 원본의 256Hz 선형 보간",
            )

        cleanupOutputSet(oneMsOutput)
        cleanupOutputSet(threeMsOutput)
        oneMsOutput = null
        threeMsOutput = null

        // 네 파일이 모두 만들어진 경우에만 Flutter에 경로를 반환한다.
        return if (
            oneRaw != null &&
            one256 != null &&
            threeRaw != null &&
            three256 != null
        ) {
            linkedMapOf(
                "oneMsRaw" to oneRaw,
                "oneMs256" to one256,
                "threeMsRaw" to threeRaw,
                "threeMs256" to three256,
            )
        } else {
            emptyMap()
        }
    }

    private fun openOutputSet(prefix: String, stamp: Long): OutputSet? {
        // 측정 중 통계는 계속 바뀌므로 .tmp에는 데이터 행만 누적한다.
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

    /** Core가 알려준 요청 주기에 따라 1ms 또는 3ms Writer를 선택한다. */
    private fun outputFor(rate: FixedRate256Core.RequestedRate): OutputSet? =
        when (rate) {
            FixedRate256Core.RequestedRate.ONE_MS -> oneMsOutput
            FixedRate256Core.RequestedRate.THREE_MS -> threeMsOutput
        }

    private fun writeOriginal(
        rate: FixedRate256Core.RequestedRate,
        sample: FixedRate256Core.OriginalSample,
    ) {
        // 1ms와 3ms 원본이 같은 파일에 섞이지 않도록 먼저 출력 묶음을 고른다.
        val output = outputFor(rate) ?: return
        val type =
            when (sample.kind) {
                FixedRate256Core.SensorKind.RAW -> "raw"
                FixedRate256Core.SensorKind.GRAVITY -> "gravity"
                FixedRate256Core.SensorKind.LINEAR -> "linear"
            }
        // timestamp/dt는 ns→µs, 가속도는 m/s²→mg로 바꿔 저장한다.
        output.originalWriter.write(
            String.format(
                Locale.US,
                "%s %d %d %.9f %.9f %.9f%n",
                type,
                sample.timestampNs / 1000L,
                sample.intervalNs / 1000L,
                sample.x * MPS2_TO_MG,
                sample.y * MPS2_TO_MG,
                sample.z * MPS2_TO_MG,
            ),
        )

        // linear 센서 시각 기준 약 1초마다 해당 lane의 통계를 Flutter로 보낸다.
        if (
            sample.kind == FixedRate256Core.SensorKind.LINEAR &&
            sample.timestampNs - output.lastStatsNs >= 1_000_000_000L
        ) {
            sendStats(rate)
            output.lastStatsNs = sample.timestampNs
        }
    }

    private fun writeProcessed(
        rate: FixedRate256Core.RequestedRate,
        sample: FixedRate256Core.ResampledSample,
    ) {
        val output = outputFor(rate) ?: return
        // 같은 256Hz timestamp의 linear/raw/gravity 3축을 한 행에 기록한다.
        output.processedCount++
        output.processedWriter.write(
            String.format(
                Locale.US,
                "%d %.9f %.9f %.9f %.9f %.9f %.9f %.9f %.9f %.9f%n",
                sample.timestampNs / 1000L,
                sample.linearX * MPS2_TO_MG,
                sample.linearY * MPS2_TO_MG,
                sample.linearZ * MPS2_TO_MG,
                sample.rawX * MPS2_TO_MG,
                sample.rawY * MPS2_TO_MG,
                sample.rawZ * MPS2_TO_MG,
                sample.gravityX * MPS2_TO_MG,
                sample.gravityY * MPS2_TO_MG,
                sample.gravityZ * MPS2_TO_MG,
            ),
        )
    }

    private fun sendStats(rate: FixedRate256Core.RequestedRate) {
        val activeCore = core ?: return
        val output = outputFor(rate) ?: return
        val stats =
            when (rate) {
                FixedRate256Core.RequestedRate.ONE_MS -> activeCore.oneMsStats
                FixedRate256Core.RequestedRate.THREE_MS -> activeCore.threeMsStats
            }
        // Flutter 화면이 어느 카드에 표시할지 알 수 있는 lane 문자열이다.
        val lane =
            if (rate == FixedRate256Core.RequestedRate.ONE_MS) "oneMs" else "threeMs"
        val event =
            mapOf(
                "type" to "stats",
                "lane" to lane,
                "rawCount" to stats.raw.count,
                "gravityCount" to stats.gravity.count,
                "linearCount" to stats.linear.count,
                "rawHz" to stats.linear.measuredHz,
                "meanDtMs" to stats.linear.meanIntervalMs,
                "minDtMs" to stats.linear.minIntervalMs,
                "maxDtMs" to stats.linear.maxIntervalMs,
                "resampledCount" to output.processedCount,
                "resampledHz" to TARGET_HZ.toDouble(),
            )
        mainHandler.post { eventSink?.success(event) }
    }

    private fun buildOriginalFile(
        outputSet: OutputSet?,
        label: String,
        stats: FixedRate256Core.RateStats,
    ): String? {
        val output = outputSet ?: return null
        return buildFile(output.originalOutput, output.originalBody) { writer ->
            writer.write("# 요청: $label\n")
            writer.write("# raw 총개수: ${stats.raw.count}\n")
            writer.write("# gravity 총개수: ${stats.gravity.count}\n")
            writer.write("# linear 총개수: ${stats.linear.count}\n")
            writer.write(
                String.format(
                    Locale.US,
                    "# linear 간격(ms): 평균=%.6f 최소=%.6f 최대=%.6f 실측Hz=%.3f%n",
                    stats.linear.meanIntervalMs,
                    stats.linear.minIntervalMs,
                    stats.linear.maxIntervalMs,
                    stats.linear.measuredHz,
                ),
            )
            writer.write("# columns: type tsUs dtUs x_mg y_mg z_mg\n")
        }
    }

    private fun buildProcessedFile(
        outputSet: OutputSet?,
        label: String,
    ): String? {
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

    private fun buildFile(
        output: File,
        body: File,
        header: (BufferedWriter) -> Unit,
    ): String? =
        try {
            // 최종 txt는 종료 후 만든 헤더를 먼저 쓰고 임시 본문을 이어 붙인다.
            BufferedWriter(FileWriter(output)).use { writer ->
                header(writer)
                body.forEachLine { writer.write("$it\n") }
            }
            output.absolutePath
        } catch (_: Exception) {
            null
        }

    private fun closeOutputSet(output: OutputSet?) {
        // flush 후 close하여 마지막 버퍼 데이터까지 디스크에 반영한다.
        if (output == null) return
        try { output.originalWriter.flush(); output.originalWriter.close() } catch (_: Exception) {}
        try { output.processedWriter.flush(); output.processedWriter.close() } catch (_: Exception) {}
    }

    private fun cleanupOutputSet(output: OutputSet?) {
        output?.originalBody?.delete()
        output?.processedBody?.delete()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // Flutter 검증 화면이 통계 스트림 구독을 시작한다.
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        // 화면이 닫히면 UI 통계 전송 대상만 제거한다.
        eventSink = null
    }
}
