package com.otis.vibration_checker

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.HandlerThread
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
 * - 요청 주기는 SENSOR_DELAY_FASTEST 로 고정한다. 목표 주기(256Hz)는
 *   Dart 격자에서 정하며, 여기서 특정 Hz 를 요청하면 시스템이 하드웨어
 *   주기의 정수배로 솎아 내려보내 최대 속도를 잃는다.
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
    private var sensorThread: HandlerThread? = null
    private var sensorHandler: Handler? = null

    private var lastAccelTsNs: Long = 0L
    private var lastGravityTsNs: Long = 0L

    private val batchBuffer = ArrayList<Map<String, Any>>(BATCH_SIZE)

    private var recordFile: File? = null
    private var recordWriter: BufferedWriter? = null
    private var lastClosedRecordPath: String? = null

    /**
     * 수집을 시작한다. 요청 주기는 단말이 줄 수 있는 최대 속도로 고정한다.
     *
     * 목표 주기(256Hz)는 Dart 격자에서 정한다. 여기서 특정 Hz 를 요청하면
     * 시스템이 하드웨어 주기의 정수배로 솎아 내려보내 최대 속도를 잃는다.
     * 근거: 측정 — 동일 단말 요청 주기별 검증에서 128Hz 요청 시 210Hz,
     * 64Hz 요청 시 70Hz 로 수신됨 확인 (하드웨어 주기 2374.785us 의 정수배)
     */
    fun start() {
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager?
        accelSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gravitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)

        if (accelSensor == null || gravitySensor == null) {
            Log.e(TAG, "Required sensors missing. accel=${accelSensor != null}, gravity=${gravitySensor != null}")
            return
        }

        lastAccelTsNs = 0L
        lastGravityTsNs = 0L
        lastClosedRecordPath = null
        synchronized(batchBuffer) { batchBuffer.clear() }
        openRecordFile()

        val thread = HandlerThread("otis-sensor").also { it.start() }
        val handler = Handler(thread.looper)
        sensorThread = thread
        sensorHandler = handler

        sensorManager?.registerListener(
            this, accelSensor, SensorManager.SENSOR_DELAY_FASTEST, 0, handler,
        )
        sensorManager?.registerListener(
            this, gravitySensor, SensorManager.SENSOR_DELAY_FASTEST, 0, handler,
        )
        Log.i(TAG, "started: SENSOR_DELAY_FASTEST, dedicated handler thread")
    }

    /**
     * 수집을 정지한다. 배치 잔여분을 마저 보내고(flush) 파일을 닫는다.
     * @return 이번 측정의 원본 기록 파일 절대 경로. 기록 실패 시 null
     */
    fun stop(): String? {
        if (recordWriter == null && lastClosedRecordPath != null) {
            return lastClosedRecordPath
        }

        sensorManager?.unregisterListener(this)
        sensorThread?.quitSafely()
        sensorThread?.join(500)
        sensorThread = null
        sensorHandler = null

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
        lastClosedRecordPath = path
        Log.i(TAG, "stopped. record=$path")
        return path
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        // 구독 전에 도착해 버퍼에 쌓인 이벤트를 즉시 내보낸다 (유실 방지).
        var pending: List<Map<String, Any>>? = null
        synchronized(batchBuffer) {
            if (batchBuffer.isNotEmpty()) {
                pending = ArrayList(batchBuffer)
                batchBuffer.clear()
            }
        }
        pending?.let { batch ->
            mainHandler.post { events?.success(batch) }
        }
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        // stop() 을 부르지 않는다. Dart 가 구독 해제와 stopCapture 를 함께 실행하므로
        // 여기서 먼저 파일을 닫으면 stopCapture 가 돌려줄 경로가 null 이 된다.
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
            // sink 미연결 상태에서 버퍼가 무한정 커지지 않도록 상한.
            // 초과 시 가장 오래된 배치 크기만큼 버린다.
            if (eventSink == null && batchBuffer.size > BATCH_SIZE * 8) {
                batchBuffer.subList(0, BATCH_SIZE).clear()
            }
            // sink 가 있고 한 배치가 찼으면 내보낼 배치를 뜬다.
            if (eventSink != null && batchBuffer.size >= BATCH_SIZE) {
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
    private fun openRecordFile() {
        closeRecordFile()
        try {
            val dir = context.getExternalFilesDir(null) ?: context.filesDir
            val file = File(dir, "raw_native_${System.currentTimeMillis()}.txt")
            val writer = BufferedWriter(FileWriter(file))
            writer.write("# OTIS raw_native.txt · 보간 전 센서 이벤트\n")
            writer.write("# columns: type tsUs x_mg y_mg z_mg dtUs\n")
            writer.write("# type: accel | gravity\n")
            writer.write("# request: SENSOR_DELAY_FASTEST (목표 주기는 Dart 격자에서 결정)\n")
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
