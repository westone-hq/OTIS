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
 */
class FixedRateVerifyHandler(
    private val context: Context,
) : EventChannel.StreamHandler {
    companion object {
        const val TARGET_HZ = FixedRate256Core.TARGET_HZ
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
    private var core: FixedRate256Core? = null
    private var oneMsOutput: OutputSet? = null
    private var threeMsOutput: OutputSet? = null

    fun start(targetHz: Int): Boolean {
        stop()
        val stamp = System.currentTimeMillis()
        oneMsOutput = openOutputSet("one_ms", stamp) ?: return false
        threeMsOutput =
            openOutputSet("three_ms", stamp)
                ?: run {
                    closeOutputSet(oneMsOutput)
                    oneMsOutput = null
                    return false
                }

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
        activeCore.stop()
        core = null
        closeOutputSet(oneMsOutput)
        closeOutputSet(threeMsOutput)

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

    private fun outputFor(rate: FixedRate256Core.RequestedRate): OutputSet? =
        when (rate) {
            FixedRate256Core.RequestedRate.ONE_MS -> oneMsOutput
            FixedRate256Core.RequestedRate.THREE_MS -> threeMsOutput
        }

    private fun writeOriginal(
        rate: FixedRate256Core.RequestedRate,
        sample: FixedRate256Core.OriginalSample,
    ) {
        val output = outputFor(rate) ?: return
        val type =
            when (sample.kind) {
                FixedRate256Core.SensorKind.RAW -> "raw"
                FixedRate256Core.SensorKind.GRAVITY -> "gravity"
                FixedRate256Core.SensorKind.LINEAR -> "linear"
            }
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
            BufferedWriter(FileWriter(output)).use { writer ->
                header(writer)
                body.forEachLine { writer.write("$it\n") }
            }
            output.absolutePath
        } catch (_: Exception) {
            null
        }

    private fun closeOutputSet(output: OutputSet?) {
        if (output == null) return
        try { output.originalWriter.flush(); output.originalWriter.close() } catch (_: Exception) {}
        try { output.processedWriter.flush(); output.processedWriter.close() } catch (_: Exception) {}
    }

    private fun cleanupOutputSet(output: OutputSet?) {
        output?.originalBody?.delete()
        output?.processedBody?.delete()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
