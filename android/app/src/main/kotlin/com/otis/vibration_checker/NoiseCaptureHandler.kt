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
 * 수정: 2026-10-04 13:50:15 · nada
 * 클래스: NoiseCaptureHandler
 * 목적: 측정하는 동안 마이크로 소음 크기(dBA)를 재서 `latestDba` 에
 *       채운다. 최근 `WINDOW_SEC` 만큼의 소리로 RMS(제곱 평균의 제곱근,
 *       소리 크기를 구하는 계산)를 내고, 그 창을 1초에 `HOP_HZ` 번씩
 *       밀며 값을 새로 낸다.
 *       권한이 없거나 초기화에 실패해도 앱을 죽이지 않고 0.0으로 대체한다.
 * 근거: 측정 — OTIS 소음계와 동시에 잰 비교에서 피크가 낮고 값이 계단처럼
 *       바뀌어, 창을 짧게 하고 더 자주 미는 실험값을 쓰고 있다
 *       (`docs/noise_otis_offset_notes.md`). 기본 오프셋의 근거는
 *       `DEFAULT_MIC_DBFS_TO_DBA_OFFSET` 을 본다
 */
class NoiseCaptureHandler(private val context: Context) {
    /**
     * 작성: 2026-07-04 12:00:10 · 박건준
     * 수정: 2026-10-04 13:50:15 · nada
     * 클래스: Companion
     * 목적: 마이크 녹음 설정과 소음 계산 설정을 모아 둔다.
     */
    companion object {
        /** 로그 태그 (Log.e 호출 시 출처를 이 이름으로 남긴다) */
        private const val TAG = "NoiseCaptureHandler"

        /** 1초에 소리를 몇 번 샘플링할지(Hz). 44100은 CD 음질과 같다 */
        private const val SAMPLE_RATE = 44100

        /** 한 채널(모노)만 받는다 */
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO

        /** 샘플 값을 16비트 정수로 받는다 */
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        /**
         * 작성: 2026-10-04 13:50:15 · nada
         * 변수: DEFAULT_MIC_DBFS_TO_DBA_OFFSET
         * 목적: Flutter 가 오프셋을 넘기지 않았을 때 쓰는 dBFS→dBA 기본
         *       오프셋. Flutter 는 늘 `kDefaultMicDbfsToDbaOffset`
         *       (lib/domain/capture/noise_offset.dart)을 넘기므로, 이 값은
         *       그 값과 같게 맞춰 둔다. Dart 와 코틀린은 상수를 함께 쓸 수
         *       없어 두 곳에 있다.
         * 근거: 인용 — `kDefaultMicDbfsToDbaOffset` 의 근거를 본다
         */
        const val DEFAULT_MIC_DBFS_TO_DBA_OFFSET = 87.3

        /**
         * 작성: 2026-09-21 17:37:25 · 박희정
         * 수정: 2026-10-04 13:50:15 · nada
         * 변수: WINDOW_SEC
         * 목적: RMS 창 길이(초). 짧을수록 순간 소리를 덜 평균 내 피크가
         *       살아난다.
         * 근거: 측정 — 0.125초 창에서 OTIS 소음계보다 피크가 눌려 보여
         *       줄여 보는 실험값이다 (`docs/noise_otis_offset_notes.md`)
         */
        private const val WINDOW_SEC = 0.03125

        /**
         * 작성: 2026-09-21 17:37:25 · 박희정
         * 수정: 2026-10-04 13:50:15 · nada
         * 변수: HOP_HZ
         * 목적: 소음값을 새로 내는 횟수(1초당). 진동 격자(256Hz)보다
         *       촘촘하게 `latestDba` 를 갱신해, 센서 이벤트에 같은 소음값이
         *       길게 붙는 일을 줄인다.
         * 근거: 미확인 — 512 를 고른 근거가 코드 · 문서에 없다
         */
        private const val HOP_HZ = 512
    }

    /**
     * 가장 최근에 계산한 소음 크기(dBA). 바깥에서는 읽기만 하고, 쓰는 것은
     * 이 클래스 안에서만 한다. 측정 전 · 권한 없음 · 창이 덜 찼으면 0.0
     */
    @Volatile
    var latestDba: Double = 0.0
        private set

