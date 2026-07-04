package com.otis.vibration_checker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import androidx.core.content.ContextCompat
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * P11 · 안드로이드 마이크 소음(dBA) 캡처 핸들러
 * - AudioRecord 44.1kHz mono -> 125ms 프레임 RMS -> dBFS
 * - dBA = dBFS + 기준오프셋(85.0) + calibrationOffsetDba
 * - RECORD_AUDIO 권한 거부 시 예외 없이 0.0 dBA(또는 N/A 처리용 기본값) 반환 (크래시 방지 규격)
 */
class NoiseCaptureHandler(private val context: Context) {
    companion object {
        private const val TAG = "NoiseCaptureHandler"
        private const val SAMPLE_RATE = 44100
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    @Volatile
    var latestDba: Double = 0.0
        private set

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var captureThread: Thread? = null

    fun start(calibrationOffsetDba: Double, micDbfsToDbaOffset: Double = 85.0) {
        stop()

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) 
            != PackageManager.PERMISSION_GRANTED) {
            Log.w(TAG, "RECORD_AUDIO permission not granted. Noise capture disabled (fallback to 0.0 dBA).")
            latestDba = 0.0
            return
        }

        val minBufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid buffer size for AudioRecord.")
            latestDba = 0.0
            return
        }

        // 125ms 프레임 크기 (44100 * 0.125 ~ 5512 샘플)
        val frameSamples = (SAMPLE_RATE * 0.125).toInt()
        val bufferSize = maxOf(minBufSize, frameSamples * 2)

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                Log.e(TAG, "AudioRecord failed to initialize.")
                audioRecord?.release()
                audioRecord = null
                latestDba = 0.0
                return
            }

            isRecording = true
            audioRecord?.startRecording()

            captureThread = Thread {
                val buffer = ShortArray(frameSamples)
                var lastLogTimeMs = System.currentTimeMillis()
                while (isRecording) {
                    val read = audioRecord?.read(buffer, 0, frameSamples) ?: 0
                    if (read > 0) {
                        var sumSquares = 0.0
                        for (i in 0 until read) {
                            val norm = buffer[i] / 32768.0
                            sumSquares += norm * norm
                        }
                        val rms = sqrt(sumSquares / read)
                        val clampedRms = maxOf(rms, 1e-5)
                        val dbfs = 20.0 * log10(clampedRms)
                        val dba = (dbfs + micDbfsToDbaOffset + calibrationOffsetDba).coerceIn(0.0, 130.0)
                        latestDba = (dba * 10.0).roundToInt() / 10.0

                        val nowMs = System.currentTimeMillis()
                        if (nowMs - lastLogTimeMs >= 1000L) {
                            Log.i(TAG, "[Device: ${android.os.Build.MODEL}] Audio 1s Stats -> dBFS: ${"%.1f".format(dbfs)}, dBA: $latestDba, Offset: $micDbfsToDbaOffset")
                            lastLogTimeMs = nowMs
                        }
                    } else {
                        try {
                            Thread.sleep(20)
                        } catch (e: InterruptedException) {
                            break
                        }
                    }
                }
            }.apply {
                name = "OTIS_NoiseCaptureThread"
                start()
            }
        } catch (e: SecurityException) {
            Log.e(TAG, "SecurityException starting AudioRecord", e)
            latestDba = 0.0
        } catch (e: Exception) {
            Log.e(TAG, "Exception starting AudioRecord", e)
            latestDba = 0.0
        }
    }

    fun stop() {
        isRecording = false
        try {
            captureThread?.interrupt()
            captureThread?.join(300)
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
        latestDba = 0.0
    }
}

private fun Double.roundToInt(): Int = Math.round(this).toInt()
