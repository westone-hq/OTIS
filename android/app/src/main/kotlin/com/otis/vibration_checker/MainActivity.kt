package com.otis.vibration_checker

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
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
    }

    private lateinit var noiseCaptureHandler: NoiseCaptureHandler
    private lateinit var sensorStreamHandler: SensorStreamHandler
    private var permissionCallback: MethodChannel.Result? = null

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
                        val sampleRate = call.argument<Int>("sampleRate") ?: 256
                        val calibrationOffset = call.argument<Double>("calibrationOffset") ?: 0.0
                        val micDbfsToDbaOffset = call.argument<Double>("micDbfsToDbaOffset") ?: 85.0
                        noiseCaptureHandler.start(calibrationOffset, micDbfsToDbaOffset)
                        sensorStreamHandler.start(sampleRate)
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