    /** 마이크 녹음기. `start()` 가 만들고 `stop()` 이 풀어 비운다. 없으면 null */
    private var audioRecord: AudioRecord? = null

    /**
     * 녹음 스레드가 계속 돌지 여부. `stop()` 이 false 로 바꿔 멈춘다. 다른
     * 스레드가 바꾼 값을 녹음 스레드가 바로 보도록 @Volatile 로 둔다
     */
    @Volatile
    private var isRecording = false

    /** 마이크를 읽고 소음을 계산하는 스레드. 돌고 있지 않으면 null */
    private var captureThread: Thread? = null

    /**
     * 작성: 2026-09-15 13:20:00 · 박희정
     * 수정: 2026-10-04 13:50:15 · nada
     * 함수: start
     * 목적: 소음 측정을 시작한다. 이미 돌고 있으면 먼저 멈추고 다시 시작한다.
     *       권한이 없거나 AudioRecord 초기화에 실패하면 예외 없이 0.0으로 둔다.
     *
     *       창이 가득 차기 전에는 값을 내지 않고 0.0을 내보낸다. 덜 찬 창의
     *       RMS는 0에서 실제 크기로 천천히 올라오는 경사라서 값이 아니다.
     *       이 저장소는 0 dBA를 이미 미측정 표시로 쓰므로, 새 규칙을 만드는
     *       것이 아니라 재지 않은 값을 0으로 채우지 않는다는 기존 규칙을
     *       지키는 것이다.
     *       "준비됨"을 따로 실어 보내는 길을 안 고른 이유: 그 신호를 넣으면
     *       NativeEvent·GridSample·MeasurementResult까지 줄줄이 자리를
     *       만들어야 하는데, 받는 쪽은 결국 "값이 없다"로 똑같이 다룬다.
     *       대가: 매 측정의 첫 창 길이만큼이 통째로 미측정이 된다. 고치기 전에는
     *       0이 0.168초뿐이었고 그 뒤 약 1.2초가 경사였다. 리포트는 0인
     *       표본을 평균에서 빼므로, 평균이 경사에 끌려 내려가지 않는 대신
     *       그만큼 표본이 줄어든다.
     * 인자: calibrationOffsetDba — 현장·기기별 추가 보정(dBA)
     *       micDbfsToDbaOffset — dBFS→dBA 기본 오프셋. 기본은
     *       `DEFAULT_MIC_DBFS_TO_DBA_OFFSET`
     * 식:   windowSamples = SAMPLE_RATE × WINDOW_SEC  (창에 담는 표본 수)
     *       rms  = sqrt(창 안 표본 제곱의 합 / windowSamples)
     *              창이 가득 찬 뒤에만 센다. 덜 찼으면 0.0을 내보낸다
     *       dBFS = 20 × log10(rms)
     *       dBA  = dBFS + micDbfsToDbaOffset + calibrationOffsetDba
     *              (0~130으로 자름)
     */
    fun start(
        calibrationOffsetDba: Double,
        micDbfsToDbaOffset: Double = DEFAULT_MIC_DBFS_TO_DBA_OFFSET,
    ) {
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

        val minBufSize = // 이 기기가 요구하는 최소 녹음 버퍼 크기(바이트)
            AudioRecord.getMinBufferSize(SAMPLE_RATE, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.e(TAG, "Invalid buffer size for AudioRecord.")
            latestDba = 0.0
            return
        }

        val windowSamples = // RMS 창 하나에 담는 표본 수
            (SAMPLE_RATE * WINDOW_SEC).toInt().coerceAtLeast(1)
        val hopSamples = // 창을 한 번 밀 때 새로 읽는 표본 수
            (SAMPLE_RATE / HOP_HZ).coerceAtLeast(1)
        val bufferSize = // 녹음 버퍼 크기. 창 두 개는 담을 만큼 잡는다
            maxOf(minBufSize, windowSamples * 2)

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
                val hopBuffer = ShortArray(hopSamples) // 한 번에 읽어 올 표본
                // 표본 제곱값을 돌려 쓰는 고리 모양 저장소. 창을 밀 때 빠지는
                // 값만 빼고 들어온 값만 더해, 창 전체를 매번 다시 세지 않는다
                val ringSquares = DoubleArray(windowSamples) // 창 안 표본 제곱값
                var ringPos = 0 // 다음 제곱값을 넣을 자리
                var filled = 0 // 창에 찬 표본 수. 창 크기까지만 센다
                var sumSquares = 0.0 // 창 안 제곱값의 합
                var lastLogTimeMs = // 마지막으로 진단 기록을 남긴 시각(밀리초)
                    System.currentTimeMillis()

                while (isRecording) {
                    val read = // 이번에 실제로 읽은 표본 수
                        audioRecord?.read(hopBuffer, 0, hopSamples) ?: 0
                    if (read <= 0) {
                        try {
                            Thread.sleep(5)
                        } catch (_: InterruptedException) {
                            break
                        }
                        continue
                    }

                    for (i in 0 until read) {
                        val norm = hopBuffer[i] / 32768.0 // -1~1 로 맞춘 표본
                        val sq = norm * norm // 표본 제곱값
                        if (filled >= windowSamples) {
                            sumSquares -= ringSquares[ringPos]
                        } else {
                            filled++
                        }
                        ringSquares[ringPos] = sq
                        sumSquares += sq
                        ringPos = (ringPos + 1) % windowSamples
                    }

                    if (filled < windowSamples) {
                        // 덜 찬 창의 RMS는 값이 아니라 경사다. 미측정 표시인
                        // 0.0을 내보내고 다음 홉을 기다린다
                        latestDba = 0.0
                        continue
                    }

                    val rms = sqrt(sumSquares / windowSamples) // 창의 RMS
                    val clampedRms = // 무음에서 로그가 -무한대가 되지 않게 막은 RMS
                        maxOf(rms, 1e-5)
                    val dbfs = 20.0 * log10(clampedRms) // 마이크 신호 크기
                    val dba = // 소음 크기. 0~130 으로 자른다
                        (dbfs + micDbfsToDbaOffset + calibrationOffsetDba)
                            .coerceIn(0.0, 130.0)
                    // OTIS 장비 기록(EVIMP1, 회사 EVA 진동측정 장비가 쓰는 데이터
                    // 형식)처럼 소수 셋째 자리까지 남긴다
                    latestDba = (dba * 1000.0).roundToInt() / 1000.0

                    val nowMs = System.currentTimeMillis() // 지금 시각(밀리초)
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
     * 수정: 2026-10-05 10:03:35 · nada
     * 함수: stop
     * 목적: 소음 측정을 멈추고 마이크 자원을 반납한다. latestDba도 0.0으로 돌린다.
     *       순서를 지킨다. 녹음을 먼저 멈춰 녹음 스레드의 읽기를 풀고, 그
     *       스레드가 끝나길 기다린 뒤에 녹음기를 반납한다 — 읽는 중인
     *       녹음기를 다른 스레드에서 반납하면 앱이 죽을 수 있다.
     */
    fun stop() {
        isRecording = false
        val record = audioRecord // 멈추고 반납할 녹음기, 없으면 null
        try {
            if (record?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                record.stop()
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping AudioRecord", e)
        }
        try {
            captureThread?.interrupt()
            captureThread?.join(300)
        } catch (e: Exception) {
            Log.e(TAG, "Error joining thread", e)
        }
        captureThread = null

        try {
            record?.release()
        } catch (e: Exception) {
            Log.e(TAG, "Error releasing AudioRecord", e)
        }
        audioRecord = null
        latestDba = 0.0
    }
}

/**
 * 작성: 2026-07-04 12:00:10 · 박건준
 * 함수: roundToInt
 * 목적: 실수를 가장 가까운 정수로 반올림한다. `latestDba` 를 소수 셋째
 *       자리에서 자를 때 쓴다.
 * 반환: 반올림한 정수
 */
private fun Double.roundToInt(): Int = Math.round(this).toInt()
