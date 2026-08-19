/*
 * 작성: 2026-08-19 10:35:00
 * 작성자: 박희정
 * 수정: 2026-08-19 13:25:00
 * 수정자: 박희정
 */
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
 * 마이크로 주변 소음 크기를 읽는 담당입니다.
 *
 * 짧은 시간마다 소리 세기를 계산해서
 * 가장 최근 값(latestDba)에 넣어 둡니다.
 * 마이크 권한이 없으면 앱을 멈추지 않고 0.0으로 둡니다.
 */
class NoiseCaptureHandler(private val context: Context) {
    companion object {
        /**
         * 기록장(Logcat)에서 이 담당 메시지를 찾을 때 쓰는 이름입니다.
         */
        private const val TAG = "NoiseCaptureHandler"

        /**
         * 1초에 소리를 몇 번 쪼개 읽을지입니다.
         * 44100이면 흔히 쓰는 CD 음질과 같습니다.
         */
        private const val SAMPLE_RATE = 44100

        /**
         * 소리는 한쪽(모노)만 받습니다.
         */
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO

        /**
         * 소리 숫자를 16비트 정수로 받습니다.
         */
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    /**
     * 가장 최근에 계산한 소음 크기입니다.
     *
     * 바깥에서는 읽기만 하고, 바꾸는 것은 이 담당 안에서만 합니다.
     * 처음 값은 0.0입니다.
     */
    @Volatile
    var latestDba: Double = 0.0
        private set

    /**
     * 마이크에서 날것 소리를 읽어 오는 도구입니다.
     * 아직 안 만들었거나 정리한 뒤에는 비어 있습니다.
     */
    private var audioRecord: AudioRecord? = null

    /**
     * 지금 녹음(계산) 중인지 표시합니다.
     * false면 반복을 멈춥니다.
     */
    private var isRecording = false

    /**
     * 소리를 계속 읽어 계산하는 배경 작업입니다.
     * 없으면 비어 있습니다.
     */
    private var captureThread: Thread? = null

    /**
     * 소음 읽기를 시작합니다.
     *
     * calibrationOffsetDba: 현장·기기 보정값입니다.
     * micDbfsToDbaOffset: 계산에 더하는 기준값입니다. 안 주면 85.0입니다.
     */
    fun start(calibrationOffsetDba: Double, micDbfsToDbaOffset: Double = 85.0) {
        // 이미 돌고 있으면 먼저 멈춥니다
        stop()

        // 마이크 권한이 없으면
        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            // 기록장에 경고를 남깁니다
            Log.w(
                TAG,
                "RECORD_AUDIO permission not granted. Noise capture disabled (fallback to 0.0 dBA)."
            )
            // 소음값을 0으로 둡니다
            latestDba = 0.0
            // 여기서 끝냅니다 (앱은 죽이지 않음)
            return
        }

        // 이 설정으로 녹음하려면 필요한 최소 공간 크기를 물어봅니다
        val minBufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        // 시스템이 “안 됨”이라고 하면
        if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
            // 오류를 기록합니다
            Log.e(TAG, "Invalid buffer size for AudioRecord.")
            // 소음값을 0으로 둡니다
            latestDba = 0.0
            // 끝냅니다
            return
        }

        // 0.125초 분량 소리 조각 개수입니다 (대략 5512개)
        val frameSamples = (SAMPLE_RATE * 0.125).toInt()
        // 시스템 최소값과 프레임 크기 중 더 큰 쪽을 씁니다
        val bufferSize = maxOf(minBufSize, frameSamples * 2)

