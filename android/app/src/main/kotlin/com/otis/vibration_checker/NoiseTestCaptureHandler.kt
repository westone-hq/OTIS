package com.otis.vibration_checker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.core.content.ContextCompat
import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.UUID
import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.exp
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * 작성: 2026-09-21 · 박희정
 * 수정: 2026-09-21 · 박희정
 * 열거: NoiseTestMode
 * 목적: 소음(dB) 전용 테스트 4모드. EVIMP1 진동+소음 측정과 별개다.
 *       id는 Flutter·CSV·UI에서 동일하게 쓴다.
 *       - rate40k / rate80k / aweight: Fast 창(0.125초)
 *       - slow: Slow 창(1.0초), 값이 덜 출렁이는지 비교용
 */
enum class NoiseTestMode(
    val id: String,
    val label: String,
    val requestedRate: Int,
    val useAWeighting: Boolean,
    /** RMS 창 길이(초). Fast≈0.125, Slow≈1.0 */
    val windowSec: Double,
) {
    RATE_40K("rate40k", "40 kHz · Fast 0.125s", 40000, false, 0.125),
    RATE_80K("rate80k", "80 kHz · Fast 0.125s", 80000, false, 0.125),
    AWEIGHT("aweight", "48 kHz · Fast + 근사 A가중", 48000, true, 0.125),
    SLOW("slow", "48 kHz · Slow 1.0s", 48000, false, 1.0);

    companion object {
        fun fromId(id: String): NoiseTestMode? = entries.find { it.id == id }
    }
}

/**
 * 작성: 2026-09-21 · 박희정
 * 클래스: NoiseTestCaptureHandler
 * 목적: 소음(dB)만 따로 테스트한다. 요청 샘플레이트·근사 A가중 여부를
 *       모드별로 바꾸고, 모드의 windowSec(Fast 0.125 / Slow 1.0) 슬라이딩
 *       RMS(~20 Hz 홉)로 dB를 계산해 CSV와 라이브 싱크에 남긴다.
 *       실험실급이 아닌 근사 측정이다.
 * 식:   dBFS = 20 × log10(rms)
 *       dB   = dBFS + 85.0 (+0 cal)  (0~130으로 자름)
 */
class NoiseTestCaptureHandler(private val context: Context) {
    companion object {
        private const val TAG = "NoiseTestCaptureHandler"
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        private const val HOP_HZ = 20
        private const val MIC_DBFS_TO_DB_OFFSET = 85.0
        private const val CALIBRATION_OFFSET = 0.0

        /** 요청 레이트가 안 될 때 고를 후보(가까운 순으로 재정렬해 시도) */
        private val FALLBACK_RATES = intArrayOf(48000, 44100, 32000, 22050, 16000, 8000)
    }

    @Volatile
    var isRunning: Boolean = false
        private set

    @Volatile
    private var latestDb: Double = 0.0

    @Volatile
    private var latestDbfs: Double = 0.0

    @Volatile
    private var latestRms: Double = 0.0

    private var audioRecord: AudioRecord? = null
    private var captureThread: Thread? = null
    private var csvWriter: BufferedWriter? = null
    private var csvFile: File? = null

    private var currentMode: NoiseTestMode? = null
    private var requestedSampleRate: Int = 0
    private var actualSampleRate: Int = 0
    private var sessionId: String = ""
    private var startedAtMs: Long = 0L

    private var minDb: Double = Double.POSITIVE_INFINITY
    private var maxDb: Double = Double.NEGATIVE_INFINITY
    private var sumDb: Double = 0.0
    private var sampleCount: Long = 0L

    private var liveSink: ((Map<String, Any?>) -> Unit)? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * 작성: 2026-09-21 · 박희정
     * 함수: setLiveSink
     * 목적: 라이브 dB 맵을 받을 콜백을 등록한다. null이면 전송을 멈춘다.
     */
    fun setLiveSink(sink: ((Map<String, Any?>) -> Unit)?) {
        liveSink = sink
    }

    /**
     * 작성: 2026-09-21 · 박희정
     * 함수: start
     * 목적: 지정 모드로 소음 테스트를 시작한다. 이미 돌고 있으면 실패 맵을
     *       돌려준다. 요청 샘플레이트가 안 되면 후보 중 가장 가까운 값으로
     *       대체하고 requested/actual 둘 다 기록한다.
     */
    fun start(mode: NoiseTestMode): Map<String, Any?> {
        if (isRunning) {
            return mapOf(
                "ok" to false,
                "error" to "이미 소음 테스트가 실행 중입니다.",
                "isRunning" to true,
            )
        }

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            return mapOf(
                "ok" to false,
                "error" to "RECORD_AUDIO 권한이 없습니다.",
                "isRunning" to false,
            )
        }

