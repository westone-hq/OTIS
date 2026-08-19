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
 * 클래스: NoiseCaptureHandler
 * 목적: 마이크로 주변 소음 크기(dBA)를 짧은 주기로 계산해 `latestDba`에
 *       채워 둔다. 마이크 권한이 없거나 초기화에 실패해도 앱을 죽이지
 *       않고 0.0으로 둔 채 넘어간다.
 */
class NoiseCaptureHandler(private val context: Context) {
    companion object {
        private const val TAG = "NoiseCaptureHandler"

        // 1초에 소리를 얼마나 잘게 쪼개 읽을지(Hz). 44100은 CD 음질과 같다
        private const val SAMPLE_RATE = 44100

        // 한 채널(모노)만 받는다
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO

        // 소리 값을 16비트 정수로 받는다
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT
    }

    /** 가장 최근에 계산한 소음 크기(dBA). 이 클래스 밖에서는 읽기만
     *  하고, 값을 바꾸는 것은 이 클래스 안에서만 한다. 시작 전이거나
     *  권한이 없으면 0.0 */
    @Volatile
    var latestDba: Double = 0.0
        private set

    /** 마이크에서 원본 소리를 읽어오는 객체. 아직 시작 전이거나
     *  정리한 뒤에는 null */
    private var audioRecord: AudioRecord? = null

    /** 지금 녹음 중인지 여부. false로 바뀌면 배경 스레드(thread, 동시에
     *  실행되는 작업의 흐름 하나)의 반복이 끝난다 */
    private var isRecording = false

    /** 소리를 계속 읽어 dBA를 계산하는 배경 스레드. 없으면 null */
    private var captureThread: Thread? = null

    /**
     * 함수: start
     * 목적: 소음 읽기를 시작한다. 이미 돌고 있으면 먼저 멈추고 다시
     *       시작한다. 마이크 권한이 없거나 `AudioRecord` 초기화에
     *       실패하면, 앱을 죽이지 않고 소음값을 0.0으로 둔 채
     *       조용히 끝낸다.
     * 인자: calibrationOffsetDba — 현장·기기마다 다른 오차를 보정하는 값
     *       micDbfsToDbaOffset — dBFS(마이크가 실제로 측정한 세기)를
     *       dBA(사람이 듣는 소음 크기 단위)로 바꿀 때 더하는 기준값.
     *       기기마다 마이크 감도가 달라 필요하다. 안 주면 85.0
     * 식: dBFS = 20 x log10(rms) — rms는 이번에 읽은 샘플들의
     *     제곱평균제곱근(소리 세기)
     *     dBA = dBFS + micDbfsToDbaOffset + calibrationOffsetDba
     *     (0~130 사이로 자른다)
     */
    fun start(calibrationOffsetDba: Double, micDbfsToDbaOffset: Double = 85.0) {
        stop()

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            // 권한 없이 AudioRecord를 만들면 SecurityException이 나므로
            // 미리 걸러서 0.0으로 두고 끝낸다
            Log.w(
                TAG,
                "RECORD_AUDIO permission not granted. Noise capture disabled (fallback to 0.0 dBA)."
            )
            latestDba = 0.0
            return
        }

        // 이 설정(샘플레이트 · 채널 · 포맷)으로 녹음하는 데 시스템이
        // 요구하는 최소 버퍼 크기
        val minBufSize = AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid buffer size for AudioRecord.")
            latestDba = 0.0
            return
        }

        // 0.125초 분량 샘플 수(약 5512개)
        val frameSamples = (SAMPLE_RATE * 0.125).toInt()
        // 시스템 최소값과 프레임 크기 중 큰 쪽
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
                val buffer = ShortArray(frameSamples) // 한 번에 읽어들일 샘플을 담을 칸
                // 마지막으로 현황을 남긴 시각
                var lastLogTimeMs = System.currentTimeMillis()
                while (isRecording) {
                    // 실제로 읽은 샘플 수
                    val read = audioRecord?.read(buffer, 0, frameSamples) ?: 0
                    if (read > 0) {
                        var sumSquares = 0.0 // 세기 계산용 제곱 합
                        for (i in 0 until read) {
                            val norm = buffer[i] / 32768.0 // 샘플값을 -1~1 범위로 정규화
                            sumSquares += norm * norm
                        }
                        val rms = sqrt(sumSquares / read) // 이번 조각의 소리 세기
                        // log10(0)은 정의되지 않으므로 최소값으로 올려 막는다
                        val clampedRms = maxOf(rms, 1e-5)
                        // 마이크가 실제로 측정한 세기(dBFS)
                        val dbfs = 20.0 * log10(clampedRms)
                        val dba = (dbfs + micDbfsToDbaOffset + calibrationOffsetDba)
                            .coerceIn(0.0, 130.0)
                        // 소수 첫째 자리로 반올림
                        latestDba = (dba * 10.0).roundToInt() / 10.0

                        val nowMs = System.currentTimeMillis() // 지금 시각
                        // 1초에 한 번만 현황을 남긴다 — 매 프레임마다 남기면 로그가 넘친다
                        if (nowMs - lastLogTimeMs >= 1000L) {
                            Log.i(
                                TAG,
                                "[Device: ${android.os.Build.MODEL}] Audio 1s Stats -> " +
                                    "dBFS: ${"%.1f".format(dbfs)}, dBA: $latestDba, " +
                                    "Offset: $micDbfsToDbaOffset"
                            )
                            lastLogTimeMs = nowMs
                        }
                    } else {
                        try {
                            // 읽은 게 없으면 바쁜 대기(busy loop)를 피해 잠깐 쉰다
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

    /**
     * 함수: stop
     * 목적: 소음 읽기를 멈추고 마이크 자원을 반납한다. 소음값도
     *       0.0으로 되돌린다.
     */
    fun stop() {
        isRecording = false
        try {
            captureThread?.interrupt()
            captureThread?.join(300) // 최대 0.3초까지 스레드 종료를 기다린다
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

/**
 * 함수: Double.roundToInt
 * 목적: 소수점 값을 반올림해 정수로 바꾼다. 이 파일 안에서만 쓰는
 *       작은 도우미다.
 * 반환: 반올림한 정수
 */
private fun Double.roundToInt(): Int = Math.round(this).toInt()
