package com.otis.vibration_checker.noise

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.media.AudioFormat
import android.media.AudioRecord
import android.media.MediaRecorder
import android.util.Log
import androidx.core.content.ContextCompat
import java.io.File
import kotlin.math.exp
import kotlin.math.log10
import kotlin.math.sqrt

/**
 * 작성: 2026-09-15 13:20:00 · 박희정
 * 수정: 2026-10-22 16:20:00 · 박건준
 * 클래스: NoiseCaptureHandler
 * 목적: 측정하는 동안 마이크로 소음 크기(dBA)를 재서 `latestDba` 에
 *       채운다. 표본마다 A 가중(`A_WEIGHTING_SOS`)을 건 뒤, 최근
 *       `WINDOW_SEC` 만큼의 소리로 RMS(제곱 평균의 제곱근, 소리 크기를
 *       구하는 계산)를 내고, 그 창을 1초에 `HOP_HZ` 번씩 밀며 값을 새로
 *       낸다. A 가중은 2026-10-20 에 넣었다 — 그 전 빌드의 값은 가중 없이
 *       오프셋 87.3 을 더한 값이다.
 *       같은 마이크 표본을 `NoiseAudioEncoder` 로 M4A 파일(현장 소음
 *       녹음)에도 남긴다. 녹음은 듣는 용도이고 dBA 계산과 따로 돈다 —
 *       녹음이 실패해도 dBA 는 계속 잰다.
 *       권한이 없거나 초기화에 실패해도 앱을 죽이지 않고 0.0으로 대체한다.
 * 근거: 측정 — OTIS 소음계와 동시에 잰 비교에서 피크가 낮고 값이 계단처럼
 *       바뀌어, 창을 짧게 하고 더 자주 미는 실험값을 쓰고 있다
 *       (`docs/experiments/noise_otis_offset_notes.md`). 기본 오프셋의 근거는
 *       `DEFAULT_MIC_DBFS_TO_DBA_OFFSET` 을 본다
 */
