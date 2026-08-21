package com.otis.vibration_checker

import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import android.hardware.Sensor
import android.hardware.SensorManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

/**
 * 작성: 2026-08-17 15:43:39 · 박건준
 * 수정: 2026-08-19 13:25:00 · 박희정
 * 클래스: MainActivity
 * 목적: 안드로이드(네이티브, Flutter 쪽에서 부르는 안드로이드 코틀린
 *       코드) 진입점. Flutter와 채널 두 개로 연결된다.
 *       - `MethodChannel`(요청 하나 · 응답 하나짜리 통로)로 센서 확인 ·
 *         측정 시작 · 종료 명령을 받아 처리한다
 *       - `EventChannel`(계속 흘려보내는 통로)은 `SensorStreamHandler`
 *         에게 맡겨 센서 원본 데이터를 Flutter로 흘려보낸다
 */
class MainActivity : FlutterActivity() {
    companion object {
        // Flutter 쪽 lib/adapter/sensor_channel.dart 의 _methodChannel 과
        // 문자열이 반드시 같아야 한다. 컴파일러가 대신 검사해주는 연결이
        // 아니라서, 둘 중 하나만 바뀌면 컴파일은 되지만 요청이 반대편에
        // 닿지 않고 조용히 실패한다
        private const val METHOD_CHANNEL =
            "com.otis.vibration_checker/sensors_method"

        // 위와 같은 이유로 sensor_channel.dart 의 _eventChannel 과 문자열이
        // 반드시 같아야 한다
        private const val STREAM_CHANNEL =
            "com.otis.vibration_checker/sensors_stream"

        // onRequestPermissionsResult 에서 어떤 권한 요청에 대한 응답인지
        // 구분하기 위한 임의의 요청 코드
        private const val REQ_HIGH_RATE_PERMISSION = 1002
    }

    // 가속도 · 중력 센서 원본 캡처 담당. startCapture/stopCapture 요청을
    // 이 핸들러에 그대로 위임한다
    private lateinit var sensorStreamHandler: SensorStreamHandler