        val resolved = resolveSampleRate(mode.requestedRate)
            ?: return mapOf(
                "ok" to false,
                "error" to "지원하는 샘플레이트를 찾지 못했습니다.",
                "isRunning" to false,
                "requestedSampleRate" to mode.requestedRate,
            )

        val windowSamples = (resolved * mode.windowSec).toInt().coerceAtLeast(1)
        val hopSamples = (resolved / HOP_HZ).coerceAtLeast(1)
        val minBufSize = AudioRecord.getMinBufferSize(resolved, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
            return mapOf(
                "ok" to false,
                "error" to "AudioRecord 버퍼 크기가 유효하지 않습니다.",
                "requestedSampleRate" to mode.requestedRate,
                "actualSampleRate" to resolved,
            )
        }
        val bufferSize = maxOf(minBufSize, windowSamples * 2)

        val record = try {
            AudioRecord(
                MediaRecorder.AudioSource.MIC,
                resolved,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize,
            )
        } catch (e: Exception) {
            Log.e(TAG, "AudioRecord create failed", e)
            return mapOf(
                "ok" to false,
                "error" to "AudioRecord 생성 실패: ${e.message}",
                "requestedSampleRate" to mode.requestedRate,
                "actualSampleRate" to resolved,
            )
        }

        if (record.state != AudioRecord.STATE_INITIALIZED) {
            record.release()
            return mapOf(
                "ok" to false,
                "error" to "AudioRecord 초기화 실패",
                "requestedSampleRate" to mode.requestedRate,
                "actualSampleRate" to resolved,
            )
        }

        sessionId = UUID.randomUUID().toString().replace("-", "").take(8)
        val stamp = SimpleDateFormat("yyyyMMdd_HHmmss_SSS", Locale.US).format(Date())
        val dir = File(context.getExternalFilesDir(null), "noise_tests").apply { mkdirs() }
        val fileName =
            "noise_${mode.id}_req${mode.requestedRate}_act${resolved}_${stamp}_${sessionId}.csv"
        val outFile = File(dir, fileName)

        val writer = try {
            BufferedWriter(FileWriter(outFile)).also { w ->
                w.write("# modeId=${mode.id}")
                w.newLine()
                w.write("# modeLabel=${mode.label}")
                w.newLine()
                w.write("# requestedSampleRate=${mode.requestedRate}")
                w.newLine()
                w.write("# actualSampleRate=$resolved")
                w.newLine()
                w.write("# aWeighting=${mode.useAWeighting}")
                w.newLine()
                w.write("# aWeightingNote=approximate one-pole HP/LP cascade (not lab-grade)")
                w.newLine()
                w.write("# windowSec=${mode.windowSec}")
                w.newLine()
                w.write("# sessionId=$sessionId")
                w.newLine()
                w.write("# micDbfsToDbOffset=$MIC_DBFS_TO_DB_OFFSET")
                w.newLine()
                w.write("# calibrationOffset=$CALIBRATION_OFFSET")
                w.newLine()
                w.write("elapsedMs,dbLevel,dbfs,rms")
                w.newLine()
                w.flush()
            }
        } catch (e: Exception) {
            Log.e(TAG, "CSV open failed", e)
            record.release()
            return mapOf(
                "ok" to false,
                "error" to "CSV 파일 생성 실패: ${e.message}",
            )
        }

        currentMode = mode
        requestedSampleRate = mode.requestedRate
        actualSampleRate = resolved
        csvFile = outFile
        csvWriter = writer
        audioRecord = record
        minDb = Double.POSITIVE_INFINITY
        maxDb = Double.NEGATIVE_INFINITY
        sumDb = 0.0
        sampleCount = 0L
        latestDb = 0.0
        latestDbfs = 0.0
        latestRms = 0.0
        startedAtMs = System.currentTimeMillis()
        isRunning = true

        try {
            record.startRecording()
        } catch (e: Exception) {
            Log.e(TAG, "startRecording failed", e)
            stopInternal()
            return mapOf(
                "ok" to false,
                "error" to "녹음 시작 실패: ${e.message}",
            )
        }

