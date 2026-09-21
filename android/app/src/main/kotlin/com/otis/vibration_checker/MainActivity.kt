package com.otis.vibration_checker

import android.Manifest
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
 * 수정: 2026-09-21 · 박희정
 * 클래스: MainActivity
 * 목적: 안드로이드(네이티브, Flutter 쪽에서 부르는 안드로이드 코틀린
 *       코드) 진입점. Flutter와 채널로 연결된다.
 *       - `MethodChannel`(요청 하나 · 응답 하나짜리 통로)로 센서 확인 ·
 *         마이크 권한 · 측정 시작 · 종료 · 소음 테스트 명령을 받아 처리한다
 *       - `EventChannel`(계속 흘려보내는 통로)은 `SensorStreamHandler`
 *         에게 맡겨 센서 원본 데이터를 Flutter로 흘려보낸다
 *       - 소음(dB) 전용 테스트는 `NoiseTestCaptureHandler` + 별도
 *         EventChannel로 EVIMP1 진동+소음 측정과 분리한다
 */
class MainActivity : FlutterActivity() {
    /**
     * 클래스: Companion
     * 목적: Flutter와 연결할 채널 이름, 권한 요청 코드 등 MainActivity
     *       전역에서 쓰는 상수를 모아둔다.
     */
    companion object {
        /**
         * Flutter 쪽 lib/adapter/sensor_channel.dart 의 _methodChannel 과
         * 문자열이 반드시 같아야 한다. 컴파일러가 대신 검사해주는 연결이
         * 아니라서, 둘 중 하나만 바뀌면 컴파일은 되지만 요청이 반대편에
         * 닿지 않고 조용히 실패한다
         */
        private const val METHOD_CHANNEL =
            "com.otis.vibration_checker/sensors_method"

        /**
         * 위와 같은 이유로 sensor_channel.dart 의 _eventChannel 과 문자열이
         * 반드시 같아야 한다
         */
        private const val STREAM_CHANNEL =
            "com.otis.vibration_checker/sensors_stream"

        /**
         * 소음(dB) 전용 테스트 라이브 스트림.
         * sensor_channel.dart 의 _noiseTestEventChannel 과 문자열이 같아야 한다
         */
        private const val NOISE_TEST_STREAM_CHANNEL =
            "com.otis.vibration_checker/noise_test_stream"

        /** onRequestPermissionsResult 에서 마이크 권한 응답과 고속 샘플링
         *  권한 응답을 구분하기 위한 임의의 요청 코드 */
        private const val REQ_AUDIO_PERMISSION = 1001
        private const val REQ_HIGH_RATE_PERMISSION = 1002
    }

    /** 소음(마이크) 원본 캡처 담당. startCapture/stopCapture·onDestroy에서 시작·정지한다 */
    private lateinit var noiseCaptureHandler: NoiseCaptureHandler

    /** 소음(dB) 전용 테스트 캡처. EVIMP1 측정과 마이크를 공유하지 않도록 분리한다 */
    private lateinit var noiseTestCaptureHandler: NoiseTestCaptureHandler

    /** 가속도 · 중력 센서 원본 캡처 담당. startCapture/stopCapture 요청을 이 핸들러에 그대로 위임한다 */
    private lateinit var sensorStreamHandler: SensorStreamHandler

    /**
     * EVIMP1 진동+소음 측정(startCapture)이 진행 중인지.
     * true면 소음 전용 테스트를 시작하지 못하게 막는다.
     */
    private var vibrationCaptureActive: Boolean = false

    /** 마이크 권한 요청 결과를 알려줄 콜백. 요청을 보낸 동안에만 값이 있고,
     *  onRequestPermissionsResult 에서 쓰고 나면 다시 null 로 비운다 */
    private var permissionCallback: MethodChannel.Result? = null

    /**
     * 고속 샘플링 권한 승인을 기다리는 동안 미뤄둔, 승인 후 이어서 실행할
     * 수집 시작 동작. 권한 요청 중이 아니면 null
     */
    private var pendingStartCapture: (() -> Unit)? = null

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-09-21 · 박희정
     * 함수: configureFlutterEngine
     * 목적: Flutter 엔진이 뜰 때 소음·센서·소음테스트 핸들러를 만들고,
     *       MethodChannel·EventChannel을 등록해 Flutter와 안드로이드를
     *       연결한다.
     * 인자: flutterEngine — Flutter 쪽에서 넘겨주는 엔진 인스턴스
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        noiseCaptureHandler = NoiseCaptureHandler(this)
        noiseTestCaptureHandler = NoiseTestCaptureHandler(this)
        sensorStreamHandler = SensorStreamHandler(this, noiseCaptureHandler)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            // → 로직 이동: SensorStreamHandler.onListen()
            .setStreamHandler(sensorStreamHandler)

        EventChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            NOISE_TEST_STREAM_CHANNEL,
        ).setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                noiseTestCaptureHandler.setLiveSink { map ->
                    events?.success(map)
                }
            }

            override fun onCancel(arguments: Any?) {
                noiseTestCaptureHandler.setLiveSink(null)
            }
        })

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
                     * 반환: result.success(Boolean) 으로 응답. 가속도계와
                     *       중력 센서가 둘 다 있으면 true
                     */
                    "checkAvailable" -> {
                        val sensorManager =
                            getSystemService(Context.SENSOR_SERVICE) as SensorManager?
                        val accel =
                            sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                        val gravity =
                            sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
                        result.success(accel != null && gravity != null)
                    }
                    /**
                     * 작성: 2026-09-15 13:30:00 · 박희정
                     * 함수: requestAudioPermission
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "requestAudioPermission" 요청에 응답한다.
                     *       마이크 권한이 이미 있으면 곧바로 성공을
                     *       알려주고, 없으면 시스템 권한 대화상자를 띄운
                     *       뒤 사용자 응답을 기다린다.
                     * 반환: result.success(Boolean) 으로 응답. 이미
                     *       승인된 상태면 즉시 true, 아니면 사용자가
                     *       응답할 때까지 기다렸다가 아래
                     *       onRequestPermissionsResult 가 이어서 응답한다
                     */
                    "requestAudioPermission" -> {
                        if (ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                Manifest.permission.RECORD_AUDIO
                            ) == PackageManager.PERMISSION_GRANTED
                        ) {
                            result.success(true)
                        } else {
                            permissionCallback = result
                            ActivityCompat.requestPermissions(
                                this@MainActivity,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                REQ_AUDIO_PERMISSION
                            )
                        }
                    }
                    /**
                     * 작성: 2026-08-17 15:43:39 · 박건준
                     * 수정: 2026-09-15 13:30:00 · 박희정
                     * 함수: startCapture
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "startCapture" 요청에 응답한다. 소음(마이크)과
                     *       가속도 · 중력 센서 캡처를 함께 시작한다.
                     *       - Android 12(S) 이상은 고속 샘플링 권한이
                     *         없으면 먼저 요청하고, 응답이 온 뒤 시작한다
                     *         (`pendingStartCapture`에 맡겨둔다)
                     *       - 이미 권한이 있거나 Android 12 미만이면
                     *         곧바로 시작한다
                     * 인자: calibrationOffset — 현장·기기 보정(dBA), 기본 0.0
                     *       micDbfsToDbaOffset — dBFS→dBA 오프셋, 기본 85.0
                     * 반환: result.success(null) 로 즉시 응답한다. 실제로
                     *       캡처가 시작됐는지는 기다리지 않는다
                     * 근거: 인용 — OI-4 임시 오프셋(기본 85.0). 측정 —
                     *       SENSOR_DELAY_FASTEST 로 요청해도 실제 수신
                     *       속도는 단말 하드웨어 주기라 200Hz 를 넘는다
                     */
                    "startCapture" -> {
                        val calibrationOffset =
                            call.argument<Double>("calibrationOffset") ?: 0.0
                        val micDbfsToDbaOffset =
                            call.argument<Double>("micDbfsToDbaOffset") ?: 85.0
                        val begin = {
                            // 마이크 공유 충돌 방지: 소음 전용 테스트가 돌고 있으면 먼저 멈춘다
                            if (noiseTestCaptureHandler.isRunning) {
                                noiseTestCaptureHandler.stop()
                            }
                            vibrationCaptureActive = true
                            // → 로직 이동: NoiseCaptureHandler.start()
                            noiseCaptureHandler.start(
                                calibrationOffset,
                                micDbfsToDbaOffset,
                            )
                            // → 로직 이동: SensorStreamHandler.start()
                            sensorStreamHandler.start()
                        }

                        val needsHighRate =
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                        val permName =
                            "android.permission.HIGH_SAMPLING_RATE_SENSORS"
                        if (needsHighRate &&
                            ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                permName
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingStartCapture = begin
                            // → 로직 이동: onRequestPermissionsResult()
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
                     * 수정: 2026-09-15 13:30:00 · 박희정
                     * 함수: stopCapture
                     * 목적: Flutter의 sensor_channel.dart 가 보낸
                     *       "stopCapture" 요청에 응답한다. 센서·소음
                     *       캡처를 멈추고 원본 기록 파일 경로를 돌려준다.
                     * 반환: result.success(String?) 로 응답. 저장된 파일
                     *       경로, 저장하지 못했으면 null
                     */
                    "stopCapture" -> {
                        // → 로직 이동: SensorStreamHandler.stop()
                        val recordPath = sensorStreamHandler.stop()
                        // → 로직 이동: NoiseCaptureHandler.stop()
                        noiseCaptureHandler.stop()
                        vibrationCaptureActive = false
                        result.success(recordPath)
                    }
                    /**
                     * 작성: 2026-09-21 · 박희정
                     * 함수: startNoiseTest
                     * 목적: 소음(dB) 전용 테스트를 시작한다. EVIMP1 측정 중이거나
                     *       이미 테스트가 돌고 있으면 거부한다. 시작 전에
                     *       EVIMP1용 NoiseCaptureHandler를 멈춰 마이크를
                     *       공유하지 않게 한다.
                     * 인자: modeId — rate40k | rate80k | aweight | slow
                     */
                    "startNoiseTest" -> {
                        val modeId = call.argument<String>("modeId") ?: ""
                        if (vibrationCaptureActive) {
                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "error" to "진동 측정이 진행 중이라 소음 테스트를 시작할 수 없습니다.",
                                    "isRunning" to false,
                                ),
                            )
                            return@setMethodCallHandler
                        }
                        if (noiseTestCaptureHandler.isRunning) {
                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "error" to "이미 소음 테스트가 실행 중입니다.",
                                    "isRunning" to true,
                                ),
                            )
                            return@setMethodCallHandler
                        }
                        val mode = NoiseTestMode.fromId(modeId)
                        if (mode == null) {
                            result.success(
                                mapOf(
                                    "ok" to false,
                                    "error" to "알 수 없는 modeId: $modeId",
                                    "isRunning" to false,
                                ),
                            )
                            return@setMethodCallHandler
                        }
                        // EVIMP1 소음 캡처가 마이크를 잡고 있지 않게 먼저 멈춘다
                        noiseCaptureHandler.stop()
                        // → 로직 이동: NoiseTestCaptureHandler.start()
                        result.success(noiseTestCaptureHandler.start(mode))
                    }
                    /**
                     * 작성: 2026-09-21 · 박희정
                     * 함수: stopNoiseTest
                     * 목적: 소음 전용 테스트를 멈추고 파일 경로·통계 요약을 돌려준다.
                     */
                    "stopNoiseTest" -> {
                        // → 로직 이동: NoiseTestCaptureHandler.stop()
                        result.success(noiseTestCaptureHandler.stop())
                    }
                    /**
                     * 작성: 2026-09-21 · 박희정
                     * 함수: getNoiseTestStatus
                     * 목적: 소음 전용 테스트의 현재 상태·통계를 돌려준다.
                     */
                    "getNoiseTestStatus" -> {
                        // → 로직 이동: NoiseTestCaptureHandler.getStatus()
                        result.success(noiseTestCaptureHandler.getStatus())
                    }
                    /**
                     * 함수: else
                     * 목적: 정의되지 않은 메서드 이름의 요청에 미구현으로 응답한다.
                     */
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    /**
     * 작성: 2026-08-17 15:43:39 · 박건준
     * 수정: 2026-09-15 13:30:00 · 박희정
     * 함수: onRequestPermissionsResult
     * 목적: 시스템 권한 대화상자에 대한 사용자 응답을 받아, 기다리고
     *       있던 쪽에 결과를 이어준다.
     *       - 마이크 권한 응답이면 대기 중이던 `permissionCallback`에
     *         승인 여부를 알려준다
     *       - 고속 샘플링 권한 응답이면, 승인 여부와 무관하게 대기 중이던
     *         `pendingStartCapture`(캡처 시작 동작)를 실행한다. 미승인이면
     *         저속으로라도 캡처는 계속 진행하되 경고를 로그로 남긴다
     * 인자: requestCode — 어떤 권한 요청에 대한 응답인지 구분하는 값
     *       (`REQ_AUDIO_PERMISSION` 또는 `REQ_HIGH_RATE_PERMISSION`)
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
        if (requestCode == REQ_AUDIO_PERMISSION) {
            val granted =
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            permissionCallback?.success(granted)
            permissionCallback = null
        }
        if (requestCode == REQ_HIGH_RATE_PERMISSION) {
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
     * 수정: 2026-09-21 · 박희정
     * 함수: onDestroy
     * 목적: 액티비티가 완전히 종료될 때 센서·소음·소음테스트 핸들러를
     *       정리해, 자원을 계속 붙들고 있지 않게 한다.
     */
    override fun onDestroy() {
        super.onDestroy()
        if (::sensorStreamHandler.isInitialized) {
            sensorStreamHandler.stop()
        }
        if (::noiseCaptureHandler.isInitialized) {
            noiseCaptureHandler.stop()
        }
        if (::noiseTestCaptureHandler.isInitialized) {
            noiseTestCaptureHandler.stop()
        }
        vibrationCaptureActive = false
    }
}