    // 고속 샘플링 권한 승인을 기다리는 동안 미뤄둔, 승인 후 이어서 실행할
    // 수집 시작 동작. 권한 요청 중이 아니면 null
    private var pendingStartCapture: (() -> Unit)? = null

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-08-19 13:25:00 · 박희정
     * 함수: configureFlutterEngine
     * 목적: Flutter 엔진이 뜰 때 센서 핸들러를 만들고, 채널 2개
     *       (`METHOD_CHANNEL`, `STREAM_CHANNEL`)를 등록해 Flutter와
     *       안드로이드를 연결한다.
     * 인자: flutterEngine — Flutter 쪽에서 넘겨주는 엔진 인스턴스
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        sensorStreamHandler = SensorStreamHandler(this)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            // → 로직 이동: SensorStreamHandler
            .setStreamHandler(sensorStreamHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    /**
                     * 작성: 2026-08-17 15:43:39 · 박건준
                     * 수정: 2026-08-19 13:25:00 · 박희정
                     * 함수: checkAvailable
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "checkAvailable" 요청에 응답한다. 이 기기에
                     *       가속도 · 중력 센서가 실제로 달려있는지 확인한다.
                     *       - `getSystemService(Context.SENSOR_SERVICE)`로
                     *         `SensorManager`(기기에 달린 센서 목록을
                     *         관리하고 값 구독을 열어주는 안드로이드 시스템
                     *         서비스)를 받아온다
                     *       - `SensorManager.getDefaultSensor(타입)`으로 그
                     *         타입의 센서가 이 기기에 있는지 물어본다. 값을
                     *         읽어보는 게 아니라 존재 여부만 조회하는
                     *         것이라, 있으면 센서 정보 객체를, 하드웨어
                     *         자체가 없으면 null을 곧바로 돌려준다
                     *       - `TYPE_GRAVITY`(중력 센서)는 따로 달린
                     *         부품이 아니라 센서 허브가 가속도 · 자이로
                     *         값을 계산해 합성해 내보내는 값이다. 그래도
                     *         `getDefaultSensor`로 존재 여부는 물어볼 수
                     *         있다
                     *       - 진동값은 가속도 원본에서 중력을 뺀 값
                     *         (raw − gravity)으로만 계산하도록 정해져
                     *         있어서, 둘 중 하나라도 없으면 계산 자체가
                     *         안 된다. 그래서 두 센서가 다 있어야 측정
                     *         가능으로 판단한다
                     * 반환: result.success(Boolean) 으로 응답. 가속도계와
                     *       중력 센서가 둘 다 있으면 true
                     */
                    "checkAvailable" -> {
                        // 센서 목록 조회 · 구독을 담당하는 시스템 서비스.
                        // 이론상 못 가져올 수도 있어 널 허용 타입으로 받는다
                        val sensorManager =
                            getSystemService(Context.SENSOR_SERVICE) as SensorManager?
                        // 가속도 센서. 이 기기에 없으면 null
                        val accel =
                            sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                        // 중력 센서(합성값). 이 기기에 없으면 null
                        val gravity =
                            sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
                        result.success(accel != null && gravity != null)
                    }
                    /**
                     * 작성: 2026-08-17 15:43:39 · 박건준
                     * 수정: 2026-08-19 13:25:00 · 박희정
                     * 함수: startCapture
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "startCapture" 요청에 응답한다. 가속도 · 중력
                     *       센서 캡처를 시작한다.
                     *       - Android 12(S) 이상은 고속 샘플링 권한이
                     *         없으면 먼저 요청하고, 응답이 온 뒤 시작한다
                     *         (`pendingStartCapture`에 맡겨둔다)
                     *       - 이미 권한이 있거나 Android 12 미만이면
                     *         곧바로 시작한다
                     * 반환: result.success(null) 로 즉시 응답한다. 실제로
                     *       캡처가 시작됐는지는 기다리지 않는다
                     * 근거: 측정 — SENSOR_DELAY_FASTEST 로 요청해도 실제
                     *       수신 속도는 단말 하드웨어 주기라 200Hz 를
                     *       넘는다(동일 단말 raw 실측 421Hz). Android 12+
                     *       에서는 고속 샘플링 권한이 없으면 이 속도가
                     *       제한된다
                     */
                    "startCapture" -> {
                        // 고속 샘플링 권한이 확보된 뒤(또는 이미 있어서
                        // 곧바로) 실행할, 실제 수집을 시작하는 동작
                        val begin = {
                            // → 로직 이동: SensorStreamHandler.start()
                            sensorStreamHandler.start()
                        }

                        // Android 12 이상 여부
                        val needsHighRate =
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                        // 고속 샘플링 권한 이름
                        val permName =
                            "android.permission.HIGH_SAMPLING_RATE_SENSORS"
                        if (needsHighRate &&
                            ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                permName
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingStartCapture = begin
                            // → 로직 이동: onRequestPermissionsResult
                            ActivityCompat.requestPermissions(
                                this@MainActivity,
                                arrayOf(permName),
                                REQ_HIGH_RATE_PERMISSION
                            )
                        } else {
                            begin()
                        }
                        result.success(null)
                    }
                    /**
                     * 작성: 2026-08-17 15:43:39 · 박건준
                     * 수정: 2026-08-19 13:25:00 · 박희정
                     * 함수: stopCapture
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "stopCapture" 요청에 응답한다. 캡처를 멈추고
                     *       원본 기록 파일 경로를 돌려준다.
                     * 반환: result.success(String?) 로 응답. 저장된 파일
                     *       경로, 저장하지 못했으면 null
                     */
                    "stopCapture" -> {
                        // → 로직 이동: SensorStreamHandler.stop()
                        // 저장된 원본 파일 경로, 없으면 null
                        val recordPath = sensorStreamHandler.stop()
                        result.success(recordPath)
                    }
                    else -> {
                        // 정의되지 않은 메서드 이름이면 미구현으로 응답한다
                        result.notImplemented()
                    }
                }
            }
    }

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-08-19 13:25:00 · 박희정
     * 함수: onRequestPermissionsResult
     * 목적: 시스템 권한 대화상자에 대한 사용자 응답을 받아, 기다리고
     *       있던 쪽에 결과를 이어준다.
     *       - 고속 샘플링 권한 응답이면, 승인 여부와 무관하게 대기 중이던
     *         `pendingStartCapture`(캡처 시작 동작)를 실행한다. 미승인이면
     *         저속으로라도 캡처는 계속 진행하되 경고를 로그로 남긴다
     * 인자: requestCode — 어떤 권한 요청에 대한 응답인지 구분하는 값
     *       (`REQ_HIGH_RATE_PERMISSION`)
     *       permissions — 요청했던 권한 이름 목록. 여기서는 안 쓴다
     *       grantResults — 각 권한에 대한 승인 결과. 인덱스가
     *       permissions 와 대응한다
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_HIGH_RATE_PERMISSION) {
            // 고속 샘플링 권한 승인 여부
            val granted =
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            if (!granted) {
                android.util.Log.w(
                    "MainActivity",
                    "고속 샘플링 권한 미승인 — 200Hz 초과 콜백이 오지 않을 수 있다"
                )
            }
            // 승인 여부와 무관하게 수집은 시작한다 (미승인 시 저속만 유효)
            pendingStartCapture?.invoke()
            pendingStartCapture = null
        }
    }

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-08-19 13:25:00 · 박희정
     * 함수: onDestroy
     * 목적: 액티비티가 완전히 종료될 때 센서 핸들러를 정리해, 자원을
     *       계속 붙들고 있지 않게 한다.
     */
    override fun onDestroy() {
        super.onDestroy()
        if (::sensorStreamHandler.isInitialized) {
            sensorStreamHandler.stop()
        }
    }
}