        try {
            // 마이크용 녹음 도구를 만듭니다
            audioRecord = AudioRecord(
                MediaRecorder.AudioSource.MIC,
                SAMPLE_RATE,
                CHANNEL_CONFIG,
                AUDIO_FORMAT,
                bufferSize
            )

            // 제대로 준비되지 않았으면
            if (audioRecord?.state != AudioRecord.STATE_INITIALIZED) {
                // 오류를 기록합니다
                Log.e(TAG, "AudioRecord failed to initialize.")
                // 자원을 반납합니다
                audioRecord?.release()
                // 비웁니다
                audioRecord = null
                // 소음값을 0으로 둡니다
                latestDba = 0.0
                // 끝냅니다
                return
            }

            // 녹음 중이라고 표시합니다
            isRecording = true
            // 실제 녹음을 시작합니다
            audioRecord?.startRecording()

            // 배경에서 돌 작업을 만듭니다
            captureThread = Thread {
                // 한 덩어리 소리를 담을 칸입니다
                val buffer = ShortArray(frameSamples)
                // 마지막으로 기록한 시각입니다
                var lastLogTimeMs = System.currentTimeMillis()
                // 녹음 중이면 계속 반복합니다
                while (isRecording) {
                    // 마이크에서 소리를 읽어 칸에 넣습니다
                    val read = audioRecord?.read(buffer, 0, frameSamples) ?: 0
                    // 뭔가 읽혔으면
                    if (read > 0) {
                        // 세기 계산용 제곱 합입니다
                        var sumSquares = 0.0
                        // 읽은 개수만큼 돌립니다
                        for (i in 0 until read) {
                            // 숫자를 -1~1 근처로 나눕니다
                            val norm = buffer[i] / 32768.0
                            // 제곱을 더합니다
                            sumSquares += norm * norm
                        }
                        // 평균 세기를 구합니다
                        val rms = sqrt(sumSquares / read)
                        // 너무 작으면 최소값으로 올립니다 (계산 깨짐 방지)
                        val clampedRms = maxOf(rms, 1e-5)
                        // dB로 바꿉니다
                        val dbfs = 20.0 * log10(clampedRms)
                        // 보정값을 더하고 0~130 사이로 자릅니다
                        val dba = (dbfs + micDbfsToDbaOffset + calibrationOffsetDba)
                            .coerceIn(0.0, 130.0)
                        // 소수 첫째 자리로 반올림해 저장합니다
                        latestDba = (dba * 10.0).roundToInt() / 10.0

                        // 지금 시각입니다
                        val nowMs = System.currentTimeMillis()
                        // 1초에 한 번만 현황을 기록합니다
                        if (nowMs - lastLogTimeMs >= 1000L) {
                            Log.i(
                                TAG,
                                "[Device: ${android.os.Build.MODEL}] Audio 1s Stats -> " +
                                    "dBFS: ${"%.1f".format(dbfs)}, dBA: $latestDba, " +
                                    "Offset: $micDbfsToDbaOffset"
                            )
                            // 기록한 시각을 갱신합니다
                            lastLogTimeMs = nowMs
                        }
                    } else {
                        try {
                            // 읽은 게 없으면 잠깐 쉽니다
                            Thread.sleep(20)
                        } catch (e: InterruptedException) {
                            // 중단 신호가 오면 반복을 나갑니다
                            break
                        }
                    }
                }
            }.apply {
                // 작업 이름을 붙여 찾기 쉽게 합니다
                name = "OTIS_NoiseCaptureThread"
                // 배경 작업을 시작합니다
                start()
            }
        } catch (e: SecurityException) {
            // 권한 문제로 실패하면 기록하고 0으로 둡니다
            Log.e(TAG, "SecurityException starting AudioRecord", e)
            latestDba = 0.0
        } catch (e: Exception) {
            // 그 밖의 실패도 기록하고 0으로 둡니다
            Log.e(TAG, "Exception starting AudioRecord", e)
            latestDba = 0.0
        }
    }

    /**
     * 소음 읽기를 멈추고 자원을 반납합니다.
     * 소음값도 0으로 돌립니다.
     */
    fun stop() {
        // 반복이 끝나도록 표시를 끕니다
        isRecording = false
        try {
            // 자고 있는 작업을 깨웁니다
            captureThread?.interrupt()
            // 최대 0.3초까지 끝나길 기다립니다
            captureThread?.join(300)
        } catch (e: Exception) {
            // 기다리다 문제 나면 기록합니다
            Log.e(TAG, "Error joining thread", e)
        }
        // 작업 자리를 비웁니다
        captureThread = null

        try {
            // 아직 녹음 중이면 멈춥니다
            if (audioRecord?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                audioRecord?.stop()
            }
            // 마이크 자원을 반납합니다
            audioRecord?.release()
        } catch (e: Exception) {
            // 반납 중 문제면 기록합니다
            Log.e(TAG, "Error releasing AudioRecord", e)
        }
        // 녹음 도구를 비웁니다
        audioRecord = null
        // 소음값을 0으로 돌립니다
        latestDba = 0.0
    }
}

/**
 * 소수점 숫자를 반올림해서 정수로 바꿉니다.
 * 이 파일 안에서만 쓰는 작은 도우미입니다.
 */
private fun Double.roundToInt(): Int = Math.round(this).toInt()