        captureThread = Thread {
            val hopBuffer = ShortArray(hopSamples)
            val ringSquares = DoubleArray(windowSamples)
            var ringPos = 0
            var filled = 0
            var sumSquares = 0.0
            val aFilter = if (mode.useAWeighting) ApproxAWeightFilter(resolved) else null

            while (isRunning) {
                val read = audioRecord?.read(hopBuffer, 0, hopSamples) ?: 0
                if (read <= 0) {
                    try {
                        Thread.sleep(5)
                    } catch (_: InterruptedException) {
                        break
                    }
                    continue
                }

                for (i in 0 until read) {
                    val raw = hopBuffer[i] / 32768.0
                    val sample = aFilter?.process(raw) ?: raw
                    val sq = sample * sample
                    if (filled >= windowSamples) {
                        sumSquares -= ringSquares[ringPos]
                    } else {
                        filled++
                    }
                    ringSquares[ringPos] = sq
                    sumSquares += sq
                    ringPos = (ringPos + 1) % windowSamples
                }

                if (filled <= 0) continue

                val rms = sqrt(sumSquares / filled)
                val clampedRms = maxOf(rms, 1e-5)
                val dbfs = 20.0 * log10(clampedRms)
                val db = (dbfs + MIC_DBFS_TO_DB_OFFSET + CALIBRATION_OFFSET)
                    .coerceIn(0.0, 130.0)
                val elapsedMs = System.currentTimeMillis() - startedAtMs

                latestRms = rms
                latestDbfs = dbfs
                latestDb = db
                if (db < minDb) minDb = db
                if (db > maxDb) maxDb = db
                sumDb += db
                sampleCount++

                try {
                    csvWriter?.write(
                        "$elapsedMs,${"%.3f".format(Locale.US, db)}," +
                            "${"%.3f".format(Locale.US, dbfs)},${"%.8f".format(Locale.US, rms)}",
                    )
                    csvWriter?.newLine()
                } catch (e: Exception) {
                    Log.e(TAG, "CSV write failed", e)
                }

                emitLive(elapsedMs)
            }
        }.apply {
            name = "OTIS_NoiseTestCaptureThread"
            start()
        }

        Log.i(
            TAG,
            "started mode=${mode.id} req=${mode.requestedRate} act=$resolved " +
                "aWeight=${mode.useAWeighting} windowSec=${mode.windowSec} " +
                "file=${outFile.absolutePath}",
        )

