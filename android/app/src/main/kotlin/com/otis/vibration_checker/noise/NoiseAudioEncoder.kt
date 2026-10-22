package com.otis.vibration_checker.noise

import android.media.MediaCodec
import android.media.MediaCodecInfo
import android.media.MediaFormat
import android.media.MediaMuxer
import android.util.Log
import java.io.File
import java.nio.ByteOrder

/**
 * 작성: 2026-10-18 10:12:30 · 박건준
 * 클래스: NoiseAudioEncoder
 * 목적: 측정 중 마이크 PCM(16비트 모노)을 AAC 로 압축해 M4A 파일 하나로
 *       남긴다. 메일에 "현장 소음" 으로 붙여 받는 쪽이 들어 볼 수 있게
 *       한다. 소음 크기(dBA) 계산에는 쓰지 않는다.
 *       `NoiseCaptureHandler` 의 녹음 스레드 하나만 `feed()` 를 부르고,
 *       그 스레드가 끝난 뒤 `finish()` 나 `abort()` 를 부른다 — 한 객체를
 *       두 스레드가 함께 만지지 않는다.
 *       안드로이드 기본 부품만 쓴다 — `MediaCodec`(기기에 든 압축기)으로
 *       AAC 를 만들고 `MediaMuxer`(압축한 조각을 재생 파일 틀에 담는 부품)로
 *       MP4 틀(.m4a)에 담는다.
 * 근거: 인용 — 2026-10-18 사용자 결정 "현장 소음 파일은 M4A(AAC, 기본
 *       내장)". MP3 는 안드로이드에 인코더가 없어 외부 라이브러리가 필요하다
 */
