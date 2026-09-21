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
 * 작성: 2026-09-15 13:20:00 · 박희정
 * 수정: 2026-09-15 16:40:00 · 박희정
 * 클래스: NoiseCaptureHandler
 * 목적: 마이크에서 주변 소음 크기(dBA)를 EVIMP1 격자(256 Hz)에 맞춰
 *       자주 갱신해 `latestDba`에 채운다. Fast(≈0.125초) 길이의
 *       슬라이딩 창 RMS를 쓰고, 창은 격자 간격(~1/256초)마다 민다.
 *       권한이 없거나 초기화에 실패해도 앱을 죽이지 않고 0.0으로 대체한다.
 * 식:   dBFS = 20 × log10(rms)
 *       dBA  = dBFS + micDbfsToDbaOffset + calibrationOffsetDba  (0~130으로 자름)
 * 근거: 인용 — OI-4 임시 오프셋. 기본 micDbfsToDbaOffset=85.0,
 *       기기·현장 보정은 calibrationOffsetDba.
 *       Fast 창 + 256 Hz 홉 → 참고 EVIMP1처럼 행마다 소음이 미세하게 변한다.
 */
class NoiseCaptureHandler(private val context: Context) {
    companion object {
        private const val TAG = "NoiseCaptureHandler"
        /** 1초에 소리를 몇 번 샘플링할지(Hz). 44100은 CD 음질과 같다 */
        private const val SAMPLE_RATE = 44100
        /** 한 채널(모노)만 받는다 */
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO
        /** 샘플 값을 16비트 정수로 받는다 */
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
        /** Fast 계열 RMS 창 길이(초). ≈ IEC 61672 Fast */
        private const val WINDOW_SEC = 0.125
        /** EVIMP1 행 주기(Hz). 창을 이 간격으로 밀어 행마다 값이 바뀌게 한다 */
        private const val HOP_HZ = 256
    }

    /**
     * 변수: latestDba
     * 목적: 가장 최근에 계산한 소음 크기(dBA).
     *       바깥에서는 읽기만 하고, 쓰는 것은 이 클래스 안에서만 한다.
     */
    @Volatile
    var latestDba: Double = 0.0
        private set

    private var audioRecord: AudioRecord? = null
    private var isRecording = false
    private var captureThread: Thread? = null

    /**
     * 작성: 2026-09-15 13:20:00 · 박희정
     * 수정: 2026-09-15 16:40:00 · 박희정
     * 함수: start
     * 목적: 소음 측정을 시작한다. 이미 돌고 있으면 먼저 멈추고 다시 시작한다.
     *       권한이 없거나 AudioRecord 초기화에 실패하면 예외 없이 0.0으로 둔다.
     * 인자: calibrationOffsetDba — 현장·기기별 추가 보정(dBA)
     *       micDbfsToDbaOffset — dBFS→dBA 기본 오프셋(기본 85.0)
     */
    fun start(calibrationOffsetDba: Double, micDbfsToDbaOffset: Double = 85.0) {
        stop()

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(
                TAG,
                "RECORD_AUDIO permission not granted. Noise capture disabled (fallback to 0.0 dBA).",
            )
            latestDba = 0.0
            return
        }

        val minBufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid buffer size for AudioRecord.")
            latestDba = 0.0
            return
        }

        // Fast 창 ≈ 5512 샘플. 홉 ≈ 172 샘플(1/256초) → 초당 ~256회 갱신
        val windowSamples = (SAMPLE_RATE * WINDOW_SEC).toInt().coerceAtLeast(1)
        val hopSamples = (SAMPLE_RATE / HOP_HZ).coerceAtLeast(1)
        val bufferSize = maxOf(minBufSize, windowSamples * 2)

        try {
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize,
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
                val hopBuffer = ShortArray(hopSamples)
                // 제곱값 링 버퍼로 슬라이딩 창 RMS (창을 통째로 다시 안 셈)
                val ringSquares = DoubleArray(windowSamples)
                var ringPos = 0
                var filled = 0
                var sumSquares = 0.0
                var lastLogTimeMs = System.currentTimeMillis()

                while (isRecording) {
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
                        val norm = hopBuffer[i] / 32768.0
                        val sq = norm * norm
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
                    val dba = (dbfs + micDbfsToDbaOffset + calibrationOffsetDba)
                        .coerceIn(0.0, 130.0)
                    // 참고 EVIMP1 처럼 소수 셋째 자리까지 남긴다
                    latestDba = (dba * 1000.0).roundToInt() / 1000.0

                    val nowMs = System.currentTimeMillis()
                    if (nowMs - lastLogTimeMs >= 1000L) {
                        Log.i(
                            TAG,
                            "[Device: ${android.os.Build.MODEL}] Audio 1s Stats -> " +
                                "dBFS: ${"%.1f".format(dbfs)}, dBA: $latestDba, " +
                                "Offset: $micDbfsToDbaOffset",
                        )
                        lastLogTimeMs = nowMs
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

    /**
     * 작성: 2026-09-15 13:20:00 · 박희정
     * 함수: stop
     * 목적: 소음 측정을 멈추고 마이크 자원을 반납한다. latestDba도 0.0으로 돌린다.
     */
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
