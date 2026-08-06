package com.otis.vibration_checker

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel
import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter

/**
 * 안드로이드 가속도·중력 센서 원본 이벤트 수집기.
 *
 * - TYPE_ACCELEROMETER(raw)와 TYPE_GRAVITY 2종만 구독한다.
 *   linear 는 사용하지 않는다 (RD-6).
 * - 요청 주기는 startCapture 의 sampleRate 로부터 도출한다:
 *   samplingPeriodUs = 1,000,000 / sampleRate. 요청은 힌트이며
 *   실제 콜백 간격은 기기·OS가 결정한다.
 * - 보간·리샘플 없음. 콜백 도착 그대로 파일에 기록하고 채널로 보낸다 (RD-1).
 * - 채널 계약: docs/capture_channel_contract.md
 */
class SensorStreamHandler(
    private val context: Context,
    private val noiseCaptureHandler: NoiseCaptureHandler
) : EventChannel.StreamHandler, SensorEventListener {

    companion object {
        private const val TAG = "SensorStreamHandler"

        /** m/s² → mg 환산. 근거: 표준 — 표준 중력 9.80665, 1000 / 9.80665 */
        private const val MPS2_TO_MG = 101.97162129779283

        /** 채널 전송 배치 크기. 근거: 측정 — 기존 구현에서 채널 오버헤드 대책으로 검증됨 */
        private const val BATCH_SIZE = 32

        private const val TYPE_ACCEL = "accel"
        private const val TYPE_GRAVITY = "gravity"
    }

    private var sensorManager: SensorManager? = null
    private var accelSensor: Sensor? = null
    private var gravitySensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var lastAccelTsNs: Long = 0L
    private var lastGravityTsNs: Long = 0L

    private val batchBuffer = ArrayList<Map<String, Any>>(BATCH_SIZE)

    private var recordFile: File? = null
    private var recordWriter: BufferedWriter? = null

    /**
     * 수집을 시작한다. 요청 주기를 sampleRate 로부터 도출하고
     * 원본 기록 파일을 연다.
     */
    fun start(targetSampleRate: Int) {
        val rate = if (targetSampleRate > 0) targetSampleRate else 256
        val samplingPeriodUs = (1_000_000 / rate)

        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager?
        accelSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gravitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)

        if (accelSensor == null || gravitySensor == null) {
            Log.e(TAG, "Required sensors missing. accel=${accelSensor != null}, gravity=${gravitySensor != null}")
            return
        }

        lastAccelTsNs = 0L
        lastGravityTsNs = 0L
        synchronized(batchBuffer) { batchBuffer.clear() }
        openRecordFile(rate, samplingPeriodUs)

        sensorManager?.registerListener(this, accelSensor, samplingPeriodUs)
        sensorManager?.registerListener(this, gravitySensor, samplingPeriodUs)
        Log.i(TAG, "started: samplingPeriodUs=$samplingPeriodUs (rate=$rate Hz)")
    }

    /**
     * 수집을 정지한다. 배치 잔여분을 마저 보내고(flush) 파일을 닫는다.
     * @return 이번 측정의 원본 기록 파일 절대 경로. 기록 실패 시 null
     */
    fun stop(): String? {
        sensorManager?.unregisterListener(this)

        // 배치 잔여분 flush — 잔여 유실 방지 (판독서 C3)
        var remainder: List<Map<String, Any>>? = null
        synchronized(batchBuffer) {
            if (batchBuffer.isNotEmpty()) {
                remainder = ArrayList(batchBuffer)
                batchBuffer.clear()
            }
        }
        remainder?.let { batch ->
            mainHandler.post { eventSink?.success(batch) }
        }

        val path = closeRecordFile()
        Log.i(TAG, "stopped. record=$path")
        return path
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        stop()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return

        val type = when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> TYPE_ACCEL
            Sensor.TYPE_GRAVITY -> TYPE_GRAVITY
            else -> return
        }

        val tsNs = event.timestamp
        val prevNs = if (type == TYPE_ACCEL) lastAccelTsNs else lastGravityTsNs
        val dtUs = if (prevNs > 0L && tsNs > prevNs) (tsNs - prevNs) / 1000L else 0L
        if (type == TYPE_ACCEL) lastAccelTsNs = tsNs else lastGravityTsNs = tsNs

        val xMg = event.values[0] * MPS2_TO_MG
        val yMg = event.values[1] * MPS2_TO_MG
        val zMg = event.values[2] * MPS2_TO_MG
        val tsUs = tsNs / 1000L

        appendRecordLine(type, tsUs, xMg, yMg, zMg, dtUs)

        if (eventSink == null) return
        val sampleMap = mapOf<String, Any>(
            "type" to type,
            "tsUs" to tsUs,
            "xMg" to xMg,
            "yMg" to yMg,
            "zMg" to zMg,
            "dtUs" to dtUs,
            "noiseDba" to noiseCaptureHandler.latestDba
        )

        var readyBatch: List<Map<String, Any>>? = null
        synchronized(batchBuffer) {
            batchBuffer.add(sampleMap)
            if (batchBuffer.size >= BATCH_SIZE) {
                readyBatch = ArrayList(batchBuffer)
                batchBuffer.clear()
            }
        }
        readyBatch?.let { batch ->
            mainHandler.post { eventSink?.success(batch) }
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 사용하지 않음
    }

    /** 원본 기록 파일을 앱 영속 저장소에 연다 (cacheDir 금지 — 판독서 C6). */
    private fun openRecordFile(rate: Int, samplingPeriodUs: Int) {
        closeRecordFile()
        try {
            val dir = context.getExternalFilesDir(null) ?: context.filesDir
            val file = File(dir, "raw_native_${System.currentTimeMillis()}.txt")
            val writer = BufferedWriter(FileWriter(file))
            writer.write("# OTIS raw_native.txt · 보간 전 센서 이벤트\n")
            writer.write("# columns: type tsUs x_mg y_mg z_mg dtUs\n")
            writer.write("# type: accel | gravity\n")
            writer.write("# targetSampleRateHz: $rate (samplingPeriodUs=$samplingPeriodUs)\n")
            writer.flush()
            recordFile = file
            recordWriter = writer
        } catch (e: Exception) {
            Log.e(TAG, "Failed to open record file", e)
            recordFile = null
            recordWriter = null
        }
    }

    private fun appendRecordLine(
        type: String,
        tsUs: Long,
        xMg: Double,
        yMg: Double,
        zMg: Double,
        dtUs: Long
    ) {
        val writer = recordWriter ?: return
        try {
            writer.write("$type $tsUs $xMg $yMg $zMg $dtUs\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to append record line", e)
        }
    }

    private fun closeRecordFile(): String? {
        try {
            recordWriter?.flush()
            recordWriter?.close()
        } catch (_: Exception) {
        }
        recordWriter = null
        val path = recordFile?.absolutePath
        recordFile = null
        return path
    }
}
