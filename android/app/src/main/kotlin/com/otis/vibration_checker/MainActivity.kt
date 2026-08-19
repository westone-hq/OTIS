/*
 * 작성: 2026-08-17 15:43:39
 * 작성자: 박건준
 * 수정: 2026-08-19 13:25:00
 * 수정자: 박희정
 */
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
 * 이 파일은 앱의 안드로이드 쪽 입구입니다.
 *
 * 화면(Flutter)에서 “센서 있어?”, “측정 시작해”, “멈춰” 같은
 * 부탁이 오면 여기서 받아서 처리합니다.
 * 센서 값은 다른 담당(SensorStreamHandler)에게 맡깁니다.
 */
class MainActivity : FlutterActivity() {
    companion object {

        /**
         * Flutter와 Android가 서로 명령을 주고받을 때 사용하는 이름입니다.
         *
         * Flutter 쪽에도 똑같은 이름이 적혀 있어야 합니다.
         * 두 곳의 이름이 다르면 Flutter에서 보낸 명령이
         * Android까지 전달되지 않습니다.
         */
        private const val METHOD_CHANNEL =
            "com.otis.vibration_checker/sensors_method"

        /**
         * Flutter로 센서 값을 계속 보낼 때 사용하는 이름입니다.
         *
         * 위와 마찬가지로 Flutter 쪽 이름과 같아야 연결됩니다.
         */
        private const val STREAM_CHANNEL =
            "com.otis.vibration_checker/sensors_stream"

        /**
         * 마이크 권한을 물어볼 때 붙이는 번호표입니다.
         *
         * 나중에 “이 결과는 마이크 권한에 대한 답이야”라고
         * 구분할 때 씁니다.
         */
        private const val REQ_AUDIO_PERMISSION = 1001

        /**
         * 센서를 아주 빠르게 읽어도 되는지 물어볼 때 붙이는 번호표입니다.
         */
        private const val REQ_HIGH_RATE_PERMISSION = 1002
    }

    /**
     * 마이크 소음을 읽는 담당입니다.
     *
     * 지금은 측정할 때 켜지 않고, 앱이 끝날 때 정리만 합니다.
     * 값은 나중에 채웁니다.
     */
    private lateinit var noiseCaptureHandler: NoiseCaptureHandler

    /**
     * 흔들림·중력 센서를 읽고 파일에 적는 담당입니다.
     *
     * “측정 시작 / 정지” 부탁이 오면 이 담당에게 넘깁니다.
     * 값은 나중에 채웁니다.
     */
    private lateinit var sensorStreamHandler: SensorStreamHandler

    /**
     * 마이크 권한 팝업이 끝난 뒤, 화면에 “허용됐어/아니야”라고
     * 답할 때 쓰는 통로입니다.
     *
     * 팝업을 띄운 동안에만 채워 두고, 답한 뒤에는 비웁니다.
     * 지금은 비어 있습니다.
     */
    private var permissionCallback: MethodChannel.Result? = null

    /**
     * 빠른 센서 권한 팝업이 끝나기 전에, “측정 시작”을 잠깐 미뤄 둔 자리입니다.
     *
     * 권한이 준비되면 여기서 꺼내서 시작합니다.
     * 지금은 비어 있습니다.
     */
    private var pendingStartCapture: (() -> Unit)? = null

    /**
     * 화면 엔진이 준비되면 자동으로 불립니다.
     *
     * 여기서 담당 두 명을 만들고,
     * Flutter와 말할 통로 두 개를 연결합니다.
     */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        // 기본 준비도 먼저 해 둡니다
        super.configureFlutterEngine(flutterEngine)

        // 소음 담당을 만듭니다 (이 화면을 넘겨 줍니다)
        noiseCaptureHandler = NoiseCaptureHandler(this)
        // 센서 담당을 만듭니다 (화면 + 소음 담당을 함께 넘깁니다)
        sensorStreamHandler = SensorStreamHandler(this, noiseCaptureHandler)

        // 센서 값을 계속 보낼 통로를 만들고
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            // 그 통로 일을 센서 담당에게 맡깁니다
            .setStreamHandler(sensorStreamHandler)

