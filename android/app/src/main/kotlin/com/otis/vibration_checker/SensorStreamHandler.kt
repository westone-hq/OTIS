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
 *
 * 안드로이드 센서 검출 방식
 * - 센서는 하드웨어에 고정된 주기로 값을 만든다. 앱이 이 주기를 올릴 수 없다.
 *   registerListener 의 요청 주기는 상한이 아니라 희망값이며, 시스템은
 *   하드웨어 주기의 정수배로만 내려준다. 하드웨어보다 빠르게 달라는 요청은
 *   무시되고 하드웨어 주기가 그대로 온다.
 * - 콜백은 등록할 때 넘긴 Handler 의 스레드에서 실행된다. 넘기지 않으면
 *   메인 스레드에서 실행되며, 2종 센서 합쳐 초당 수백 회 호출이 화면 갱신을
 *   막는다. 그래서 전용 HandlerThread 를 만들어 넘긴다.
 * - 하드웨어 주기는 기기마다 다르다. 특정 값을 전제한 처리를 하지 않는다.
 *   실측: 검증 기기 2374.785us(421.2Hz), 대상 기기 2124.5us(470.7Hz).
 *
 * 중력 채널(TYPE_GRAVITY) 의 성질
 * - 물리 센서가 아니다. 센서 허브가 가속도와 회전 정보를 합쳐 계산해 내보내는
 *   가상 센서다. 산출식은 공개되어 있지 않다.
 * - 실측 성질: 벡터 크기가 정확히 1000mg 로 고정된다(변동 2.8e-4 mg).
 *   즉 크기 정보가 없는 정규화된 방향 벡터이며, 어느 쪽이 아래인지만 알려준다.
 *   근거: 측정 — 20260809-170017_raw.txt
 * - 방향이 변하는 속도는 5ms 당 평균 0.063도(초당 12.7도) 수준으로 1Hz 미만의
 *   저역이다. 그래서 격자 간격(3.906ms)보다 느린 주기로 받아도 두 실측 사이를
 *   선형 보간해 쓸 수 있다 (RD-35).
 * - 가속도 채널과의 주기 비율은 기기마다 다르다. 검증 기기는 가속도의 정확히
 *   절반이었으나 대상 기기는 2.35 배로 무관하다. 비율을 가정하지 않는다.
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

        /**
         * Dart 격자 목표 256Hz에 대응하는 주기(µs).
         * registerListener 요청값은 FASTEST이지만, 단말 최소주기가 이보다 크면
         * 256Hz 격자를 하드웨어만으로 채우기 어렵다.
         */
        private const val TARGET_GRID_PERIOD_US = 3906
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
        printSensorInformation()
        Log.i(TAG, "started: SENSOR_DELAY_FASTEST, dedicated handler thread")
    }

    /**
     * 이 단말에 적용된 가속도·중력 센서 사양을 로그로 출력하고,
     * 메일/파일 첨부용 텍스트도 같은 내용으로 돌려준다.
     */
    fun buildSensorInformationText(): String {
        val manager = sensorManager
            ?: (context.getSystemService(Context.SENSOR_SERVICE) as SensorManager?).also {
                sensorManager = it
            }
        val accel = accelSensor ?: manager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER).also {
            accelSensor = it
        }
        val gravity = gravitySensor ?: manager?.getDefaultSensor(Sensor.TYPE_GRAVITY).also {
            gravitySensor = it
        }

        val buf = StringBuilder()
        buf.appendLine("# OTIS sensor_info.txt · 단말 적용 센서 사양")
        buf.appendLine("# request: SENSOR_DELAY_FASTEST")
        buf.appendLine("# targetGrid: 256Hz (${TARGET_GRID_PERIOD_US}us)")
        buf.appendLine()
        buf.append(formatSensorBlock("ACCELEROMETER", accel))
        buf.appendLine()
        buf.append(formatSensorBlock("GRAVITY", gravity))
        return buf.toString()
    }

    private fun printSensorInformation() {
        val text = buildSensorInformationText()
        for (line in text.lineSequence()) {
            if (line.isNotBlank()) Log.i(TAG, line)
        }
    }

    private fun formatSensorBlock(label: String, sensor: Sensor?): String {
        if (sensor == null) {
            return "[$label]\n센서 없음\n"
        }
        val minDelayUs = sensor.minDelay
        val maximumSensorHz =
            if (minDelayUs > 0) 1_000_000.0 / minDelayUs else 0.0
        val buf = StringBuilder()
        buf.appendLine("[$label]")
        buf.appendLine("센서 이름: ${sensor.name}")
        buf.appendLine("제조사: ${sensor.vendor}")
        buf.appendLine("센서 최소주기: $minDelayUs μs")
        buf.appendLine("이론상 최대속도: $maximumSensorHz Hz")
        buf.appendLine("최대 측정범위: ${sensor.maximumRange} m/s²")
        buf.appendLine("측정 해상도: ${sensor.resolution} m/s²")
        if (minDelayUs > TARGET_GRID_PERIOD_US) {
            buf.appendLine("경고: 이 센서는 요청한 256Hz를 지원하지 않을 가능성이 높다.")
        }
        return buf.toString()
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
