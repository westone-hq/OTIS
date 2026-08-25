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
 * 작성: 2026-08-19 08:32:13 · 박건준
 * 클래스: SensorStreamHandler
 * 목적: 안드로이드 가속도·중력 센서 원본 이벤트 수집기.
 *
 *       - TYPE_ACCELEROMETER(raw)와 TYPE_GRAVITY 두 종류만 구독한다.
 *         TYPE_LINEAR_ACCELERATION(안드로이드가 raw에서 자체 계산한 중력값을
 *         이미 빼서 내보내는 합성 센서)은 쓰지 않는다. 아래 중력 채널
 *         설명처럼 안드로이드의 합성 계산식은 공개되어 있지 않다. 그래서 이
 *         프로젝트는 그 합성값을 그대로 믿는 대신, raw와 gravity를 각각
 *         따로 받아 직접 뺀 값을 진동으로 쓴다.
 *       - 요청 주기는 SENSOR_DELAY_FASTEST 로 고정한다. 목표 주기(256Hz)는
 *         Dart 쪽 격자(일정한 시간 간격으로 줄 세운 표의 각 행)에서 정하며,
 *         여기서 특정 Hz 를 요청하면 시스템이 하드웨어 주기의 정수배로 솎아
 *         내려보내 최대 속도를 잃는다.
 *       - 이 클래스는 보간(양옆 실측값 사이를 비례로 채워 넣는 계산) · 리샘플을
 *         하지 않는다. 콜백(값이 준비되면 시스템이 대신 불러주는 함수)으로
 *         도착한 값을 그대로 파일에 기록하고 채널로 보낸다. 등간격으로 맞추는
 *         계산은 Dart 쪽 `GridResampler`가 측정이 끝난 뒤 한다.
 *
 *       안드로이드 센서 검출 방식
 *         - 센서는 하드웨어에 고정된 주기로 값을 만든다. 앱이 이 주기를 올릴 수 없다.
 *           registerListener 의 요청 주기는 상한이 아니라 희망값이며, 시스템은
 *           하드웨어 주기의 정수배로만 내려준다. 하드웨어보다 빠르게 달라는 요청은
 *           무시되고 하드웨어 주기가 그대로 온다.
 *         - 콜백은 등록할 때 넘긴 Handler(어느 스레드(thread, 동시에 실행되는
 *           작업의 흐름 하나)에서 실행할지 지정하는 안드로이드 객체)의
 *           스레드에서 실행된다. 넘기지 않으면 메인 스레드에서 실행되며, 2종
 *           센서 합쳐 초당 수백 회 호출이 화면 갱신을 막는다. 그래서 전용
 *           HandlerThread 를 만들어 넘긴다.
 *         - 하드웨어 주기는 기기마다 다르다. 특정 값을 전제한 처리를 하지 않는다.
 *           실측: 검증 기기 2374.785us(421.2Hz), 대상 기기 2124.5us(470.7Hz).
 *
 *       중력 채널(TYPE_GRAVITY) 의 성질
 *         - 물리 센서가 아니다. 센서 허브가 가속도와 회전 정보를 합쳐 계산해 내보내는
 *           가상 센서다. 산출식은 공개되어 있지 않다.
 *         - 실측 성질: 벡터 크기가 정확히 1000mg 로 고정된다(변동 2.8e-4 mg).
 *           즉 크기 정보가 없는 정규화된 방향 벡터이며, 어느 쪽이 아래인지만 알려준다.
 *         - 방향이 변하는 속도는 5ms 당 평균 0.063도(초당 12.7도) 수준으로 1Hz 미만의
 *           저역이다. 그래서 격자 간격(3.906ms)보다 느린 주기로 받아도 두 실측 사이를
 *           선형 보간해 쓸 수 있다.
 *         - 가속도 채널과의 주기 비율은 기기마다 다르다. 검증 기기는 가속도의 정확히
 *           절반이었으나 대상 기기는 2.35 배로 무관하다. 비율을 가정하지 않는다.
 * 근거: 측정 — 20260809-170017_raw.txt
 */