        // 명령을 주고받을 통로를 만듭니다
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            // 명령이 오면 아래 내용을 실행합니다
            .setMethodCallHandler { call, result ->
                // 명령 이름에 따라 나눕니다
                when (call.method) {
                    /**
                     * “이 폰으로 측정할 수 있어?”에 답합니다.
                     *
                     * 흔들림 센서와 중력 센서가 둘 다 있어야
                     * 측정할 수 있다고 봅니다.
                     */
                    "checkAvailable" -> {
                        // 폰의 센서 관리자를 가져옵니다
                        val sensorManager =
                            getSystemService(Context.SENSOR_SERVICE) as SensorManager?
                        // 흔들림(가속도) 센서가 있는지 봅니다
                        val accel =
                            sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                        // 중력 센서가 있는지 봅니다
                        val gravity =
                            sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
                        // 둘 다 있으면 true, 아니면 false를 화면에 보냅니다
                        result.success(accel != null && gravity != null)
                    }
                    /**
                     * “마이크 써도 돼?”에 답합니다.
                     *
                     * 이미 허용돼 있으면 바로 예라고 하고,
                     * 아니면 허용 창을 띄웁니다.
                     */
                    "requestAudioPermission" -> {
                        // 이미 마이크 권한이 있는지 확인합니다
                        if (ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                Manifest.permission.RECORD_AUDIO
                            ) == PackageManager.PERMISSION_GRANTED
                        ) {
                            // 이미 허용이면 화면에 true를 보냅니다
                            result.success(true)
                        } else {
                            // 나중에 답하려고 통로를 잠시 보관합니다
                            permissionCallback = result
                            // 마이크 허용 창을 띄웁니다
                            ActivityCompat.requestPermissions(
                                this@MainActivity,
                                arrayOf(Manifest.permission.RECORD_AUDIO),
                                REQ_AUDIO_PERMISSION
                            )
                        }
                    }
                    /**
                     * “측정 시작해”에 답합니다.
                     *
                     * 안드로이드 12 이상이면 빠른 센서 권한이 필요할 수 있어
                     * 먼저 물어보고, 아니면 바로 시작합니다.
                     * 화면에는 “요청은 받았다”고 바로 답합니다.
                     */
                    "startCapture" -> {
                        // 나중에(또는 바로) 실행할 “진짜 시작” 동작입니다
                        val begin = {
                            // 센서 담당에게 시작을 시킵니다
                            sensorStreamHandler.start()
                        }

                        // 이 폰이 안드로이드 12 이상인지 봅니다
                        val needsHighRate =
                            Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                        // 빠른 센서 권한의 공식 이름입니다
                        val permName =
                            "android.permission.HIGH_SAMPLING_RATE_SENSORS"
                        // 12 이상인데 아직 권한이 없으면
                        if (needsHighRate &&
                            ContextCompat.checkSelfPermission(
                                this@MainActivity,
                                permName
                            ) != PackageManager.PERMISSION_GRANTED
                        ) {
                            // 시작 동작을 잠시 넣어 둡니다
                            pendingStartCapture = begin
                            // 빠른 센서 권한 창을 띄웁니다
                            ActivityCompat.requestPermissions(
                                this@MainActivity,
                                arrayOf(permName),
                                REQ_HIGH_RATE_PERMISSION
                            )
                        } else {
                            // 권한이 이미 있거나 필요 없으면 바로 시작합니다
                            begin()
                        }
                        // 화면에는 일단 “접수했다”고 답합니다
                        result.success(null)
                    }
                    /**
                     * “측정 멈춰”에 답합니다.
                     *
                     * 센서를 멈추고, 저장한 원본 파일 위치를 돌려줍니다.
                     */
                    "stopCapture" -> {
                        // 센서 담당을 멈추고 파일 위치를 받습니다
                        val recordPath = sensorStreamHandler.stop()
                        // 그 위치를 화면에 보냅니다
                        result.success(recordPath)
                    }
                    else -> {
                        // 모르는 명령이면 “그건 없어”라고 답합니다
                        result.notImplemented()
                    }
                }
            }
    }

    /**
     * 권한 창에서 사용자가 허용/거부를 고른 뒤 불립니다.
     *
     * 마이크 권한이면 화면에 결과를 보내고,
     * 빠른 센서 권한이면 미뤄 둔 측정을 시작합니다
     * (거부해도 느린 속도로라도 시작합니다).
     */
    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        // 기본 처리도 먼저 합니다
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        // 마이크 권한 결과이면
        if (requestCode == REQ_AUDIO_PERMISSION) {
            // 결과가 있고 첫 값이 “허용”이면 true입니다
            val granted =
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            // 보관해 둔 통로로 화면에 true/false를 보냅니다
            permissionCallback?.success(granted)
            // 통로는 비웁니다
            permissionCallback = null
        // 빠른 센서 권한 결과이면
        } else if (requestCode == REQ_HIGH_RATE_PERMISSION) {
            // 허용됐는지 봅니다
            val granted =
                grantResults.isNotEmpty() &&
                    grantResults[0] == PackageManager.PERMISSION_GRANTED
            // 거부됐으면 기록장에 경고만 남깁니다
            if (!granted) {
                android.util.Log.w(
                    "MainActivity",
                    "고속 샘플링 권한 미승인 — 200Hz 초과 콜백이 오지 않을 수 있다"
                )
            }
            // 허용이든 거부든, 미뤄 둔 측정을 시작합니다
            pendingStartCapture?.invoke()
            // 미뤄 둔 자리는 비웁니다
            pendingStartCapture = null
        }
    }

    /**
     * 이 화면이 완전히 끝날 때 불립니다.
     *
     * 센서·소음 담당이 만들어져 있으면 멈춰서
     * 자원을 붙들고 있지 않게 합니다.
     */
    override fun onDestroy() {
        // 기본 정리도 먼저 합니다
        super.onDestroy()
        // 센서 담당을 이미 만들었으면 멈춥니다
        if (::sensorStreamHandler.isInitialized) {
            sensorStreamHandler.stop()
        }
        // 소음 담당을 이미 만들었으면 멈춥니다
        if (::noiseCaptureHandler.isInitialized) {
            noiseCaptureHandler.stop()
        }
    }
}
