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
 * - Sensor.TYPE_LINEAR_ACCELERATION / TYPE_ACCELEROMETER / TYPE_GRAVITY를 SENSOR_DELAY_FASTEST로 구독
 * - 타임스탬프(ns) 기반 선형 보간(Linear Interpolation) 적용하여 유효 256Hz 샘플레이트 도출
 * - linear / raw accelerometer / gravity 모두 리샘플 시점에 보간
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

    private data class AxisSample(
        var prevTimestampNs: Long = 0L,
        var prevX: Float = 0f,
        var prevY: Float = 0f,
        var prevZ: Float = 0f,
        var currTimestampNs: Long = 0L,
        var currX: Float = 0f,
        var currY: Float = 0f,
        var currZ: Float = 0f,
    ) {
        fun reset() {
            prevTimestampNs = 0L
            currTimestampNs = 0L
            prevX = 0f
            prevY = 0f
            prevZ = 0f
            currX = 0f
            currY = 0f
            currZ = 0f
        }

        fun push(timestampNs: Long, x: Float, y: Float, z: Float) {
            if (currTimestampNs == 0L) {
                currTimestampNs = timestampNs
                currX = x
                currY = y
                currZ = z
                prevTimestampNs = timestampNs
                prevX = x
                prevY = y
                prevZ = z
                return
            }
            if (timestampNs <= currTimestampNs) {
                currTimestampNs = timestampNs
                currX = x
                currY = y
                currZ = z
                return
            }
            prevTimestampNs = currTimestampNs
            prevX = currX
            prevY = currY
            prevZ = currZ
            currTimestampNs = timestampNs
            currX = x
            currY = y
            currZ = z
        }

        fun interpolateAt(targetNs: Long): Triple<Float, Float, Float> {
            if (currTimestampNs == 0L) return Triple(0f, 0f, 0f)
            if (prevTimestampNs == 0L || currTimestampNs <= prevTimestampNs) {
                return Triple(currX, currY, currZ)
            }
            val deltaNs = currTimestampNs - prevTimestampNs
            val alpha = ((targetNs - prevTimestampNs).toFloat() / deltaNs.toFloat())
                .coerceIn(0f, 1f)
            val x = prevX + alpha * (currX - prevX)
            val y = prevY + alpha * (currY - prevY)
            val z = prevZ + alpha * (currZ - prevZ)
            return Triple(x, y, z)
        }
    }

    private var sensorManager: SensorManager? = null
    private var linearSensor: Sensor? = null
    private var accelerometerSensor: Sensor? = null
    private var gravitySensor: Sensor? = null
    private var eventSink: EventChannel.EventSink? = null
    private val mainHandler = Handler(Looper.getMainLooper())

    private var targetIntervalNs: Long = 1_000_000_000L / 256L
    private val linearSample = AxisSample()
    private val rawSample = AxisSample()
    private val gravitySample = AxisSample()
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
        accelerometerSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        gravitySensor = sensorManager?.getDefaultSensor(Sensor.TYPE_GRAVITY)

        if (linearSensor == null) {
            Log.e(TAG, "Linear Acceleration sensor not available on this device.")
            return
        }

        linearSample.reset()
        rawSample.reset()
        gravitySample.reset()
        nextTargetNs = 0L
        rawCount = 0
        resampledCount = 0
        lastLogNs = 0L
        synchronized(batchBuffer) {
            batchBuffer.clear()
        }

        sensorManager?.registerListener(this, linearSensor, SensorManager.SENSOR_DELAY_FASTEST)
        accelerometerSensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_FASTEST)
        }
        gravitySensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_FASTEST)
        }
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

        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                rawSample.push(
                    event.timestamp,
                    event.values[0],
                    event.values[1],
                    event.values[2],
                )
                return
            }
            Sensor.TYPE_GRAVITY -> {
                gravitySample.push(
                    event.timestamp,
                    event.values[0],
                    event.values[1],
                    event.values[2],
                )
                return
            }
            Sensor.TYPE_LINEAR_ACCELERATION -> {
                // linear acceleration 이벤트 타임스탬프를 256Hz 리샘플 기준으로 사용한다.
            }
            else -> return
        }

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

        if (linearSample.prevTimestampNs == 0L || currNs <= linearSample.prevTimestampNs) {
            linearSample.push(currNs, currX, currY, currZ)
            nextTargetNs = currNs
            return
        }

        linearSample.push(currNs, currX, currY, currZ)

        while (nextTargetNs <= currNs) {
            val deltaNs = linearSample.currTimestampNs - linearSample.prevTimestampNs
            val alpha = if (deltaNs > 0) {
                (nextTargetNs - linearSample.prevTimestampNs).toFloat() / deltaNs.toFloat()
            } else {
                0f
            }

            val interpX = linearSample.prevX + alpha * (linearSample.currX - linearSample.prevX)
            val interpY = linearSample.prevY + alpha * (linearSample.currY - linearSample.prevY)
            val interpZ = linearSample.prevZ + alpha * (linearSample.currZ - linearSample.prevZ)

            val (rawX, rawY, rawZ) = rawSample.interpolateAt(nextTargetNs)
            val (gravX, gravY, gravZ) = gravitySample.interpolateAt(nextTargetNs)

            val sampleMap = mapOf<String, Any>(
                "tsUs" to (nextTargetNs / 1000L),
                "x" to (interpX * MPS2_TO_MG).toDouble(),
                "y" to (interpY * MPS2_TO_MG).toDouble(),
                "z" to (interpZ * MPS2_TO_MG).toDouble(),
                "rawX" to (rawX * MPS2_TO_MG).toDouble(),
                "rawY" to (rawY * MPS2_TO_MG).toDouble(),
                "rawZ" to (rawZ * MPS2_TO_MG).toDouble(),
                "gravityX" to (gravX * MPS2_TO_MG).toDouble(),
                "gravityY" to (gravY * MPS2_TO_MG).toDouble(),
                "gravityZ" to (gravZ * MPS2_TO_MG).toDouble(),
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
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 불필요
    }
}