class SensorStreamHandler(
    private val context: Context // 센서 서비스에 접근할 때 쓰는 안드로이드 컨텍스트
) : EventChannel.StreamHandler, SensorEventListener {

    companion object {
        /** 로그 태그 (Log.e/Log.i 호출 시 출처를 이 이름으로 남긴다) */
        private const val TAG = "SensorStreamHandler"

        /**
         * 변수: MPS2_TO_MG
         * 목적: m/s² → mg 환산 계수
         * 근거: 표준 — 표준 중력 9.80665, 1000 / 9.80665
         */
        private const val MPS2_TO_MG = 101.97162129779283

        /**
         * 변수: BATCH_SIZE
         * 목적: 채널 전송 배치 크기
         * 근거: 측정 — 기존 구현에서 채널 오버헤드
         *       (한 번 보낼 때마다 추가로 드는 처리 부담) 대책으로 검증됨
         */
        private const val BATCH_SIZE = 32

        /** Flutter로 보낼 때 가속도 이벤트를 나타내는 문자열 값 */
        private const val TYPE_ACCEL = "accel"

        /** Flutter로 보낼 때 중력 이벤트를 나타내는 문자열 값 */
        private const val TYPE_GRAVITY = "gravity"
    }

    /** 센서 목록 조회·구독을 담당하는 시스템 서비스. `start()`가 채우고 `stop()`이 등록을 해제한다 */
    private var sensorManager: SensorManager? = null
    /** 가속도 센서. `start()`가 채운다. 이 기기에 없으면 null */
    private var accelSensor: Sensor? = null
    /** 중력 센서. `start()`가 채운다. 이 기기에 없으면 null */
    private var gravitySensor: Sensor? = null
    /** Flutter로 데이터를 흘려보낼 통로. `onListen()`이 연결하고 `onCancel()`이 끊는다 */
    private var eventSink: EventChannel.EventSink? = null
    /** 메인(UI) 스레드에서 실행할 작업을 예약하는 핸들러. 센서 콜백은
     *  별도 스레드에서 오므로, Flutter로 값을 보낼 때는 이걸 거쳐 메인
     *  스레드로 옮긴다 */
    private val mainHandler = Handler(Looper.getMainLooper())
    /** 센서 콜백을 처리하는 전용 스레드. `start()`가 만들고 `stop()`이 정리한다 */
    private var sensorThread: HandlerThread? = null
    /** `sensorThread`에서 실행되는 핸들러. 센서 등록·해제에 쓴다 */
    private var sensorHandler: Handler? = null

    /** 가속도 채널에서 직전에 받은 값의 시각(나노초). 간격(dtUs) 계산에 쓴다 */
    private var lastAccelTsNs: Long = 0L
    /** 중력 채널에서 직전에 받은 값의 시각(나노초) */
    private var lastGravityTsNs: Long = 0L

    /** Flutter로 아직 못 보낸 이벤트를 모아두는 버퍼. `BATCH_SIZE`만큼 차면 한 번에 내보낸다 */
    private val batchBuffer = ArrayList<Map<String, Any>>(BATCH_SIZE)

    /** 지금 기록 중인 원본 파일. 열려 있지 않으면 null */
    private var recordFile: File? = null
    /** `recordFile`에 쓰는 버퍼링된 writer. 열려 있지 않으면 null */
    private var recordWriter: BufferedWriter? = null
    /** 가장 최근에 닫은 기록 파일의 경로. `stop()`이 중복 호출됐을 때
     *  다시 정지시키지 않고 이 값을 그대로 돌려준다 */
    private var lastClosedRecordPath: String? = null

    /**
     * 작성: 2026-08-19 08:32:13 · 박건준
     * 함수: start
     * 목적: 센서 수집을 시작한다. 요청 주기는 단말이 줄 수 있는 최대
     *       속도로 고정한다. 목표 주기(256Hz)는 Dart 격자에서 정하며,
     *       여기서 특정 Hz 를 요청하면 시스템이 하드웨어 주기의
     *       정수배로 솎아 내려보내 최대 속도를 잃는다.
     * 근거: 측정 — 동일 단말 요청 주기별 검증에서 128Hz 요청 시 210Hz,
     *       64Hz 요청 시 70Hz 로 수신됨 확인 (하드웨어 주기 2374.785us 의 정수배)
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
        // → 로직 이동: openRecordFile()
        openRecordFile()

        val thread = HandlerThread("otis-sensor").also { it.start() } // 센서 콜백 전용 스레드
        val handler = Handler(thread.looper) // 그 스레드에 일을 넣는 핸들러
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
     * 작성: 2026-08-19 08:32:13 · 박건준
     * 함수: stop
     * 목적: 센서 수집을 멈추고 지금까지 쌓인 값을 마무리해 파일로
     *       확정한다. Flutter의 stopCapture 요청과, 화면이 완전히
     *       종료될 때 안전망으로 도는 MainActivity.onDestroy() 양쪽에서
     *       부를 수 있다. 이미 한 번 정지 처리를 마친 뒤 다시
     *       불리면(안전망이 뒤늦게 도는 경우) 센서를 다시 건드리지
     *       않고 저장해 둔 경로를 그대로 돌려준다.
     * 반환: 이번 측정의 원본 기록 파일 절대 경로. 기록에 실패했으면 null
     */
    fun stop(): String? {
        // 이미 정지 처리를 마쳤다면(recordWriter가 비어 있고 경로를
        // 저장해 뒀다면) 다시 정지시키지 않고 그 경로를 그대로 돌려준다
        if (recordWriter == null && lastClosedRecordPath != null) {
            return lastClosedRecordPath
        }

        sensorManager?.unregisterListener(this)
        sensorThread?.quitSafely()
        sensorThread?.join(500)
        sensorThread = null
        sensorHandler = null

        // 채널로 아직 못 보낸 배치 잔여분이 있으면 마저 내보낸다.
        // 그냥 두면 이번 측정의 마지막 값 몇 개가 유실된다
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

        // → 로직 이동: closeRecordFile()
        val path = closeRecordFile() // 기록 파일을 닫고 받은 경로
        lastClosedRecordPath = path
        Log.i(TAG, "stopped. record=$path")
        return path
    }

    /**
     * 작성: 2026-08-19 08:32:13 · 박건준
     * 함수: onListen
     * 목적: Flutter가 `EventChannel`(계속 흘려보내는 통로) 구독을 시작할
     *       때 호출된다. 앞으로 값을 내보낼 출구(`eventSink`)를 저장하고,
     *       구독 전에 미리 쌓여 있던 값이 있으면 즉시 내보낸다 —
     *       그렇지 않으면 구독 전에 온 값이 그대로 유실된다.
     * 인자: arguments — Flutter가 넘긴 부가 인자. 여기서는 쓰지 않는다
     *       events — 값을 내보낼 출구
     */
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
        // 구독 전에 도착해 버퍼에 쌓인 이벤트를 즉시 내보낸다 (유실 방지).
        var pending: List<Map<String, Any>>? = null // 구독 전에 쌓여 있던 값
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

    /**
     * 작성: 2026-08-19 08:32:13 · 박건준
     * 함수: onCancel
     * 목적: `EventChannel` 구독이 끊길 때(Flutter 쪽이 스트림을 그만
     *       듣기로 했을 때) 호출된다. 여기서는 파일을 닫지 않는다 —
     *       Flutter는 구독 해제와 stopCapture 요청을 함께 실행하는데,
     *       여기서 먼저 파일을 닫아버리면 뒤이어 오는 stopCapture
     *       요청이 돌려줄 파일 경로가 이미 비워진 뒤라 null이 된다.
     *       실제 정지·파일 마무리는 `stop()`에서만 한다.
     * 인자: arguments — Flutter가 넘긴 부가 인자. 여기서는 쓰지 않는다
     */
    override fun onCancel(arguments: Any?) {
        this.eventSink = null
    }

    /**
     * 작성: 2026-08-19 08:32:13 · 박건준
     * 함수: onSensorChanged
     * 목적: 가속도 또는 중력 센서에서 새 값이 올 때마다 안드로이드가
     *       부른다. 원본 파일에 한 줄 적고, 배치 버퍼에 담아 뒀다가
     *       `BATCH_SIZE`(32개)만큼 차면 한 번에 Flutter로 내보낸다.
     * 인자: event — 안드로이드가 넘겨주는 센서 원본 이벤트. 가속도 ·
     *       중력 외의 종류거나 비어 있으면 무시한다
     */
    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null) return

        val type = when (event.sensor.type) { // "accel" 또는 "gravity"로 분류
            Sensor.TYPE_ACCELEROMETER -> TYPE_ACCEL
            Sensor.TYPE_GRAVITY -> TYPE_GRAVITY
            else -> return
        }

        val tsNs = event.timestamp // 이번 값의 시각(나노초)
        val prevNs = if (type == TYPE_ACCEL) lastAccelTsNs else lastGravityTsNs // 같은 종류의 직전 값 시각
        val dtUs = if (prevNs > 0L && tsNs > prevNs) (tsNs - prevNs) / 1000L else 0L // 직전 값과의 간격(us). 첫 값이면 0
        if (type == TYPE_ACCEL) lastAccelTsNs = tsNs else lastGravityTsNs = tsNs

        val xMg = event.values[0] * MPS2_TO_MG // X축 값(mg)
        val yMg = event.values[1] * MPS2_TO_MG // Y축 값(mg)
        val zMg = event.values[2] * MPS2_TO_MG // Z축 값(mg)
        val tsUs = tsNs / 1000L // 값의 시각(마이크로초)

        // → 로직 이동: appendRecordLine()
        appendRecordLine(type, tsUs, xMg, yMg, zMg, dtUs)

        val sampleMap = mapOf<String, Any>( // Flutter로 보낼 한 점의 정보
            "type" to type,
            "tsUs" to tsUs,
            "xMg" to xMg,
            "yMg" to yMg,
            "zMg" to zMg,
            "dtUs" to dtUs
        )

        var readyBatch: List<Map<String, Any>>? = null // 이번에 내보낼 배치
        synchronized(batchBuffer) {
            batchBuffer.add(sampleMap)
            // eventSink 미연결 상태에서 버퍼가 무한정 커지지 않도록 상한.
            // 초과 시 가장 오래된 배치 크기만큼 버린다.
            if (eventSink == null && batchBuffer.size > BATCH_SIZE * 8) {
                batchBuffer.subList(0, BATCH_SIZE).clear()
            }
            // eventSink 가 있고 한 배치가 찼으면 내보낼 배치를 뜬다.
            if (eventSink != null && batchBuffer.size >= BATCH_SIZE) {
                readyBatch = ArrayList(batchBuffer)
                batchBuffer.clear()
            }
        }
        readyBatch?.let { batch ->
            mainHandler.post { eventSink?.success(batch) }
        }
    }

    /**
     * 작성: 2026-08-19 08:32:13 · 박건준
     * 함수: onAccuracyChanged
     * 목적: 센서 정확도가 바뀔 때 안드로이드가 부른다. 이 앱에서는 쓰지 않는다.
     * 인자: sensor — 정확도가 바뀐 센서
     *       accuracy — 새로 바뀐 정확도 값
     */
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 사용하지 않음
    }

    /**
     * 작성: 2026-08-19 08:32:13 · 박건준
     * 함수: openRecordFile
     * 목적: 원본 기록 파일을 앱 전용 영속 저장소에 새로 연다. 안드로이드의
     *       캐시 폴더(cacheDir)는 시스템이 저장 공간이 부족하면 사용자
     *       동의 없이 그 안의 파일을 임의로 지울 수 있어, 측정 원본을
     *       거기에 두면 안전하게 보관되지 않는다. 그래서 캐시 폴더 대신
     *       외장 저장소(없으면 앱 전용 내부 저장소)를 쓴다.
     */
    private fun openRecordFile() {
        // 혹시 이전에 열린 채로 남은 파일이 있으면 먼저 정리한다
        // → 로직 이동: closeRecordFile()
        closeRecordFile()
        try {
            val dir = context.getExternalFilesDir(null) ?: context.filesDir // 외장 없으면 앱 전용 내부 저장소
            val file = File(dir, "raw_native_${System.currentTimeMillis()}.txt") // 새로 만들 기록 파일
            val writer = BufferedWriter(FileWriter(file)) // 이 파일에 쓸 writer
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

    /**
     * 작성: 2026-08-19 08:32:13 · 박건준
     * 함수: appendRecordLine
     * 목적: 원본 기록 파일에 값 한 줄을 추가한다. 파일이 열려 있지
     *       않으면(`recordWriter`가 null) 조용히 넘어간다.
     * 인자: type — 센서 종류("accel" 또는 "gravity")
     *       tsUs — 값의 시각(마이크로초)
     *       xMg, yMg, zMg — 값(mg)
     *       dtUs — 같은 종류 직전 값과의 시간 간격(마이크로초)
     */
    private fun appendRecordLine(
        type: String,
        tsUs: Long,
        xMg: Double,
        yMg: Double,
        zMg: Double,
        dtUs: Long
    ) {
        val writer = recordWriter ?: return // 파일이 열려 있지 않으면 조용히 넘어간다
        try {
            writer.write("$type $tsUs $xMg $yMg $zMg $dtUs\n")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to append record line", e)
        }
    }

    /**
     * 작성: 2026-08-19 08:32:13 · 박건준
     * 함수: closeRecordFile
     * 목적: 열려 있는 원본 기록 파일을 마무리한다. 버퍼에 남아 있던
     *       내용을 디스크에 쓰고(flush) 파일을 닫는다. 닫는 도중
     *       예외가 나도 무시하고 계속 진행한다 — 이미 flush 된
     *       내용까지는 파일에 남아 있으므로, 닫기 실패 때문에 측정
     *       전체를 실패로 만들 이유가 없다.
     * 반환: 방금 닫은 파일의 절대 경로. 파일을 연 적이 없으면 null
     */
    private fun closeRecordFile(): String? {
        try {
            recordWriter?.flush()
            recordWriter?.close()
        } catch (_: Exception) {
        }
        recordWriter = null
        val path = recordFile?.absolutePath // 지금 닫은 파일의 경로
        recordFile = null
        return path
    }
}
