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
 *
 * 이중 구독:
 * - FASTEST(≈3~7ms): 분석용 256Hz 리샘플 + raw_3to7ms 원본 덤프
 * - samplingPeriodUs=3000(1~3ms 요청): raw_1to3ms 원본 덤프 전용
 *
 * 참고: 요청 주기는 힌트이며 실제 콜백 간격은 기기/OS에 따라 다를 수 있다.
 */
class SensorStreamHandler(
    private val context: Context,
    private val noiseCaptureHandler: NoiseCaptureHandler
) : EventChannel.StreamHandler, SensorEventListener {

    companion object {
        private const val TAG = "SensorStreamHandler"
        private const val MPS2_TO_MG = 101.97162129779283
        private const val BATCH_SIZE = 32

        /**
         * 분석용 리샘플 목표 Hz (Flutter [SampleRate.hz]와 동일해야 함).
         * 간격 = 1e9/TARGET_SAMPLE_RATE_HZ ns ≈ 3.906ms (3906µs).
         */
        const val TARGET_SAMPLE_RATE_HZ = 256

        /** 1~3ms 요청 (원본 덤프 전용 스트림) */
        private const val SAMPLING_PERIOD_1TO3_US = 3000
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

    private var targetIntervalNs: Long = 1_000_000_000L / TARGET_SAMPLE_RATE_HZ
    private val linearSample = AxisSample()
    private val rawSample = AxisSample()
    private val gravitySample = AxisSample()
    private var nextTargetNs: Long = 0L

    private var rawCount: Int = 0
    private var resampledCount: Int = 0
    private var lastLogNs: Long = 0L

    private val batchBuffer = ArrayList<Map<String, Any>>(BATCH_SIZE)

    /** FASTEST(≈3~7ms) 원본 덤프 — 분석 스트림과 동일 리스너 */
    private val dump3to7 = NativeDumpWriter(
        context,
        tag = "native3to7",
        requestLabel = "SENSOR_DELAY_FASTEST (≈3~7ms 요청)",
    )

    /** 3000us(1~3ms) 원본 덤프 전용 */
    private val dump1to3 = NativeDumpWriter(
        context,
        tag = "native1to3",
        requestLabel = "samplingPeriodUs=$SAMPLING_PERIOD_1TO3_US (1~3ms 요청)",
    )

    private val listener1to3 = object : SensorEventListener {
        override fun onSensorChanged(event: SensorEvent?) {
            if (event == null) return
            val type = when (event.sensor.type) {
                Sensor.TYPE_ACCELEROMETER -> "raw"
                Sensor.TYPE_GRAVITY -> "gravity"
                Sensor.TYPE_LINEAR_ACCELERATION -> "linear"
                else -> return
            }
            dump1to3.append(type, event.timestamp, event.values[0], event.values[1], event.values[2])
        }

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
    }

    fun start(targetSampleRate: Int) {
        val rate =
            if (targetSampleRate > 0) targetSampleRate else TARGET_SAMPLE_RATE_HZ
        // 1초(ns) / Hz = 샘플 간격. 256Hz → ≈ 3.90625ms
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
        dump3to7.open()
        dump1to3.open()

        // A) ≈3~7ms: 분석(256Hz 리샘플) + 원본 덤프
        sensorManager?.registerListener(this, linearSensor, SensorManager.SENSOR_DELAY_FASTEST)
        accelerometerSensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_FASTEST)
        }
        gravitySensor?.let {
            sensorManager?.registerListener(this, it, SensorManager.SENSOR_DELAY_FASTEST)
        }

        // B) 1~3ms 요청: 원본 덤프만
        sensorManager?.registerListener(listener1to3, linearSensor, SAMPLING_PERIOD_1TO3_US)
        accelerometerSensor?.let {
            sensorManager?.registerListener(listener1to3, it, SAMPLING_PERIOD_1TO3_US)
        }
        gravitySensor?.let {
            sensorManager?.registerListener(listener1to3, it, SAMPLING_PERIOD_1TO3_US)
        }

        Log.i(
            TAG,
            "SensorStreamHandler started: FASTEST(≈3~7ms)+${SAMPLING_PERIOD_1TO3_US}us(1~3ms), " +
                "resampleTarget=${rate}Hz",
        )
    }

    /**
     * 센서 구독 종료 후 원본 덤프 경로 맵을 반환한다.
     * keys: native3to7, native1to3
     */
    fun stop(): Map<String, String> {
        sensorManager?.unregisterListener(this)
        sensorManager?.unregisterListener(listener1to3)
        synchronized(batchBuffer) {
            batchBuffer.clear()
        }
        // close()는 중복 호출해도 마지막 경로를 유지한다 (EventChannel onCancel → stopCapture 순서 대비)
        val path3 = dump3to7.close()
        val path1 = dump1to3.close()
        Log.i(
            TAG,
            "SensorStreamHandler stopped. " +
                "3to7 raw=${dump3to7.accelCount} path=$path3 · " +
                "1to3 raw=${dump1to3.accelCount} path=$path1",
        )
        val out = linkedMapOf<String, String>()
        if (!path3.isNullOrEmpty()) out["native3to7"] = path3
        if (!path1.isNullOrEmpty()) out["native1to3"] = path1
        return out
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        this.eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        // sink만 끊는다. 덤프 close/경로 회수는 stopCapture→stop()에서 한다.
        // (여기서 stop() 하면 경로가 버려진 채 초별 txt가 저장되지 않음)
        this.eventSink = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (event == null || eventSink == null) return

        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                dump3to7.append(
                    "raw",
                    event.timestamp,
                    event.values[0],
                    event.values[1],
                    event.values[2],
                )
                rawSample.push(
                    event.timestamp,
                    event.values[0],
                    event.values[1],
                    event.values[2],
                )
                return
            }
            Sensor.TYPE_GRAVITY -> {
                dump3to7.append(
                    "gravity",
                    event.timestamp,
                    event.values[0],
                    event.values[1],
                    event.values[2],
                )
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

        dump3to7.append("linear", currNs, currX, currY, currZ)

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
