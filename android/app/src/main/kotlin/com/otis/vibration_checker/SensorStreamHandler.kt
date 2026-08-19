/*
 * 작성: 2026-08-19 10:35:00
 * 작성자: 박희정
 * 수정: 2026-08-19 13:25:00
 * 수정자: 박희정
 */
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
 * 폰의 흔들림·중력 센서 값을 받아 처리하는 담당입니다.
 *
 * 값이 오면 그대로 파일에 적고,
 * 조금씩 모아서 화면(Flutter)으로도 보냅니다.
 * 값을 예쁘게 고치거나 사이를 메우지는 않습니다.
 *
 * 중력 값은 따로 달린 부품이 아니라,
 * 폰이 계산해서 알려 주는 “아래 방향”에 가깝습니다.
 */
class SensorStreamHandler(
    private val context: Context,
    private val noiseCaptureHandler: NoiseCaptureHandler
) : EventChannel.StreamHandler, SensorEventListener {

    companion object {
        /**
         * 기록장에서 이 담당 메시지를 찾을 때 쓰는 이름입니다.
         */
        private const val TAG = "SensorStreamHandler"

        /**
         * 폰이 주는 단위(m/s²)를 우리가 쓰는 단위(mg)로 바꿀 때 곱하는 수입니다.
         */
        private const val MPS2_TO_MG = 101.97162129779283

        /**
         * 화면에 한 번에 보낼 샘플 개수입니다.
         * 하나하나 보내면 너무 바쁘니까 32개씩 묶습니다.
         */
        private const val BATCH_SIZE = 32

        /**
         * 흔들림(가속도) 값을 적을 때 쓰는 이름입니다.
         */
        private const val TYPE_ACCEL = "accel"

        /**
         * 중력 값을 적을 때 쓰는 이름입니다.
         */
        private const val TYPE_GRAVITY = "gravity"
    }

    /**
     * 센서를 켜고 끄는 관리자입니다.
     * 시작 전에는 비어 있습니다.
     */
    private var sensorManager: SensorManager? = null

    /**
     * 흔들림 센서입니다. 없으면 비어 있습니다.
     */
    private var accelSensor: Sensor? = null

    /**
     * 중력 센서입니다. 없으면 비어 있습니다.
     */
    private var gravitySensor: Sensor? = null

    /**
     * 화면으로 값을 밀어 넣는 출구입니다.
     * 화면이 “듣기 시작”했을 때만 채워집니다.
     */
    private var eventSink: EventChannel.EventSink? = null

    /**
     * 화면 쪽 일꾼에게 일을 맡길 때 씁니다.
     * 값을 화면으로 보낼 때 여기를 거칩니다.
     */
    private val mainHandler = Handler(Looper.getMainLooper())

    /**
     * 센서 값을 받을 전용 배경 작업입니다.
     * 멈추면 비웁니다.
     */
    private var sensorThread: HandlerThread? = null

    /**
     * 위 배경 작업에 일을 넣는 도구입니다.
     * 센서 등록할 때 넘깁니다.
     */
    private var sensorHandler: Handler? = null

    /**
     * 직전에 받은 흔들림 값의 시각입니다.
     * 간격(얼마나 떨어졌는지)을 계산할 때 씁니다.
     */
    private var lastAccelTsNs: Long = 0L

    /**
     * 직전에 받은 중력 값의 시각입니다.
     */
    private var lastGravityTsNs: Long = 0L

    /**
     * 화면으로 보내기 전에 샘플을 모아 두는 바구니입니다.
     * 한 칸에는 type, 시각, x/y/z 같은 정보가 들어갑니다.
     */
    private val batchBuffer = ArrayList<Map<String, Any>>(BATCH_SIZE)

    /**
     * 지금 열고 있는 원본 기록 파일입니다.
     * 안 열었거나 닫으면 비어 있습니다.
     */
    private var recordFile: File? = null

    /**
     * 위 파일에 글을 쓰는 펜입니다.
     */
    private var recordWriter: BufferedWriter? = null

    /**
     * 직전에 닫은 파일의 위치(경로)입니다.
     * 정지를 두 번 불러도 위치를 다시 알려 줄 수 있게 보관합니다.
     */
    private var lastClosedRecordPath: String? = null

    /**
     * 센서 수집을 시작합니다.
     *
     * 파일을 열고, 흔들림·중력 센서를 “가장 빠르게” 받도록 등록합니다.
     * 실제 속도는 폰이 정합니다.
     */
    fun start() {
        // 센서 관리자를 가져옵니다
        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager?
        // 흔들림 센서를 찾습니다
        accelSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        // 중력 센서를 찾습니다
        gravitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)

        // 둘 중 하나라도 없으면
        if (accelSensor == null || gravitySensor == null) {
            // 오류를 기록하고 시작하지 않습니다
            Log.e(
                TAG,
                "Required sensors missing. accel=${accelSensor != null}, " +
                    "gravity=${gravitySensor != null}"
            )
            return
        }

        // 직전 시각을 초기화합니다
        lastAccelTsNs = 0L
        lastGravityTsNs = 0L
        // 이전 측정 경로 기억을 지웁니다
        lastClosedRecordPath = null
        // 바구니 비웁니다 (다른 작업과 겹치지 않게 잠깐 잠급니다)
        synchronized(batchBuffer) { batchBuffer.clear() }
        // 새 기록 파일을 엽니다
        openRecordFile()

        // 센서 전용 배경 작업을 만들고 시작합니다
        val thread = HandlerThread("otis-sensor").also { it.start() }
        // 그 작업에 일을 넣을 도구를 만듭니다
        val handler = Handler(thread.looper)
        // 나중에 끌 수 있게 보관합니다
        sensorThread = thread
        sensorHandler = handler

        // 흔들림 센서를 등록합니다 (가장 빠른 주기, 배경 작업에서 받음)
        sensorManager?.registerListener(
            this, accelSensor, SensorManager.SENSOR_DELAY_FASTEST, 0, handler,
        )
        // 중력 센서도 같은 방식으로 등록합니다
        sensorManager?.registerListener(
            this, gravitySensor, SensorManager.SENSOR_DELAY_FASTEST, 0, handler,
        )
        // 시작했다고 기록합니다
        Log.i(TAG, "started: SENSOR_DELAY_FASTEST, dedicated handler thread")
    }

    /**
     * 센서 수집을 멈춥니다.
     *
     * 남은 샘플을 화면에 보내고, 파일을 닫은 뒤
     * 파일 위치를 돌려줍니다. 없으면 비어 있는 값을 줍니다.
     */
    fun stop(): String? {
        // 이미 닫혀 있고 예전 위치만 있으면 그 위치를 다시 줍니다
        if (recordWriter == null && lastClosedRecordPath != null) {
            return lastClosedRecordPath
        }

        // 센서 알림을 끊습니다
        sensorManager?.unregisterListener(this)
        // 배경 작업에 종료를 요청합니다
        sensorThread?.quitSafely()
        // 최대 0.5초까지 기다리니다
        sensorThread?.join(500)
        // 자리를 비웁니다
        sensorThread = null
        sensorHandler = null

        // 바구니에 32개보다 적게 남은 것도 화면에 보냅니다
        // remainder: 남은 샘플 목록 (없으면 비어 있음)
        var remainder: List<Map<String, Any>>? = null
        // 바구니 잠깐 잠급니다
        synchronized(batchBuffer) {
            // 남은 게 있으면
            if (batchBuffer.isNotEmpty()) {
                // 복사본을 만들고
                remainder = ArrayList(batchBuffer)
                // 원본 바구니는 비웁니다
                batchBuffer.clear()
            }
        }
        // 남은 게 있으면 화면 쪽으로 보냅니다
        remainder?.let { batch ->
            mainHandler.post { eventSink?.success(batch) }
        }

        // 파일을 닫고 위치를 받습니다
        val path = closeRecordFile()
        // 다음에 쓸 수 있게 위치를 기억합니다
        lastClosedRecordPath = path
        // 정지했다고 기록합니다
        Log.i(TAG, "stopped. record=$path")
        // 위치를 돌려줍니다
        return path
    }

    /**
     * 화면이 “센서 값 듣기 시작”할 때 불립니다.
     *
     * 출구를 저장하고, 듣기 전에 바구니 쌓인 값이 있으면 바로 보냅니다.
     */
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        // 앞으로 값을 넣을 출구를 보관합니다
        this.eventSink = events
        // pending: 듣기 전에 쌓여 있던 샘플 (없으면 비어 있음)
        var pending: List<Map<String, Any>>? = null
        // 바구니 잠깐 잠급니다
        synchronized(batchBuffer) {
            // 쌓인 게 있으면
            if (batchBuffer.isNotEmpty()) {
                // 복사본을 만들고
                pending = ArrayList(batchBuffer)
                // 원본은 비웁니다
                batchBuffer.clear()
            }
        }
        // 쌓여 있던 게 있으면 바로 보냅니다
        pending?.let { batch ->
            mainHandler.post { events?.success(batch) }
        }
    }

    /**
     * 화면이 “듣기 그만”할 때 불립니다.
     *
     * 출구만 끊습니다. 여기서 측정까지 멈추지 않습니다.
     * (화면이 따로 “멈춰”를 부를 때 파일 위치를 받아야 해서입니다.)
     */
    override fun onCancel(arguments: Any?) {
        // 출구를 비웁니다
        this.eventSink = null
    }

    /**
     * 센서에서 새 값이 올 때마다 불립니다.
     *
     * 파일에 한 줄 적고, 바구니에 넣은 뒤
     * 32개가 차면 화면으로 보냅니다.
     */
    override fun onSensorChanged(event: SensorEvent?) {
        // 값이 비어 있으면 끝냅니다
        if (event == null) return

        // 흔들림인지 중력인지 이름으로 바꿉니다
        val type = when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> TYPE_ACCEL
            Sensor.TYPE_GRAVITY -> TYPE_GRAVITY
            // 둘 다 아니면 무시합니다
            else -> return
        }

        // 이번 값의 시각입니다
        val tsNs = event.timestamp
        // 같은 종류의 직전 시각입니다
        val prevNs = if (type == TYPE_ACCEL) lastAccelTsNs else lastGravityTsNs
        // 직전과 이번 사이 간격입니다 (첫 값이면 0)
        val dtUs = if (prevNs > 0L && tsNs > prevNs) (tsNs - prevNs) / 1000L else 0L
        // 이번 시각을 직전으로 기억합니다
        if (type == TYPE_ACCEL) lastAccelTsNs = tsNs else lastGravityTsNs = tsNs

        // x/y/z를 우리가 쓰는 단위로 바꿉니다
        val xMg = event.values[0] * MPS2_TO_MG
        val yMg = event.values[1] * MPS2_TO_MG
        val zMg = event.values[2] * MPS2_TO_MG
        // 시각도 더 큰 단위로 바꿉니다
        val tsUs = tsNs / 1000L

        // 원본 파일에 한 줄을 적습니다
        appendRecordLine(type, tsUs, xMg, yMg, zMg, dtUs)

        // 화면으로 보낼 한 점의 정보 묶음입니다
        val sampleMap = mapOf<String, Any>(
            "type" to type,
            "tsUs" to tsUs,
            "xMg" to xMg,
            "yMg" to yMg,
            "zMg" to zMg,
            "dtUs" to dtUs,
            "noiseDba" to noiseCaptureHandler.latestDba
        )

        // 지금 화면에 보낼 묶음 (없으면 비어 있음)
        var readyBatch: List<Map<String, Any>>? = null
        // 바구니 잠깐 잠급니다
        synchronized(batchBuffer) {
            // 이번 샘플을 바구니에 넣습니다
            batchBuffer.add(sampleMap)
            // 화면이 안 듣는데 너무 많이 쌓이면 오래된 것부터 일부 버립니다
            if (eventSink == null && batchBuffer.size > BATCH_SIZE * 8) {
                batchBuffer.subList(0, BATCH_SIZE).clear()
            }
            // 화면이 듣고 있고 32개가 찼으면 보낼 묶음을 만듭니다
            if (eventSink != null && batchBuffer.size >= BATCH_SIZE) {
                readyBatch = ArrayList(batchBuffer)
                batchBuffer.clear()
            }
        }
        // 보낼 묶음이 있으면 화면으로 보냅니다
        readyBatch?.let { batch ->
            mainHandler.post { eventSink?.success(batch) }
        }
    }

    /**
     * 센서 정확도가 바뀌었을 때 불립니다.
     * 이 앱에서는 쓰지 않습니다.
     */
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 사용하지 않습니다
    }

    /**
     * 원본 기록 파일을 새로 엽니다.
     * 오래 남는 앱 폴더에 저장합니다.
     */
    private fun openRecordFile() {
        // 예전 파일이 열려 있으면 먼저 닫습니다
        closeRecordFile()
        try {
            // 저장할 폴더를 정합니다 (밖 폴더, 없으면 안쪽 폴더)
            val dir = context.getExternalFilesDir(null) ?: context.filesDir
            // 파일 이름에 시각을 넣어 겹치지 않게 합니다
            val file = File(dir, "raw_native_${System.currentTimeMillis()}.txt")
            // 파일에 쓸 펜을 만듭니다
            val writer = BufferedWriter(FileWriter(file))
            // 맨 위에 설명 줄을 적습니다
            writer.write("# OTIS raw_native.txt · 보간 전 센서 이벤트\n")
            writer.write("# columns: type tsUs x_mg y_mg z_mg dtUs\n")
            writer.write("# type: accel | gravity\n")
            writer.write("# request: SENSOR_DELAY_FASTEST (목표 주기는 Dart 격자에서 결정)\n")
            // 당장 파일에 반영합니다
            writer.flush()
            // 파일과 펜을 보관합니다
            recordFile = file
            recordWriter = writer
        } catch (e: Exception) {
            // 실패하면 기록하고 비웁니다
            Log.e(TAG, "Failed to open record file", e)
            recordFile = null
            recordWriter = null
        }
    }

    /**
     * 원본 파일에 한 줄을 추가합니다.
     */
    private fun appendRecordLine(
        type: String,
        tsUs: Long,
        xMg: Double,
        yMg: Double,
        zMg: Double,
        dtUs: Long
    ) {
        // 펜이 없으면 그냥 끝냅니다
        val writer = recordWriter ?: return
        try {
            // 타입 시각 x y z 간격 한 줄을 적습니다
            writer.write("$type $tsUs $xMg $yMg $zMg $dtUs\n")
        } catch (e: Exception) {
            // 쓰기 실패면 기록합니다
            Log.e(TAG, "Failed to append record line", e)
        }
    }

    /**
     * 파일을 닫고 전체 위치(경로)를 돌려줍니다.
     */
    private fun closeRecordFile(): String? {
        try {
            // 남은 글을 밀어 넣고
            recordWriter?.flush()
            // 펜을 닫습니다
            recordWriter?.close()
        } catch (_: Exception) {
            // 닫다 실패해도 아래 정리는 계속합니다
        }
        // 펜을 비웁니다
        recordWriter = null
        // 파일 위치를 받습니다
        val path = recordFile?.absolutePath
        // 파일을 비웁니다
        recordFile = null
        // 위치를 돌려줍니다
        return path
    }
}