class NoiseAudioEncoder(
    /** 쓸 M4A 파일. 실패하면 `abort()` 가 지운다 */
    private val file: File,
    /** 입력 PCM 의 표본 속도(Hz). 녹음기와 같아야 한다 */
    private val sampleRate: Int,
) {
    /**
     * 작성: 2026-10-18 10:12:30 · 박건준
     * 클래스: Companion
     * 목적: 압축 설정과 압축기를 기다리는 한도를 모아 둔다.
     */
    companion object {
        /** 로그 태그 */
        private const val TAG = "NoiseAudioEncoder"

        /**
         * 작성: 2026-10-18 10:12:30 · 박건준
         * 변수: BIT_RATE
         * 목적: AAC 압축 비트율(초당 비트). 1분에 약 0.48MB 다.
         * 근거: 미정 — 메일 첨부 한도(흔히 25MB) 안에서 10분 측정도
         *       5MB 아래로 두려고 골랐다. 듣고 판단하는 용도라 음성 품질이면
         *       된다고 보았다. OTIS 가 원하는 음질이 정해지면 바꾼다
         */
        private const val BIT_RATE = 64_000

        /**
         * 작성: 2026-10-18 10:12:30 · 박건준
         * 변수: CHUNK_SAMPLES
         * 목적: 압축기에 한 번에 넘기는 표본 수. 녹음 스레드는 1초에 512 번
         *       86 표본씩 읽는데, 그대로 넘기면 압축기 호출이 너무 잦다.
         *       이만큼 모았다가 넘긴다.
         * 근거: 표준 — AAC 프레임 하나가 1024 표본이라 그 배수로 잡았다
         */
        private const val CHUNK_SAMPLES = 4096

        /**
         * 작성: 2026-10-18 10:12:30 · 박건준
         * 변수: TIMEOUT_US
         * 목적: 압축기의 빈 입력 칸 · 결과 조각을 한 번 기다리는 한도
         *       (마이크로초).
         * 근거: 미확인 — 녹음 스레드를 오래 붙잡지 않으려고 고른 값이다
         */
        private const val TIMEOUT_US = 10_000L

        /**
         * 작성: 2026-10-18 10:12:30 · 박건준
         * 변수: MAX_WAIT_TRIES
         * 목적: 빈 입력 칸 · 마지막 조각을 `TIMEOUT_US` 씩 기다리는 횟수
         *       한도. 넘으면 압축기가 멈춘 것으로 보고 녹음을 포기한다 —
         *       녹음 때문에 소음 측정 스레드가 멈추면 안 된다.
         * 근거: 미확인 — 1초(10ms × 100)를 고른 근거가 코드 · 문서에 없다
         */
        private const val MAX_WAIT_TRIES = 100
    }

    /** AAC 압축기. 생성자가 만들고 `release()` 가 반납한다 */
    private val codec: MediaCodec =
        MediaCodec.createEncoderByType(MediaFormat.MIMETYPE_AUDIO_AAC)

    /** M4A 파일에 압축 조각을 담는 부품. 생성자가 만들고 `release()` 가 반납한다 */
    private val muxer = MediaMuxer(file.path, MediaMuxer.OutputFormat.MUXER_OUTPUT_MPEG_4)

    /** 압축기에 넘기기 전에 표본을 모아 두는 칸 */
    private val pending = ShortArray(CHUNK_SAMPLES)

    /** `pending` 에 찬 표본 수 */
    private var pendingCount = 0

    /** 압축기에 넘긴 표본 수 누계. 조각의 재생 시각을 정하는 데 쓴다 */
    private var queuedSamples = 0L

    /** 파일에 실제로 쓴 조각 수. 0 이면 들을 것이 없는 파일이다 */
    private var writtenFrames = 0

    /** 파일 틀 안 소리 트랙 번호. 압축기가 형식을 알려 주기 전이면 -1 */
    private var track = -1

    /** 자원을 이미 반납했는지. 두 번 반납하지 않게 한다 */
    private var released = false

    /**
     * 끝 표시가 붙은 조각을 이미 받았는지. 끝 표시를 넣은 직후의
     * `drain()` 이 받아 버리면 `finish()` 의 `drain()` 이 더 기다리지 않게 한다
     */
    private var outputEnded = false

    init {
        val format = // 압축 설정 (AAC-LC, 모노)
            MediaFormat.createAudioFormat(MediaFormat.MIMETYPE_AUDIO_AAC, sampleRate, 1)
        format.setInteger(
            MediaFormat.KEY_AAC_PROFILE,
            MediaCodecInfo.CodecProfileLevel.AACObjectLC,
        )
        format.setInteger(MediaFormat.KEY_BIT_RATE, BIT_RATE)
        format.setInteger(MediaFormat.KEY_MAX_INPUT_SIZE, CHUNK_SAMPLES * 2)
        try {
            codec.configure(format, null, null, MediaCodec.CONFIGURE_FLAG_ENCODE)
            codec.start()
        } catch (e: Exception) {
            abort() // → 로직 이동: abort()
            throw e
        }
    }

    /**
     * 작성: 2026-10-18 10:12:30 · 박건준
     * 함수: feed
     * 목적: 녹음 스레드가 방금 읽은 표본을 받는다. `CHUNK_SAMPLES` 가 차면
     *       압축기에 넘긴다.
     * 인자: samples — 읽은 표본 (16비트 PCM)
     *       count — 앞에서부터 쓸 표본 수
     * 반환: 없음. 압축기가 멈췄거나 파일 쓰기가 실패하면 예외를 올린다.
     *       부르는 쪽(`NoiseCaptureHandler`)이 잡아 `abort()` 하고 녹음만
     *       포기한다
     */
    fun feed(samples: ShortArray, count: Int) {
        var offset = 0 // `samples` 에서 다음에 옮길 자리
        while (offset < count) {
            val n = minOf(count - offset, CHUNK_SAMPLES - pendingCount) // 옮길 수
            System.arraycopy(samples, offset, pending, pendingCount, n)
            pendingCount += n
            offset += n
            if (pendingCount == CHUNK_SAMPLES) {
                queuePending(endOfStream = false) // → 로직 이동: queuePending()
            }
        }
    }

    /**
     * 작성: 2026-10-18 10:12:30 · 박건준
     * 함수: finish
     * 목적: 남은 표본을 넘기고 끝 표시를 보낸 뒤, 마지막 조각까지 파일에
     *       담고 닫는다.
     * 반환: 다 쓴 M4A 파일 경로. 들을 조각이 하나도 없거나 닫다가
     *       실패하면 파일을 지우고 null
     */
    fun finish(): String? {
        return try {
            queuePending(endOfStream = true) // → 로직 이동: queuePending()
            drain(endOfStream = true) // → 로직 이동: drain()
            if (writtenFrames == 0) {
                abort() // → 로직 이동: abort()
                null
            } else {
                release() // → 로직 이동: release()
                file.path
            }
        } catch (e: Exception) {
            Log.e(TAG, "finish failed", e)
            abort() // → 로직 이동: abort()
            null
        }
    }

    /**
     * 작성: 2026-10-18 10:12:30 · 박건준
     * 함수: abort
     * 목적: 녹음을 포기한다. 자원을 반납하고 쓰다 만 파일을 지운다. 여러 번
     *       불러도 안전하다.
     */
    fun abort() {
        try {
            release() // → 로직 이동: release()
        } catch (e: Exception) {
            Log.e(TAG, "release failed", e)
        }
        if (file.exists() && !file.delete()) Log.w(TAG, "delete failed: ${file.path}")
    }

    /**
     * 작성: 2026-10-18 10:12:30 · 박건준
     * 함수: queuePending
     * 목적: 모아 둔 표본을 압축기의 빈 입력 칸에 넣고, 그사이 나온 조각을
     *       파일에 담는다. 빈 칸이 없으면 조각을 빼내 칸을 비우며
     *       `MAX_WAIT_TRIES` 번까지 기다린다.
     *       입력 칸이 모아 둔 양보다 작으면 칸 크기만큼씩 나눠 넣는다 —
     *       압축기는 `KEY_MAX_INPUT_SIZE` 요청을 따르지 않을 수 있다.
     * 인자: endOfStream — true 면 마지막 입력에 끝 표시를 붙인다(남은 표본이
     *       0개여도 끝 표시만 보낸다)
     * 반환: 없음. 빈 칸을 끝내 얻지 못하면 `IllegalStateException`
     * 식:   재생 시각(마이크로초) = queuedSamples × 1,000,000 / sampleRate
     */
    private fun queuePending(endOfStream: Boolean) {
        if (pendingCount == 0 && !endOfStream) return
        do {
            var tries = 0 // 빈 입력 칸을 기다린 횟수
            var index = // 빈 입력 칸 번호, 없으면 음수
                codec.dequeueInputBuffer(TIMEOUT_US)
            while (index < 0) {
                drain(endOfStream = false) // → 로직 이동: drain()
                if (++tries >= MAX_WAIT_TRIES) error("no input buffer")
                index = codec.dequeueInputBuffer(TIMEOUT_US)
            }
            val input = // 빈 입력 칸
                codec.getInputBuffer(index) ?: error("null input buffer")
            input.clear()
            // 표본 하나도 못 담는 칸이면 같은 자리를 끝없이 돌게 되어 멈춘다
            if (input.capacity() < 2) error("input buffer too small")
            val n = minOf(pendingCount, input.capacity() / 2) // 이번에 넣을 표본 수
            input.order(ByteOrder.nativeOrder()).asShortBuffer().put(pending, 0, n)
            val last = n == pendingCount // 모아 둔 표본을 다 넣는 입력인지
            val ptsUs = queuedSamples * 1_000_000L / sampleRate // 이 입력의 재생 시각
            codec.queueInputBuffer(
                index,
                0,
                n * 2,
                ptsUs,
                if (endOfStream && last) MediaCodec.BUFFER_FLAG_END_OF_STREAM else 0,
            )
            queuedSamples += n
            System.arraycopy(pending, n, pending, 0, pendingCount - n)
            pendingCount -= n
            drain(endOfStream = false) // → 로직 이동: drain()
        } while (pendingCount > 0)
    }

    /**
     * 작성: 2026-10-18 10:12:30 · 박건준
     * 수정: 2026-10-20 12:31:05 · 박건준
     * 함수: drain
     * 목적: 압축기가 내놓은 조각을 파일에 담는다. 첫 조각 전에 압축기가
     *       알려 주는 형식으로 파일 틀의 소리 트랙을 만든다. 끝 조각을
     *       받았으면(`outputEnded`) 압축기에 더 묻지 않는다 — 끝 뒤에는
     *       나올 조각이 없어, 기다리면 한도(약 1초)만큼 정지가 늦어진다.
     * 인자: endOfStream — true 면 끝 표시가 붙은 조각이 나올 때까지
     *       `MAX_WAIT_TRIES` 번 기다린다. false 면 지금 나온 것만 담는다
     * 근거: 측정 — 2026-10-20 에뮬레이터(API 36.1) 측정에서 끝 표시를 넣은
     *       직후의 `drain()` 이 끝 조각을 받아, `finish()` 가 1초를 다
     *       기다린 뒤 "end of stream not reached" 를 남겼다
     */
    private fun drain(endOfStream: Boolean) {
        val info = MediaCodec.BufferInfo() // 나온 조각의 크기 · 시각 · 표시
        var tries = 0 // 끝 조각을 기다린 횟수
        while (!outputEnded) {
            val index = // 나온 조각 번호, 아니면 상태 값(음수)
                codec.dequeueOutputBuffer(info, if (endOfStream) TIMEOUT_US else 0L)
            when {
                index == MediaCodec.INFO_TRY_AGAIN_LATER -> {
                    if (!endOfStream) return
                    if (++tries >= MAX_WAIT_TRIES) {
                        Log.w(TAG, "end of stream not reached; closing with what we have")
                        return
                    }
                }
                index == MediaCodec.INFO_OUTPUT_FORMAT_CHANGED -> {
                    track = muxer.addTrack(codec.outputFormat)
                    muxer.start()
                }
                index >= 0 -> {
                    val output = // 나온 조각
                        codec.getOutputBuffer(index) ?: error("null output buffer")
                    // 형식 정보 조각은 트랙을 만들 때 이미 들어갔다
                    val isConfig = (info.flags and MediaCodec.BUFFER_FLAG_CODEC_CONFIG) != 0
                    if (info.size > 0 && !isConfig && track >= 0) {
                        output.position(info.offset)
                        output.limit(info.offset + info.size)
                        muxer.writeSampleData(track, output, info)
                        writtenFrames++
                    }
                    codec.releaseOutputBuffer(index, false)
                    if ((info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM) != 0) {
                        outputEnded = true
                    }
                }
            }
        }
    }

    /**
     * 작성: 2026-10-18 10:12:30 · 박건준
     * 함수: release
     * 목적: 압축기와 파일 틀 부품을 닫고 반납한다. 트랙을 연 뒤에만 파일
     *       틀을 닫는다 — 열지 않은 틀을 닫으면 예외가 난다. 두 번 부르면
     *       아무것도 하지 않는다.
     */
    private fun release() {
        if (released) return
        released = true
        try {
            codec.stop()
        } catch (e: Exception) {
            Log.w(TAG, "codec stop failed", e)
        }
        codec.release()
        try {
            if (track >= 0) muxer.stop()
        } finally {
            muxer.release()
        }
    }
}