        return mapOf(
            "ok" to true,
            "isRunning" to true,
            "modeId" to mode.id,
            "modeLabel" to mode.label,
            "requestedSampleRate" to mode.requestedRate,
            "actualSampleRate" to resolved,
            "aWeighting" to mode.useAWeighting,
            "windowSec" to mode.windowSec,
            "sessionId" to sessionId,
            "filePath" to outFile.absolutePath,
            "fileName" to outFile.name,
        )
    }

    /**
     * 작성: 2026-09-21 · 박희정
     * 함수: stop
     * 목적: 소음 테스트를 멈추고 CSV를 닫은 뒤 요약 맵을 돌려준다.
     */
    fun stop(): Map<String, Any?> {
        val summary = buildStatusMap(includeFile = true)
        stopInternal()
        return summary + mapOf("ok" to true, "isRunning" to false)
    }

    /**
     * 작성: 2026-09-21 · 박희정
     * 함수: getStatus
     * 목적: 현재 실행 상태·통계를 맵으로 돌려준다.
     */
    fun getStatus(): Map<String, Any?> = buildStatusMap(includeFile = true) + mapOf(
        "ok" to true,
        "isRunning" to isRunning,
    )

    private fun stopInternal() {
        isRunning = false
        try {
            captureThread?.interrupt()
            captureThread?.join(500)
        } catch (e: Exception) {
            Log.e(TAG, "Error joining thread", e)
        }
        captureThread = null

        try {
            if (audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                audioRecord?.stop()
            }
            audioRecord?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing AudioRecord", e)
        }
        audioRecord = null

        try {
            csvWriter?.flush()
            csvWriter?.close()
        } catch (e: Exception) {
            Log.e(TAG, "Error closing CSV", e)
        }
        csvWriter = null
    }

    private fun buildStatusMap(includeFile: Boolean): Map<String, Any?> {
        val mode = currentMode
        val avg = if (sampleCount > 0) sumDb / sampleCount else 0.0
        val min = if (sampleCount > 0) minDb else 0.0
        val max = if (sampleCount > 0) maxDb else 0.0
        val elapsed = if (startedAtMs > 0) {
            System.currentTimeMillis() - startedAtMs
        } else {
            0L
        }
        val base = mutableMapOf<String, Any?>(
            "modeId" to (mode?.id ?: ""),
            "modeLabel" to (mode?.label ?: ""),
            "requestedSampleRate" to requestedSampleRate,
            "actualSampleRate" to actualSampleRate,
            "aWeighting" to (mode?.useAWeighting ?: false),
            "windowSec" to (mode?.windowSec ?: 0.0),
            "sessionId" to sessionId,
            "latestDb" to latestDb,
            "dbLevel" to latestDb,
            "dbfs" to latestDbfs,
            "rms" to latestRms,
            "minDb" to min,
            "maxDb" to max,
            "avgDb" to avg,
            "elapsedMs" to elapsed,
            "sampleCount" to sampleCount,
            "isRunning" to isRunning,
        )
        if (includeFile) {
            base["filePath"] = csvFile?.absolutePath
            base["fileName"] = csvFile?.name
        }
        return base
    }

    private fun emitLive(elapsedMs: Long) {
        val sink = liveSink ?: return
        val mode = currentMode
        val avg = if (sampleCount > 0) sumDb / sampleCount else 0.0
        val min = if (sampleCount > 0) minDb else 0.0
        val max = if (sampleCount > 0) maxDb else 0.0
        val map: Map<String, Any?> = mapOf(
            "modeId" to (mode?.id ?: ""),
            "requestedSampleRate" to requestedSampleRate,
            "actualSampleRate" to actualSampleRate,
            "aWeighting" to (mode?.useAWeighting ?: false),
            "windowSec" to (mode?.windowSec ?: 0.0),
            "sessionId" to sessionId,
            "dbLevel" to latestDb,
            "dbfs" to latestDbfs,
            "rms" to latestRms,
            "minDb" to min,
            "maxDb" to max,
            "avgDb" to avg,
            "elapsedMs" to elapsedMs,
            "sampleCount" to sampleCount,
            "isRunning" to true,
        )
        mainHandler.post { sink(map) }
    }

    /**
     * 요청 레이트를 먼저 시도하고, 실패 시 후보 중 요청값에 가장 가까운
     * 레이트를 순서대로 시도한다.
     */
    private fun resolveSampleRate(requested: Int): Int? {
        if (canInitRate(requested)) return requested
        val ordered = FALLBACK_RATES.sortedBy { abs(it - requested) }
        for (rate in ordered) {
            if (canInitRate(rate)) return rate
        }
        return null
    }

    private fun canInitRate(rate: Int): Boolean {
        val minBuf = AudioRecord.getMinBufferSize(rate, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBuf == AudioRecord.ERROR || minBuf == AudioRecord.ERROR_BAD_VALUE) return false
        return try {
            val ar = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                rate,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                minBuf * 2,
            )
            val ok = ar.state == AudioRecord.STATE_INITIALIZED
            ar.release()
            ok
        } catch (_: Exception) {
            false
        }
    }
}

/**
 * 작성: 2026-09-21 · 박희정
 * 클래스: ApproxAWeightFilter
 * 목적: 근사 A가중 — 1차 HP(~100 Hz) + 1차 LP(~12 kHz) 캐스케이드.
 *       실험실급 IEC A-weighting이 아니다. 비교 테스트용 근사치다.
 */
private class ApproxAWeightFilter(sampleRate: Int) {
    private val hp = OnePoleHighPass(fcHz = 100.0, sampleRate = sampleRate)
    private val lp = OnePoleLowPass(fcHz = 12000.0, sampleRate = sampleRate)

    fun process(x: Double): Double = lp.process(hp.process(x))
}

/** 1차 고역통과(one-pole high-pass) */
private class OnePoleHighPass(fcHz: Double, sampleRate: Int) {
    private val a = exp(-2.0 * PI * fcHz / sampleRate)
    private var prevX = 0.0
    private var prevY = 0.0

    fun process(x: Double): Double {
        val y = a * (prevY + x - prevX)
        prevX = x
        prevY = y
        return y
    }
}

/** 1차 저역통과(one-pole low-pass) */
private class OnePoleLowPass(fcHz: Double, sampleRate: Int) {
    private val a = exp(-2.0 * PI * fcHz / sampleRate)
    private var prevY = 0.0

    fun process(x: Double): Double {
        val y = (1.0 - a) * x + a * prevY
        prevY = y
        return y
    }
}
