package com.otis.vibration_checker

import android.content.Context
import android.media.AudioRecord
import android.media.AudioTimestamp
import android.os.Build
import android.os.SystemClock
import android.util.Log
import java.io.File
import java.io.BufferedOutputStream

/**
 * 클래스: NoiseSnapshot
 * 목적: 센서가 읽은 소음값과 계산 시각·표본 끝 위치를 함께 보존한다.
 */
data class NoiseSnapshot(val value: Double, val calculatedNs: Long, val frameEnd: Long)

/**
 * 클래스: NoiseDiagnostics
 * 목적: new/dB 실험용 MIC PCM과 시각을 앱 외장 저장소에 보존한다.
 *       쓰기 오류는 로그에 남기고 진단 기록만 중단한다.
 *       PCM은 OS가 MIC 경로로 제공한 신호이며 무가공을 보장하지 않는다.
 */
class NoiseDiagnostics private constructor(private val directory: File) {
    private val audio = BufferedOutputStream(File(directory, "audio.pcm").outputStream())
    private val calculations = File(directory, "calculations.csv").bufferedWriter()
    private val sensors = File(directory, "sensor_noise.csv").bufferedWriter()
    private var audioFailed = false
    private var sensorFailed = false
    private val timestamp = AudioTimestamp()

    init {
        calculations.write("frame_end,read_count,read_ns,calculated_ns,write_ns,dbfs,value,hardware_frame,hardware_ns\n")
        sensors.write("sensor_ns,saved_ns,calculated_ns,frame_end,value\n")
    }

    /**
     * 함수: pcm
     * 목적: 실제 읽은 표본만 signed int16 little-endian으로 저장한다.
     */
    fun pcm(buffer: ShortArray, count: Int) {
        if (audioFailed) return
        try {
            for (i in 0 until count) {
                audio.write(buffer[i].toInt() and 255)
                audio.write((buffer[i].toInt() shr 8) and 255)
            }
        } catch (e: Exception) {
            audioFailed = true
            Log.e("NoiseDiagnostics", "PCM write failed: $directory", e)
        }
    }

    /**
     * 함수: calculation
     * 목적: 표본 위치와 읽기·계산·버퍼 기록 시각을 저장한다.
     *       지원 시 BOOTTIME 하드웨어 앵커도 남긴다. 미지원은 빈 칸이다.
     */
    fun calculation(record: AudioRecord, frames: Long, count: Int, readNs: Long,
                    dbfs: Double?, sample: NoiseSnapshot?) {
        if (audioFailed) return
        try {
            val hasTimestamp = Build.VERSION.SDK_INT >= 24 &&
                record.getTimestamp(timestamp, AudioTimestamp.TIMEBASE_BOOTTIME) == AudioRecord.SUCCESS
            val hardware = if (hasTimestamp) "${timestamp.framePosition},${timestamp.nanoTime}" else ","
            calculations.write("$frames,$count,$readNs,${sample?.calculatedNs ?: ""}," +
                "${SystemClock.elapsedRealtimeNanos()},${dbfs ?: ""},${sample?.value ?: ""},$hardware\n")
        } catch (e: Exception) {
            audioFailed = true
            Log.e("NoiseDiagnostics", "Calculation write failed: $directory", e)
        }
    }

    /**
     * 함수: sensor
     * 목적: 센서 이벤트에 실제 붙인 소음 스냅샷과 버퍼 기록 시각을 저장한다.
     */
    @Synchronized
    fun sensor(sensorNs: Long, sample: NoiseSnapshot) {
        if (sensorFailed) return
        try {
            sensors.write("$sensorNs,${SystemClock.elapsedRealtimeNanos()}," +
                "${sample.calculatedNs},${sample.frameEnd},${sample.value}\n")
        } catch (e: Exception) {
            sensorFailed = true
            Log.e("NoiseDiagnostics", "Sensor write failed: $directory", e)
        }
    }

    /**
     * 함수: closeAudio
     * 목적: 녹음 스레드 종료 후 PCM과 계산 기록을 닫는다.
     */
    fun closeAudio() {
        closeResource(audio)
        closeResource(calculations)
    }

    /**
     * 함수: close
     * 목적: 센서 기록을 닫는다. 진단 폴더는 분석을 위해 남긴다.
     */
    @Synchronized
    fun close() {
        sensorFailed = true
        closeResource(sensors)
    }

    /**
     * 함수: closeResource
     * 목적: 닫기 실패를 로그로 남긴다.
     */
    private fun closeResource(resource: java.io.Closeable) {
        try { resource.close() } catch (e: Exception) {
            Log.e("NoiseDiagnostics", "Close failed: $directory", e)
        }
    }

    /**
     * 클래스: Companion
     * 목적: 진단 폴더와 재계산 메타데이터를 만든다.
     */
    companion object {
        /**
         * 함수: open
         * 목적: 측정별 폴더를 생성하며 실패 시 진단만 비활성화한다.
         */
        fun open(context: Context, rate: Int, window: Int, hop: Int, offset: Double): NoiseDiagnostics? {
            try {
                val parent = File(context.getExternalFilesDir(null) ?: context.filesDir, "noise_diagnostics")
                val dir = File(parent, "${System.currentTimeMillis()}_${SystemClock.elapsedRealtimeNanos()}")
                check(dir.mkdirs()) { "Cannot create $dir" }
                File(dir, "metadata.json").writeText(
                    """{"sample_rate":$rate,"window_samples":$window,"hop_samples":$hop,"offset":$offset,"source":"MIC","format":"s16le","channels":1,"clock":"elapsedRealtimeNanos/BOOTTIME","started_ns":${SystemClock.elapsedRealtimeNanos()}}"""
                )
                Log.i("NoiseDiagnostics", "Saved diagnostic directory: $dir")
                return NoiseDiagnostics(dir)
            } catch (e: Exception) {
                Log.e("NoiseDiagnostics", "Cannot open diagnostics", e)
                return null
            }
        }
    }
}
