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
 */
class FastestVerifyHandler(
    private val context: Context,
) : EventChannel.StreamHandler {
    companion object {
        const val TARGET_HZ = 256
        private const val MPS2_TO_MG = 101.97162129779283
    }

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

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var fastestCore: Fastest256Core? = null
    private var handlerCore: HandlerThread256Core? = null
    private var fastestOutput: OutputSet? = null
    private var handlerOutput: OutputSet? = null

    fun start(targetHz: Int): Boolean {
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

        val fastestStarted = fastestCore?.start() == true
        val handlerStarted = handlerCore?.start() == true
        if (!fastestStarted || !handlerStarted) {
            fastestCore?.stop()
            handlerCore?.stop()
            fastestCore = null
            handlerCore = null
            closeAndDelete(fastestOutput)
            closeAndDelete(handlerOutput)
            fastestOutput = null
            handlerOutput = null
            return false
        }
        return true
    }

    fun stop(): Map<String, String> {
        val activeFastest = fastestCore
        val activeHandler = handlerCore
        if (activeFastest == null && activeHandler == null) return emptyMap()

        activeFastest?.stop()
        activeHandler?.stop()
        fastestCore = null
        handlerCore = null
        closeOutput(fastestOutput)
        closeOutput(handlerOutput)

        val fastestRaw =
            buildFastestOriginal(activeFastest, fastestOutput)
        val fastest256 =
            buildProcessed("SENSOR_DELAY_FASTEST 원본의 256Hz 보간", fastestOutput)
        val handlerRaw =
            buildHandlerOriginal(activeHandler, handlerOutput)
        val handler256 =
            buildProcessed("FASTEST+HandlerThread 원본의 256Hz 보간", handlerOutput)

        cleanupBodies(fastestOutput)
        cleanupBodies(handlerOutput)
        fastestOutput = null
        handlerOutput = null

        return if (
            fastestRaw != null &&
            fastest256 != null &&
            handlerRaw != null &&
            handler256 != null
        ) {
            linkedMapOf(
                "fastestRaw" to fastestRaw,
                "fastest256" to fastest256,
                "handlerRaw" to handlerRaw,
                "handler256" to handler256,
            )
        } else {
            emptyMap()
        }
    }

    private fun openOutputSet(prefix: String, stamp: Long): OutputSet? {
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

    private fun writeFastestOriginal(sample: Fastest256Core.OriginalSample) {
        val output = fastestOutput ?: return
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
        if (
            sample.kind == Fastest256Core.SensorKind.LINEAR &&
            sample.timestampNs - output.lastStatsNs >= 1_000_000_000L
        ) {
            sendFastestStats()
            output.lastStatsNs = sample.timestampNs
        }
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

    private fun buildFile(
        output: File,
        body: File,
        header: (BufferedWriter) -> Unit,
    ): String? =
        try {
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

    private fun cleanupBodies(output: OutputSet?) {
        output?.originalBody?.delete()
        output?.processedBody?.delete()
    }

    private fun closeAndDelete(output: OutputSet?) {
        closeOutput(output)
        cleanupBodies(output)
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