class NoiseCaptureHandler(private val context: Context) {
    /**
     * 작성: 2026-07-04 12:00:10 · 박건준
     * 수정: 2026-10-04 13:50:15 · 박건준
     * 클래스: Companion
     * 목적: 마이크 녹음 설정과 소음 계산 설정을 모아 둔다.
     */
    companion object {
        /** 로그 태그 (Log.e 호출 시 출처를 이 이름으로 남긴다) */
        private const val TAG = "NoiseCaptureHandler"

        /**
         * 작성: 2026-10-22 12:00:00 · 박건준
         * 변수: PREFERRED_SAMPLE_RATE
         * 목적: 마이크를 먼저 열어 보는 표본 속도(Hz). 이 기기에서 열리지
         *       않으면 `FALLBACK_SAMPLE_RATE` 로 연다(`openRecord()`).
         * 근거: 인용 — 2026-10-22 사용자 지시 "48000hz 로 변경". 많은 폰이
         *       마이크를 48kHz 로 돌려 안드로이드 안 변환을 한 번 덜 거치고,
         *       A 가중 쌍일차 변환의 높은 대역 오차가 줄어든다(8kHz −0.66 →
         *       −0.54, 16kHz −8.52 → −6.43 dB)
         */
        private const val PREFERRED_SAMPLE_RATE = 48000

        /**
         * 작성: 2026-10-22 12:00:00 · 박건준
         * 변수: FALLBACK_SAMPLE_RATE
         * 목적: 48kHz 를 열지 못할 때 쓰는 표본 속도(Hz).
         * 근거: 표준 — 안드로이드가 모든 기기에서 보장하는 녹음 표본 속도는
         *       44100Hz 뿐이다(AudioRecord 문서)
         */
        private const val FALLBACK_SAMPLE_RATE = 44100

        /** 한 채널(모노)만 받는다 */
        private const val CHANNEL_CONFIG = AudioFormat.CHANNEL_IN_MONO

        /** 샘플 값을 16비트 정수로 받는다 */
        private const val AUDIO_FORMAT = AudioFormat.ENCODING_PCM_16BIT

        /**
         * 작성: 2026-10-04 13:50:15 · 박건준
         * 수정: 2026-10-20 17:10:22 · 박건준
         * 변수: DEFAULT_MIC_DBFS_TO_DBA_OFFSET
         * 목적: Flutter 가 오프셋을 넘기지 않았을 때 쓰는 A 가중 dBFS→dBA
         *       기본 오프셋. Flutter 는 늘 `kDefaultMicDbfsToDbaOffset`
         *       (lib/domain/config/noise_config.dart)을 넘기므로, 이 값은
         *       그 값과 같게 맞춰 둔다. Dart 와 코틀린은 상수를 함께 쓸 수
         *       없어 두 곳에 있다.
         * 근거: 인용 — `kDefaultMicDbfsToDbaOffset` 의 근거를 본다
         */
        const val DEFAULT_MIC_DBFS_TO_DBA_OFFSET = 105.2

        /**
         * 작성: 2026-10-20 17:10:22 · 박건준
         * 변수: A_WEIGHTING_SOS
         * 목적: A 가중(사람 귀가 소리 높이마다 다르게 느끼는 만큼 깎는 보정)
         *       필터 계수. 2차 필터 세 단을 이어 건다. 한 단은
         *       [b0, b1, b2, a0, a1, a2] 이고 a0 는 1 이다. 1kHz 에서 0 dB 다.
         *       44100Hz(`FALLBACK_SAMPLE_RATE`) 전용이다. 48kHz 는
         *       `A_WEIGHTING_SOS_48000` 을 쓴다(`weightingFor()`).
         * 근거: 표준 — IEC 61672-1 A 가중의 아날로그 극(20.6 · 107.7 ·
         *       737.9 · 12194 Hz)을 쌍일차 변환으로 44100Hz 에 옮겼다(SciPy
         *       `bilinear_zpk` → `zpk2sos`). 표준 표와 31.5Hz ~ 4kHz 에서
         *       0.1 dB 안이고, 8kHz −0.7 · 16kHz −8.6 dB 더 깎인다(변환이 높은
         *       대역을 눌러 담는 성질). 승강기 소음은 대부분 이보다 낮다.
         *       측정 — 2026-10-20 오티스폰 · 테스트폰 동시 기록 3건에서 이
         *       가중을 넣으니 오티스 소음 곡선과의 상관이 0.88 ~ 0.90 →
         *       0.96 ~ 0.98 로 올랐다(docs/experiments/noise_otis_offset_notes.md)
         */
        private val A_WEIGHTING_SOS = arrayOf(
            doubleArrayOf(
                0.2555878203785177, 0.5111756407570354, 0.2555878203785177,
                1.0, -0.14053608242071078, 0.004937597615540203,
            ),
            doubleArrayOf(1.0, -2.0, 1.0, 1.0, -1.884901217428792, 0.8864214718161674),
            doubleArrayOf(1.0, -2.0, 1.0, 1.0, -1.9941388812663283, 0.9941474694445309),
        )

        /**
         * 작성: 2026-10-22 12:00:00 · 박건준
         * 변수: A_WEIGHTING_SOS_48000
         * 목적: `A_WEIGHTING_SOS` 와 같은 A 가중을 48000Hz
         *       (`PREFERRED_SAMPLE_RATE`)에 옮긴 계수.
         * 근거: 표준 — `A_WEIGHTING_SOS` 와 같은 방법(SciPy 1.16.3
         *       `bilinear_zpk` → `zpk2sos`, 1kHz 0 dB 맞춤). 같은 방법으로
         *       44100Hz 계수를 다시 만들면 위 값과 모든 자리가 같다. 시험
         *       `test/domain/config/noise_weighting_test.dart` 가 SciPy 픽스처와
         *       대조한다
         */
        private val A_WEIGHTING_SOS_48000 = arrayOf(
            doubleArrayOf(
                0.23418304260356063, 0.46836608520712125, 0.23418304260356063,
                1.0, -0.22455845805977914, 0.012606625271546396,
            ),
            doubleArrayOf(1.0, -2.0, 1.0, 1.0, -1.8938704947230707, 0.8951597690946617),
            doubleArrayOf(1.0, -2.0, 1.0, 1.0, -1.9946144559930215, 0.9946217070140843),
        )

        /**
         * 작성: 2026-09-21 17:37:25 · 박희정
         * 수정: 2026-10-04 13:50:15 · 박건준
         * 변수: WINDOW_SEC
         * 목적: RMS 창 길이(초). 짧을수록 순간 소리를 덜 평균 내 피크가
         *       살아난다.
         * 근거: 측정 — 0.125초 창에서 OTIS 소음계보다 피크가 눌려 보여
         *       줄여 보는 실험값이다 (`docs/experiments/noise_otis_offset_notes.md`)
         */
        private const val WINDOW_SEC = 0.03125

        /**
         * 작성: 2026-10-12 17:20:16 · 박희정
         * 수정: 2026-10-22 16:20:00 · 박건준
         * 변수: FAST_TIME_WEIGHT_SEC
         * 목적: 소음 RMS에 적용하는 지수평활의 시간 상수(초). 홉마다 새로
         *       들어오는 평균 제곱값을 이 상수로 평활해, 소음계의 "Fast"
         *       응답과 비슷한 반응 속도를 낸다. 2026-10-22 에 잠시 Slow(1초)로
         *       바꿨다가 같은 날 되돌렸다 — 소음 평균은 이 Fast 값으로 내고,
         *       최대만 Dart 가 이 값에 1초 평활을 더해 낸다(`NoiseSlow`).
         * 근거: 표준 — IEC 61672-1 의 "Fast" 시간가중 시정수(0.125초)
         */
        private const val FAST_TIME_WEIGHT_SEC = 0.125

        /**
         * 작성: 2026-09-21 17:37:25 · 박희정
         * 수정: 2026-10-04 13:50:15 · 박건준
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
     * 이번 측정에서 실제로 연 마이크 표본 속도(Hz). 48000 을 못 열면 44100.
     * 열지 못했거나 측정 전이면 0. `stop()` 뒤에도 다음 `start()` 까지 남겨
     * Flutter 가 정지 응답으로 받아 가게 한다
     */
    @Volatile
    var activeSampleRate: Int = 0
        private set

    /**
     * 현장 소음 녹음기. `start()` 가 만들고, 녹음 스레드가 표본을 넣으며,
     * `stop()` 이 스레드가 끝난 뒤 파일을 닫는다. 녹음 중이 아니거나 녹음이
     * 실패해 포기했으면 null
     */
    private var audioEncoder: NoiseAudioEncoder? = null

    /**
     * 작성: 2026-09-15 13:20:00 · 박희정
     * 수정: 2026-10-22 12:00:00 · 박건준
     * 함수: start
     * 목적: 소음 측정을 시작한다. 이미 돌고 있으면 먼저 멈추고 다시 시작한다
     *       — 그때 닫힌 앞 녹음은 받아 갈 곳이 없어 지운다.
     *       권한이 없거나 AudioRecord 초기화에 실패하면 예외 없이 0.0으로 둔다.
     *       현장 소음 녹음(`openAudioEncoder()`)도 함께 켜고, 녹음 스레드가
     *       읽은 표본을 그대로 넣는다. 녹음이 실패하면 녹음만 포기한다.
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
     *       마이크는 48000Hz 로 먼저 열고, 못 열면 44100Hz 로 연다
     *       (`openRecord()`). 연 속도는 `activeSampleRate` 에 남기고, A 가중
     *       계수도 그 속도의 것을 쓴다(`weightingFor()`).
     * 식:   windowSamples = 표본 속도 × WINDOW_SEC  (창에 담는 표본 수)
     *       표본 = A 가중(`aWeight()`)을 건 표본. 녹음 파일에는 가중 전
     *              표본을 넣는다
     *       meanSquare = 창 안 표본 제곱의 합 / windowSamples
     *                    창이 가득 찬 뒤에만 센다. 덜 찼으면 0.0을 내보낸다
     *       alpha = exp(-(이번 홉 표본 수 / 표본 속도) / FAST_TIME_WEIGHT_SEC)
     *       weightedMeanSquare = alpha × 이전 weightedMeanSquare
     *                            + (1 - alpha) × meanSquare
     *                            첫 창은 평활 없이 meanSquare 그대로 쓴다
     *       rms  = sqrt(weightedMeanSquare)
     *       dBFS = 20 × log10(rms)
     *       dBA  = dBFS + micDbfsToDbaOffset + calibrationOffsetDba
     *              (0~130으로 자름)
     */
    fun start(
        calibrationOffsetDba: Double,
        micDbfsToDbaOffset: Double = DEFAULT_MIC_DBFS_TO_DBA_OFFSET,
    ) {
        stopAndDiscardAudio() // → 로직 이동: stopAndDiscardAudio()

        if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO)
            != PackageManager.PERMISSION_GRANTED
        ) {
            Log.w(
                TAG,
                "RECORD_AUDIO permission not granted. Noise capture disabled (fallback to 0.0 dBA).",
            )
            activeSampleRate = 0
            latestDba = 0.0
            return
        }

