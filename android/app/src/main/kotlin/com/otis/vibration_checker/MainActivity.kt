package com.otis.vibration_checker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorManager
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import com.otis.vibration_checker.verify.FastestVerifyHandler
import com.otis.vibration_checker.verify.FixedRateVerifyHandler
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val METHOD_CHANNEL = "com.otis.vibration_checker/sensors_method"
        private const val STREAM_CHANNEL = "com.otis.vibration_checker/sensors_stream"
        private const val FASTEST_VERIFY_METHOD = "com.otis.vibration_checker/verify_fastest_method"
        private const val FASTEST_VERIFY_STREAM = "com.otis.vibration_checker/verify_fastest_stream"
        private const val FIXED_VERIFY_METHOD = "com.otis.vibration_checker/verify_fixed_method"
        private const val FIXED_VERIFY_STREAM = "com.otis.vibration_checker/verify_fixed_stream"
        private const val REQ_AUDIO_PERMISSION = 1001
    }

    private lateinit var noiseCaptureHandler: NoiseCaptureHandler
    private lateinit var sensorStreamHandler: SensorStreamHandler
    private lateinit var fastestVerifyHandler: FastestVerifyHandler
    private lateinit var fixedRateVerifyHandler: FixedRateVerifyHandler
    private var permissionCallback: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        noiseCaptureHandler = NoiseCaptureHandler(this)
        sensorStreamHandler = SensorStreamHandler(this, noiseCaptureHandler)
        fastestVerifyHandler = FastestVerifyHandler(this)
        fixedRateVerifyHandler = FixedRateVerifyHandler(this)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, STREAM_CHANNEL)
            .setStreamHandler(sensorStreamHandler)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FASTEST_VERIFY_STREAM)
            .setStreamHandler(fastestVerifyHandler)
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, FIXED_VERIFY_STREAM)
            .setStreamHandler(fixedRateVerifyHandler)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "checkAvailable" -> {
                        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager?
                        val linearSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)
                        result.success(linearSensor != null)
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
                        val sampleRate =
                            call.argument<Int>("sampleRate")
                                ?: SensorStreamHandler.TARGET_SAMPLE_RATE_HZ
                        val calibrationOffset = call.argument<Double>("calibrationOffset") ?: 0.0
                        val micDbfsToDbaOffset = call.argument<Double>("micDbfsToDbaOffset") ?: 85.0
                        noiseCaptureHandler.start(calibrationOffset, micDbfsToDbaOffset)
                        sensorStreamHandler.start(sampleRate)
                        result.success(null)
                    }
                    "stopCapture" -> {
                        val nativePaths = sensorStreamHandler.stop()
                        noiseCaptureHandler.stop()
                        result.success(nativePaths)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }

        // 페이지 1 전용: FASTEST → 256Hz → 3~7.txt
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FASTEST_VERIFY_METHOD)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val sampleRate =
                            call.argument<Int>("sampleRate")
                                ?: FastestVerifyHandler.TARGET_HZ
                        val started = fastestVerifyHandler.start(sampleRate)
                        if (started) {
                            result.success(null)
                        } else {
                            result.error(
                                "VERIFY_SENSOR_UNAVAILABLE",
                                "검증에 필요한 raw/gravity/linear 센서를 시작할 수 없습니다.",
                                null,
                            )
                        }
                    }
                    "stop" -> {
                        result.success(fastestVerifyHandler.stop())
                    }
                    else -> result.notImplemented()
                }
            }

        // 페이지 2 전용: 1ms·3ms → 각각 256Hz → 1.txt·3.txt
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, FIXED_VERIFY_METHOD)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "start" -> {
                        val sampleRate =
                            call.argument<Int>("sampleRate")
                                ?: FixedRateVerifyHandler.TARGET_HZ
                        val started = fixedRateVerifyHandler.start(sampleRate)
                        if (started) {
                            result.success(null)
                        } else {
                            result.error(
                                "VERIFY_SENSOR_UNAVAILABLE",
                                "1ms·3ms 검증 센서를 시작할 수 없습니다.",
                                null,
                            )
                        }
                    }
                    "stop" -> result.success(fixedRateVerifyHandler.stop())
                    else -> result.notImplemented()
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
        }
    }

    override fun onDestroy() {
        super.onDestroy()
        if (::sensorStreamHandler.isInitialized) {
            sensorStreamHandler.stop() // 경로 불필요 (Activity 종료)
        }
        if (::fastestVerifyHandler.isInitialized) {
            fastestVerifyHandler.stop()
        }
        if (::fixedRateVerifyHandler.isInitialized) {
            fixedRateVerifyHandler.stop()
        }
        if (::noiseCaptureHandler.isInitialized) {
            noiseCaptureHandler.stop()
        }
    }
}
