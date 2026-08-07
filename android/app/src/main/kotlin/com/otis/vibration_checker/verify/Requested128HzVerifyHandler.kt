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
 * [Requested128HzCore] 하나만 실행해 128Hz 단독 측정 파일 하나를 만든다.
 *
 * FASTEST·1ms·3ms·64Hz Core를 시작하지 않으므로 다른 요청 주기의 영향을 받지 않는다.
 */
class Requested128HzVerifyHandler(
    private val context: Context,
) : EventChannel.StreamHandler {
    companion object {
        private const val MPS2_TO_MG = 101.97162129779283
    }

    private val mainHandler = Handler(Looper.getMainLooper())
    private var eventSink: EventChannel.EventSink? = null
    private var core: Requested128HzCore? = null
    private var bodyFile: File? = null
    private var outputFile: File? = null
    private var writer: BufferedWriter? = null
    private var lastStatsNs = 0L

    fun start(): Boolean {
        stop()
        val stamp = System.currentTimeMillis()
        val body = File(context.cacheDir, "standalone_128_$stamp.tmp")
        val output = File(context.cacheDir, "standalone_128_$stamp.txt")
        val openedWriter =
            try {
                BufferedWriter(FileWriter(body))
            } catch (_: Exception) {
                body.delete()
                return false
            }

        bodyFile = body
        outputFile = output
        writer = openedWriter
        lastStatsNs = 0L
        core = Requested128HzCore(context, ::writeOriginal)
        if (core?.start() != true) {
            core = null
            closeWriter()
            cleanupBody()
            outputFile = null
            return false
        }
        return true
    }

    fun stop(): Map<String, String> {
        val active = core ?: return emptyMap()
        active.stop()
        core = null
        closeWriter()
        val path = buildOutput(active)
        cleanupBody()
        bodyFile = null
        outputFile = null
        return if (path == null) {
            emptyMap()
        } else {
            mapOf(Requested128HzCore.OUTPUT_KEY to path)
        }
    }

    private fun writeOriginal(sample: Requested128HzCore.OriginalSample) {
        val activeWriter = writer ?: return
        val type =
            when (sample.kind) {
                Requested128HzCore.SensorKind.RAW -> "raw"
                Requested128HzCore.SensorKind.GRAVITY -> "gravity"
                Requested128HzCore.SensorKind.LINEAR -> "linear"
            }
        activeWriter.write(
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
            sample.kind == Requested128HzCore.SensorKind.LINEAR &&
            sample.timestampNs - lastStatsNs >= 1_000_000_000L
        ) {
            sendStats()
            lastStatsNs = sample.timestampNs
        }
    }

    private fun sendStats() {
        val active = core ?: return
        val event =
            mapOf(
                "type" to "stats",
                "lane" to "standalone128",
                "requestedHz" to Requested128HzCore.REQUESTED_HZ,
                "samplingPeriodUs" to Requested128HzCore.SAMPLING_PERIOD_US,
                "rawCount" to active.rawStats.count,
                "gravityCount" to active.gravityStats.count,
                "linearCount" to active.linearStats.count,
                "rawHz" to active.rawStats.measuredHz,
                "gravityHz" to active.gravityStats.measuredHz,
                "linearHz" to active.linearStats.measuredHz,
                "meanDtUs" to active.linearStats.meanIntervalUs,
                "minDtUs" to active.linearStats.minIntervalUs,
                "maxDtUs" to active.linearStats.maxIntervalUs,
            )
        mainHandler.post { eventSink?.success(event) }
    }

    private fun buildOutput(active: Requested128HzCore): String? {
        val body = bodyFile ?: return null
        val output = outputFile ?: return null
        return try {
            BufferedWriter(FileWriter(output)).use { outputWriter ->
                outputWriter.write("# 128Hz 단독 센서 요청 측정\n")
                outputWriter.write("# samplingPeriodUs: ${Requested128HzCore.SAMPLING_PERIOD_US}\n")
                writeStats(outputWriter, "raw", active.rawStats)
                writeStats(outputWriter, "gravity", active.gravityStats)
                writeStats(outputWriter, "linear", active.linearStats)
                outputWriter.write("# columns: type tsUs dtUs x_mg y_mg z_mg\n")
                body.forEachLine { outputWriter.write("$it\n") }
            }
            output.absolutePath
        } catch (_: Exception) {
            output.delete()
            null
        }
    }

    private fun writeStats(
        outputWriter: BufferedWriter,
        type: String,
        stats: Requested128HzCore.IntervalStats,
    ) {
        outputWriter.write(
            String.format(
                Locale.US,
                "# %s: 개수=%d 평균=%.3fus 최소=%.3fus 최대=%.3fus 실측Hz=%.3f%n",
                type,
                stats.count,
                stats.meanIntervalUs,
                stats.minIntervalUs,
                stats.maxIntervalUs,
                stats.measuredHz,
            ),
        )
    }

    private fun closeWriter() {
        val activeWriter = writer
        writer = null
        try {
            activeWriter?.flush()
            activeWriter?.close()
        } catch (_: Exception) {
        }
    }

    private fun cleanupBody() {
        bodyFile?.delete()
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
