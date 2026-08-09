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

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.otis.vibration_checker/sensors_method"
        private const val STREAM_CHANNEL = "com.otis.vibration_checker/sensors_stream"
        private const val REQ_AUDIO_PERMISSION = 1001
        private const val REQ_HIGH_RATE_PERMISSION = 1002
    }

    private lateinit var noiseCaptureHandler: NoiseCaptureHandler
    private lateinit var sensorStreamHandler: SensorStreamHandler
    private var permissionCallback: MethodChannel.Result? = null

    // 고속 샘플링 권한 승인 후 이어서 실행할 수집 시작 동작
    private var pendingStartCapture: (() -> Unit)? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        noiseCaptureHandler = NoiseCaptureHandler(this)
        sensorStreamHandler = SensorStreamHandler(this, noiseCaptureHandler)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            .setStreamHandler(sensorStreamHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkAvailable" -> {
                        // 계약: 가속도계와 중력 센서가 모두 있어야 측정 가능 (RD-6)
                        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager?
                        val accel = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
                        val gravity = sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)
                        result.success(accel != null && gravity != null)
                    }
                    "requestAudioPermission" -> {
                        if (ContextCompat.checkSelfPermission(this@MainActivity, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED) {
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
                    "startCapture" -> {
                        val calibrationOffset = call.argument<Double>("calibrationOffset") ?: 0.0
                        val micDbfsToDbaOffset = call.argument<Double>("micDbfsToDbaOffset") ?: 85.0

                        // 실제 수집 시작 동작
                        val begin = {
                            noiseCaptureHandler.start(calibrationOffset, micDbfsToDbaOffset)
                            sensorStreamHandler.start()
                        }

                        // SENSOR_DELAY_FASTEST 로 받으므로 실제 수신 속도는
                        // 단말 하드웨어 주기이며 200Hz 를 넘는다. 따라서 Android 12+
                        // 에서는 항상 고속 샘플링 권한 확보를 먼저 시도한다.
                        // 근거: 측정 — 동일 단말 FASTEST 조건 raw 실측 421Hz
                        val needsHighRate = Build.VERSION.SDK_INT >= Build.VERSION_CODES.S
                        val permName = "android.permission.HIGH_SAMPLING_RATE_SENSORS"
                        if (needsHighRate &&
                            ContextCompat.checkSelfPermission(this@MainActivity, permName)
                                != PackageManager.PERMISSION_GRANTED
                        ) {
                            pendingStartCapture = begin
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
                    "stopCapture" -> {
                        // 계약: 원본 기록 파일 경로를 돌려준다
                        val recordPath = sensorStreamHandler.stop()
                        noiseCaptureHandler.stop()
                        result.success(recordPath)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == REQ_AUDIO_PERMISSION) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
            permissionCallback?.success(granted)
            permissionCallback = null
        } else if (requestCode == REQ_HIGH_RATE_PERMISSION) {
            val granted = grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED
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

    override fun onDestroy() {
        super.onDestroy()
        if (::sensorStreamHandler.isInitialized) {
            sensorStreamHandler.stop()
        }
        if (::noiseCaptureHandler.isInitialized) {
            noiseCaptureHandler.stop()
        }
    }
}
