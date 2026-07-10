package com.otis.vibration_checker

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.Looper
import android.util.Log
import io.flutter.plugin.common.EventChannel

/**
 * P11 · 안드로이드 가속도 센서 스트림 핸들러 및 256Hz 선형 보간 리샘플러
 * - Sensor.TYPE_LINEAR_ACCELERATION을 SENSOR_DELAY_FASTEST로 구독
 * - 타임스탬프(ns) 기반 선형 보간(Linear Interpolation) 적용하여 유효 256Hz 샘플레이트 도출
 * - m/s² -> mg 단위 변환 (1 m/s² = 101.97 mg)
 * - 32샘플 단위 배칭으로 Flutter EventChannel 오버헤드 최적화
 */
class SensorStreamHandler(
    private val context: Context,
    private val noiseCaptureHandler: NoiseCaptureHandler
) : EventChannel.StreamHandler, SensorEventListener {

    companion object {
        private const val TAG = "SensorStreamHandler"
        private const val MPS2_TO_MG = 101.97162129779283
        private const val BATCH_SIZE = 32
    }

    private var sensorManager: SensorManager? = null
    private var linearSensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var targetIntervalNs: Long = 1_000_000_000L / 256L // 256Hz 기본 간격 (약 3,906,250 ns)
    private var prevTimestampNs: Long = 0L
    private var prevX: Float = 0f
    private var prevY: Float = 0f
    private var prevZ: Float = 0f
    private var nextTargetNs: Long = 0L

    private var rawCount: Int = 0
    private var resampledCount: Int = 0
    private var lastLogNs: Long = 0L

    private val batchBuffer = ArrayList<Map<String, Any>>(BATCH_SIZE)

    fun start(targetSampleRate: Int) {
        val rate = if (targetSampleRate > 0) targetSampleRate else 256
        targetIntervalNs = 1_000_000_000L / rate

        sensorManager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager?
        linearSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)

        if (linearSensor == null) {
            Log.e(TAG, "Linear Acceleration sensor not available on this device.")
            return
        }

        prevTimestampNs = 0L
        nextTargetNs = 0L
        rawCount = 0
        resampledCount = 0
        lastLogNs = 0L
        synchronized(batchBuffer) {
            batchBuffer.clear()
        }

        sensorManager?.registerListener(this, linearSensor, SensorManager.SENSOR_DELAY_FASTEST)
        Log.i(TAG, "SensorStreamHandler started at $rate Hz target.")
    }

    fun stop() {
        sensorManager?.unregisterListener(this)
        synchronized(batchBuffer) {
            batchBuffer.clear()
        }
        Log.i(TAG, "SensorStreamHandler stopped.")
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        this.eventSink = null
        stop()
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || eventSink == null) return

        val currNs = event.timestamp
        val currX = event.values[0]
        val currY = event.values[1]
        val currZ = event.values[2]

        rawCount++
        if (lastLogNs == 0L) lastLogNs = currNs
        if (currNs - lastLogNs >= 1_000_000_000L) {
            val elapsedSec = (currNs - lastLogNs) / 1_000_000_000.0
            val rawHz = (rawCount / elapsedSec).toInt()
            val resampHz = (resampledCount / elapsedSec).toInt()
            Log.i(TAG, "[Device: ${android.os.Build.MODEL}] 1s Stats -> Raw Hz: $rawHz, Resampled Hz: $resampHz, Batch Size: $BATCH_SIZE")
            rawCount = 0
            resampledCount = 0
            lastLogNs = currNs
        }

        if (prevTimestampNs == 0L || currNs <= prevTimestampNs) {
            prevTimestampNs = currNs
            prevX = currX
            prevY = currY
            prevZ = currZ
            nextTargetNs = currNs
            return
        }

        // 선형 보간을 통해 nextTargetNs <= currNs 이 만족되는 모든 시점에 대해 샘플 생성
        while (nextTargetNs <= currNs) {
            val deltaNs = currNs - prevTimestampNs
            val alpha = if (deltaNs > 0) (nextTargetNs - prevTimestampNs).toFloat() / deltaNs.toFloat() else 0f
            
            val interpX = prevX + alpha * (currX - prevX)
            val interpY = prevY + alpha * (currY - prevY)
            val interpZ = prevZ + alpha * (currZ - prevZ)

            val sampleMap = mapOf<String, Any>(
                "tsUs" to (nextTargetNs / 1000L),
                "x" to (interpX * MPS2_TO_MG).toDouble(),
                "y" to (interpY * MPS2_TO_MG).toDouble(),
                "z" to (interpZ * MPS2_TO_MG).toDouble(),
                "noiseDba" to noiseCaptureHandler.latestDba
            )

            resampledCount++
            var readyBatch: List<Map<String, Any>>? = null
            synchronized(batchBuffer) {
                batchBuffer.add(sampleMap)
                if (batchBuffer.size >= BATCH_SIZE) {
                    readyBatch = ArrayList(batchBuffer)
                    batchBuffer.clear()
                }
            }

            readyBatch?.let { batch ->
                mainHandler.post {
                    eventSink?.success(batch)
                }
            }

            nextTargetNs += targetIntervalNs
        }

        prevTimestampNs = currNs
        prevX = currX
        prevY = currY
        prevZ = currZ
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 불필요
    }
}
