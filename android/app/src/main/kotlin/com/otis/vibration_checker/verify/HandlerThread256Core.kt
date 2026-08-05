package com.otis.vibration_checker.verify

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Handler
import android.os.HandlerThread
import android.os.Looper

/**
 * HandlerThread 방식 핵심.
 *
 * 센서 요청은 FASTEST로 동일하지만 registerListener의 5개 인자 오버로드를 사용해
 * onSensorChanged를 메인 스레드가 아닌 전용 센서 스레드에서 처리한다.
 */
class HandlerThread256Core(
    context: Context,
    private val onOriginal: (OriginalSample) -> Unit,
    private val onResampled: (ResampledSample) -> Unit,
) : SensorEventListener {
    companion object {
        const val TARGET_HZ = 256
        private const val ONE_SECOND_NS = 1_000_000_000L
    }

    enum class SensorKind { RAW, GRAVITY, LINEAR }

    data class OriginalSample(
        val kind: SensorKind,
        val timestampNs: Long,
        val intervalNs: Long,
        val x: Float,
        val y: Float,
        val z: Float,
    )

    data class ResampledSample(
        val timestampNs: Long,
        val linearX: Double,
        val linearY: Double,
        val linearZ: Double,
        val rawX: Double,
        val rawY: Double,
        val rawZ: Double,
        val gravityX: Double,
        val gravityY: Double,
        val gravityZ: Double,
    )

    data class IntervalStats(
        var count: Long = 0,
        var previousTimestampNs: Long = 0,
        var intervalCount: Long = 0,
        var intervalSumNs: Long = 0,
        var minIntervalNs: Long = Long.MAX_VALUE,
        var maxIntervalNs: Long = 0,
    ) {
        val meanIntervalMs: Double
            get() =
                if (intervalCount > 0) {
                    intervalSumNs.toDouble() / intervalCount / 1_000_000.0
                } else 0.0
        val minIntervalMs: Double
            get() =
                if (minIntervalNs == Long.MAX_VALUE) 0.0
                else minIntervalNs / 1_000_000.0
        val maxIntervalMs: Double
            get() = maxIntervalNs / 1_000_000.0
        val measuredHz: Double
            get() =
                if (intervalSumNs > 0 && intervalCount > 0) {
                    intervalCount * ONE_SECOND_NS.toDouble() / intervalSumNs
                } else 0.0
    }

    private data class PointPair(
        var previousTimestampNs: Long = 0,
        var previousX: Float = 0f,
        var previousY: Float = 0f,
        var previousZ: Float = 0f,
        var currentTimestampNs: Long = 0,
        var currentX: Float = 0f,
        var currentY: Float = 0f,
        var currentZ: Float = 0f,
    ) {
        fun push(timestampNs: Long, x: Float, y: Float, z: Float) {
            if (currentTimestampNs == 0L) {
                previousTimestampNs = timestampNs
                previousX = x
                previousY = y
                previousZ = z
                currentTimestampNs = timestampNs
                currentX = x
                currentY = y
                currentZ = z
                return
            }
            if (timestampNs <= currentTimestampNs) return
            previousTimestampNs = currentTimestampNs
            previousX = currentX
            previousY = currentY
            previousZ = currentZ
            currentTimestampNs = timestampNs
            currentX = x
            currentY = y
            currentZ = z
        }

        fun interpolate(targetNs: Long): Triple<Double, Double, Double> {
            if (currentTimestampNs == 0L) return Triple(0.0, 0.0, 0.0)
            val deltaNs = currentTimestampNs - previousTimestampNs
            if (deltaNs <= 0L) {
                return Triple(
                    currentX.toDouble(),
                    currentY.toDouble(),
                    currentZ.toDouble(),
                )
            }
            val alpha =
                (
                    (targetNs - previousTimestampNs).toDouble() /
                        deltaNs
                ).coerceIn(0.0, 1.0)
            return Triple(
                previousX + alpha * (currentX - previousX),
                previousY + alpha * (currentY - previousY),
                previousZ + alpha * (currentZ - previousZ),
            )
        }
    }

    private val sensorManager =
        context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
    private val rawSensor =
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gravitySensor =
        sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
    private val linearSensor =
        sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)

    private var rawPoints = PointPair()
    private var gravityPoints = PointPair()
    private var linearPoints = PointPair()
    var rawStats = IntervalStats()
        private set
    var gravityStats = IntervalStats()
        private set
    var linearStats = IntervalStats()
        private set

    private val targetIntervalNs = ONE_SECOND_NS / TARGET_HZ
    private var nextTargetTimestampNs = 0L
    private var sensorThread: HandlerThread? = null
    private var running = false

    fun start(): Boolean {
        stop()
        if (rawSensor == null || gravitySensor == null || linearSensor == null) {
            return false
        }

        rawPoints = PointPair()
        gravityPoints = PointPair()
        linearPoints = PointPair()
        rawStats = IntervalStats()
        gravityStats = IntervalStats()
        linearStats = IntervalStats()
        nextTargetTimestampNs = 0L

        val thread = HandlerThread("OTIS-HandlerThread-Sensor")
        thread.start()
        sensorThread = thread
        val sensorHandler = Handler(thread.looper)
        running = true

        // maxReportLatencyUs=0: 배칭 없이 가능한 즉시 전용 HandlerThread로 전달.
        val rawRegistered =
            sensorManager.registerListener(
                this,
                rawSensor,
                SensorManager.SENSOR_DELAY_FASTEST,
                0,
                sensorHandler,
            )
        val gravityRegistered =
            sensorManager.registerListener(
                this,
                gravitySensor,
                SensorManager.SENSOR_DELAY_FASTEST,
                0,
                sensorHandler,
            )
        val linearRegistered =
            sensorManager.registerListener(
                this,
                linearSensor,
                SensorManager.SENSOR_DELAY_FASTEST,
                0,
                sensorHandler,
            )

        if (!rawRegistered || !gravityRegistered || !linearRegistered) {
            stop()
            return false
        }
        return true
    }

    fun stop() {
        running = false
        sensorManager.unregisterListener(this)
        val thread = sensorThread
        thread?.quitSafely()
        if (thread != null && Looper.myLooper() != thread.looper) {
            try {
                thread.join(2000)
            } catch (_: InterruptedException) {
                Thread.currentThread().interrupt()
            }
        }
        sensorThread = null
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (!running || event == null) return
        val timestampNs = event.timestamp
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                val intervalNs = updateStats(rawStats, timestampNs)
                onOriginal(
                    OriginalSample(
                        SensorKind.RAW,
                        timestampNs,
                        intervalNs,
                        x,
                        y,
                        z,
                    ),
                )
                rawPoints.push(timestampNs, x, y, z)
                return
            }
            Sensor.TYPE_GRAVITY -> {
                val intervalNs = updateStats(gravityStats, timestampNs)
                onOriginal(
                    OriginalSample(
                        SensorKind.GRAVITY,
                        timestampNs,
                        intervalNs,
                        x,
                        y,
                        z,
                    ),
                )
                gravityPoints.push(timestampNs, x, y, z)
                return
            }
            Sensor.TYPE_LINEAR_ACCELERATION -> {
                val intervalNs = updateStats(linearStats, timestampNs)
                onOriginal(
                    OriginalSample(
                        SensorKind.LINEAR,
                        timestampNs,
                        intervalNs,
                        x,
                        y,
                        z,
                    ),
                )
                processLinear(timestampNs, x, y, z)
            }
        }
    }

    private fun updateStats(stats: IntervalStats, timestampNs: Long): Long {
        stats.count++
        var intervalNs = 0L
        if (
            stats.previousTimestampNs > 0L &&
            timestampNs > stats.previousTimestampNs
        ) {
            intervalNs = timestampNs - stats.previousTimestampNs
            stats.intervalCount++
            stats.intervalSumNs += intervalNs
            stats.minIntervalNs = minOf(stats.minIntervalNs, intervalNs)
            stats.maxIntervalNs = maxOf(stats.maxIntervalNs, intervalNs)
        }
        stats.previousTimestampNs = timestampNs
        return intervalNs
    }

    private fun processLinear(
        timestampNs: Long,
        x: Float,
        y: Float,
        z: Float,
    ) {
        if (linearPoints.currentTimestampNs == 0L) {
            linearPoints.push(timestampNs, x, y, z)
            nextTargetTimestampNs = timestampNs
            return
        }
        linearPoints.push(timestampNs, x, y, z)

        while (nextTargetTimestampNs <= timestampNs) {
            val linear = linearPoints.interpolate(nextTargetTimestampNs)
            val raw = rawPoints.interpolate(nextTargetTimestampNs)
            val gravity = gravityPoints.interpolate(nextTargetTimestampNs)
            onResampled(
                ResampledSample(
                    timestampNs = nextTargetTimestampNs,
                    linearX = linear.first,
                    linearY = linear.second,
                    linearZ = linear.third,
                    rawX = raw.first,
                    rawY = raw.second,
                    rawZ = raw.third,
                    gravityX = gravity.first,
                    gravityY = gravity.second,
                    gravityZ = gravity.third,
                ),
            )
            nextTargetTimestampNs += targetIntervalNs
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