        try {
            // → 로직 이동: openRecord()
            val opened = // 연 녹음기와 표본 속도, 둘 다 못 열면 null
                openRecord(PREFERRED_SAMPLE_RATE) ?: openRecord(FALLBACK_SAMPLE_RATE)
            if (opened == null) {
                Log.e(TAG, "AudioRecord failed to initialize at 48000 and 44100 Hz.")
                activeSampleRate = 0
                latestDba = 0.0
                return
            }
            audioRecord = opened.first
            val sampleRate = opened.second // 이번 측정의 표본 속도(Hz)
            activeSampleRate = sampleRate
            // → 로직 이동: weightingFor()
            val weighting = weightingFor(sampleRate) // 이 속도의 A 가중 계수
            val windowSamples = // RMS 창 하나에 담는 표본 수
                (sampleRate * WINDOW_SEC).toInt().coerceAtLeast(1)
            val hopSamples = // 창을 한 번 밀 때 새로 읽는 표본 수
                (sampleRate / HOP_HZ).coerceAtLeast(1)

            isRecording = true
            audioRecord?.startRecording()
            // → 로직 이동: openAudioEncoder()
            audioEncoder = openAudioEncoder(sampleRate)

            captureThread = Thread {
                val hopBuffer = ShortArray(hopSamples) // 한 번에 읽어 올 표본
                // A 가중 필터 세 단의 상태(단마다 지연 값 두 개). 측정마다 0 에서
                // 시작한다
                val aState = Array(weighting.size) { DoubleArray(2) }
                // 표본 제곱값을 돌려 쓰는 고리 모양 저장소. 창을 밀 때 빠지는
                // 값만 빼고 들어온 값만 더해, 창 전체를 매번 다시 세지 않는다
                val ringSquares = DoubleArray(windowSamples) // 창 안 표본 제곱값
                var ringPos = 0 // 다음 제곱값을 넣을 자리
                var filled = 0 // 창에 찬 표본 수. 창 크기까지만 센다
                var sumSquares = 0.0 // 창 안 제곱값의 합
                var lastLogTimeMs = // 마지막으로 진단 기록을 남긴 시각(밀리초)
                    System.currentTimeMillis()

                var fastWeightedMeanSquare: Double? = // Fast 평활 상태. 첫 창은 null
                    null
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

                    audioEncoder?.let { encoder ->
                        try {
                            // → 로직 이동: NoiseAudioEncoder.feed()
                            encoder.feed(hopBuffer, read)
                        } catch (e: Exception) {
                            Log.e(TAG, "noise audio encode failed; recording dropped", e)
                            // → 로직 이동: NoiseAudioEncoder.abort()
                            encoder.abort()
                            audioEncoder = null
                        }
                    }

                    for (i in 0 until read) {
                        val norm = hopBuffer[i] / 32768.0 // -1~1 로 맞춘 표본
                        // → 로직 이동: aWeight()
                        val weighted = // A 가중한 표본
                            aWeight(norm, weighting, aState)
                        val sq = weighted * weighted // 가중한 표본 제곱값
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

                    val meanSquare = // 창의 평균 제곱값(Fast 평활 전)
                        sumSquares / windowSamples
                    val alpha = // 이번 홉 길이에 맞춘 지수평활 감쇠율(0~1)
                        exp(-(read.toDouble() / sampleRate) / FAST_TIME_WEIGHT_SEC)
                    val weightedMeanSquare = // Fast 시간가중을 적용한 평균 제곱값
                        fastWeightedMeanSquare?.let { previous ->
                            alpha * previous + (1.0 - alpha) * meanSquare
                        } ?: meanSquare
                    fastWeightedMeanSquare = weightedMeanSquare

                    val rms = sqrt(weightedMeanSquare) // 평활된 창의 RMS
                    val clampedRms = // 무음에서 로그가 -무한대가 되지 않게 막은 RMS
                        maxOf(rms, 1e-5)
                    val dbfs = 20.0 * log10(clampedRms) // 마이크 신호 크기
                    val dba = // 소음 크기. 0~130 으로 자른다
                        (dbfs + micDbfsToDbaOffset + calibrationOffsetDba)
                            .coerceIn(0.0, 130.0)
                    // 참고 EVIMP1 처럼 소수 셋째 자리까지 남긴다
                    latestDba = (dba * 1000.0).roundToInt() / 1000.0

                    val nowMs = System.currentTimeMillis() // 지금 시각(밀리초)
                    if (nowMs - lastLogTimeMs >= 1000L) {
                        Log.i(
                            TAG,
                            "[Device: ${android.os.Build.MODEL}] Audio 1s Stats -> " +
                                "dBFS: ${"%.1f".format(dbfs)}, dBA: $latestDba, " +
                                "Offset: $micDbfsToDbaOffset, Rate: $sampleRate",
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
            stopAndDiscardAudio() // → 로직 이동: stopAndDiscardAudio()
            latestDba = 0.0
        } catch (e: Exception) {
            Log.e(TAG, "Exception starting AudioRecord", e)
            stopAndDiscardAudio() // → 로직 이동: stopAndDiscardAudio()
            latestDba = 0.0
        }
    }

    /**
     * 작성: 2026-10-22 12:00:00 · 박건준
     * 함수: openRecord
     * 목적: 주어진 표본 속도로 마이크 녹음기를 연다.
     * 인자: sampleRate — 표본 속도(Hz)
     * 반환: (녹음기, 표본 속도). 이 기기가 그 속도를 지원하지 않거나 초기화에
     *       실패하면 null — 부르는 쪽이 다음 속도를 시도한다
     */
    private fun openRecord(sampleRate: Int): Pair<AudioRecord, Int>? {
        val minBufSize = // 이 기기가 요구하는 최소 녹음 버퍼 크기(바이트)
            AudioRecord.getMinBufferSize(sampleRate, CHANNEL_CONFIG, AUDIO_FORMAT)
        if (minBufSize == AudioRecord.ERROR || minBufSize == AudioRecord.ERROR_BAD_VALUE) {
            Log.w(TAG, "AudioRecord does not support $sampleRate Hz")
            return null
        }
        val windowSamples = // RMS 창 하나에 담는 표본 수
            (sampleRate * WINDOW_SEC).toInt().coerceAtLeast(1)
        val bufferSize = // 녹음 버퍼 크기. 창 두 개는 담을 만큼 잡는다
            maxOf(minBufSize, windowSamples * 2)
        val record = AudioRecord( // 연 녹음기
            MediaRecorder.AudioSource.MIC,
            sampleRate,
            CHANNEL_CONFIG,
            AUDIO_FORMAT,
            bufferSize,
        )
        if (record.state != AudioRecord.STATE_INITIALIZED) {
            Log.w(TAG, "AudioRecord failed to initialize at $sampleRate Hz")
            record.release()
            return null
        }
        return record to sampleRate
    }

    /**
     * 작성: 2026-10-22 12:00:00 · 박건준
     * 함수: weightingFor
     * 목적: 표본 속도에 맞는 A 가중 계수를 고른다.
     * 인자: sampleRate — 연 표본 속도(Hz). `PREFERRED_SAMPLE_RATE` 나
     *       `FALLBACK_SAMPLE_RATE` 만 온다(`openRecord()` 가 그 둘만 연다)
     * 반환: A 가중 2차 필터 세 단의 계수
     */
    private fun weightingFor(sampleRate: Int): Array<DoubleArray> =
        if (sampleRate == PREFERRED_SAMPLE_RATE) A_WEIGHTING_SOS_48000 else A_WEIGHTING_SOS

    /**
     * 작성: 2026-10-20 17:10:22 · 박건준
     * 수정: 2026-10-22 12:00:00 · 박건준
     * 함수: aWeight
     * 목적: 표본 하나에 A 가중 필터 세 단을 차례로 건다. 녹음 스레드가
     *       표본마다 부른다.
     * 인자: x — 가중 전 표본 (-1 ~ 1)
     *       weighting — 표본 속도에 맞는 계수(`weightingFor()`)
     *       state — 단마다 지연 값 두 개. 부를 때마다 갱신한다
     * 반환: 가중한 표본
     * 식:   단마다 (전치 직접형 II)
     *       y = b0·x + s0,  s0 = b1·x − a1·y + s1,  s1 = b2·x − a2·y
     */
    private fun aWeight(
        x: Double,
        weighting: Array<DoubleArray>,
        state: Array<DoubleArray>,
    ): Double {
        var value = x // 이 단에 들어가는 값
        for (k in weighting.indices) {
            val c = weighting[k] // 이 단의 계수
            val s = state[k] // 이 단의 지연 값
            val y = c[0] * value + s[0] // 이 단의 출력
            s[0] = c[1] * value - c[4] * y + s[1]
            s[1] = c[2] * value - c[5] * y
            value = y
        }
        return value
    }

    /**
     * 작성: 2026-10-18 10:12:30 · 박건준
     * 함수: openAudioEncoder
     * 목적: 현장 소음 녹음 파일을 앱 저장 공간 맨 위에 만들고 녹음기를
     *       준비한다. 측정 폴더는 Flutter 가 저장할 때 정하므로, 원본 기록
     *       (`SensorStreamHandler`)과 같이 여기 두었다가 Flutter 가 옮긴다.
     * 인자: sampleRate — 마이크를 연 표본 속도(Hz). 녹음 파일도 같은 속도다
     * 반환: 녹음기. 이 기기에서 AAC 압축기를 열지 못하면 null — 녹음 없이
     *       dBA 만 잰다
     */
    private fun openAudioEncoder(sampleRate: Int): NoiseAudioEncoder? {
        val dir = // 녹음 파일을 둘 앱 저장 공간
            context.getExternalFilesDir(null) ?: context.filesDir
        val file = // 이번 측정의 녹음 파일
            File(dir, "noise_native_${System.currentTimeMillis()}.m4a")
        return try {
            NoiseAudioEncoder(file, sampleRate)
        } catch (e: Exception) {
            Log.e(TAG, "noise audio encoder unavailable", e)
            if (file.exists()) file.delete()
            null
        }
    }

    /**
     * 작성: 2026-10-18 10:12:30 · 박건준
     * 함수: stopAndDiscardAudio
     * 목적: 측정을 멈추되 닫힌 녹음 파일은 지운다. 받아 갈 곳이 없는
     *       정지(다시 시작 전, 시작 실패, 화면 종료)에 쓴다 — 지우지 않으면
     *       앱 저장 공간에 쌓인다.
     */
    fun stopAndDiscardAudio() {
        val path = stop() // → 로직 이동: stop()
        if (path != null && !File(path).delete()) Log.w(TAG, "delete failed: $path")
    }

    /**
     * 작성: 2026-09-15 13:20:00 · 박희정
     * 수정: 2026-10-18 10:12:30 · 박건준
     * 함수: stop
     * 목적: 소음 측정을 멈추고 마이크 자원을 반납한다. latestDba도 0.0으로 돌린다.
     *       순서를 지킨다. 녹음을 먼저 멈춰 녹음 스레드의 읽기를 풀고, 그
     *       스레드가 끝나길 기다린 뒤에 녹음기를 반납한다 — 읽는 중인
     *       녹음기를 다른 스레드에서 반납하면 앱이 죽을 수 있다.
     *       현장 소음 녹음 파일도 스레드가 끝난 뒤에 닫는다 — 표본을 넣는
     *       스레드와 닫는 스레드가 겹치지 않게 한다.
     * 반환: 닫은 현장 소음 녹음(M4A) 경로. 녹음하지 않았거나 실패했으면 null
     */
    fun stop(): String? {
        isRecording = false
        val record = audioRecord // 멈추고 반납할 녹음기, 없으면 null
        try {
            if (record?.recordingState == AudioRecord.RECORDSTATE_RECORDING) {
                record.stop() // 먼저 read를 풀고 기록 스레드를 기다린다.
            }
            captureThread?.join()
        } catch (e: Exception) {
            Log.e(TAG, "Error stopping noise capture", e)
        }
        captureThread = null
        record?.release()
        audioRecord = null
        latestDba = 0.0
        // → 로직 이동: NoiseAudioEncoder.finish()
        val audioPath = audioEncoder?.finish() // 닫은 녹음 경로, 없으면 null
        audioEncoder = null
        return audioPath
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
