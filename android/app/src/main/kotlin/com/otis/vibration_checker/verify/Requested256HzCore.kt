package com.otis.vibration_checker.verify

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager

/**
 * 256Hz 요청 전용 독립 측정 코드.
 *
 * 다른 주파수의 원본을 재사용하지 않고 samplingPeriodUs=3906으로 센서를 별도 등록한다.
 * Android가 실제로 전달한 원본 timestamp 간격과 실측 Hz를 센서별로 계산한다.
 */
class Requested256HzCore(
    context: Context,
    private val onOriginal: (OriginalSample) -> Unit,
) : SensorEventListener {
    companion object {
        const val REQUESTED_HZ = 256
        const val SAMPLING_PERIOD_US = 3906
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

    data class IntervalStats(
        var count: Long = 0,
        var previousTimestampNs: Long = 0,
        var intervalCount: Long = 0,
        var intervalSumNs: Long = 0,
        var minIntervalNs: Long = Long.MAX_VALUE,
        var maxIntervalNs: Long = 0,
    ) {
        val meanIntervalUs: Double
            get() =
                if (intervalCount > 0) {
                    intervalSumNs.toDouble() / intervalCount / 1_000.0
                } else {
                    0.0
                }
        val minIntervalUs: Double
            get() =
                if (minIntervalNs == Long.MAX_VALUE) 0.0 else minIntervalNs / 1_000.0
        val maxIntervalUs: Double
            get() = maxIntervalNs / 1_000.0
        val measuredHz: Double
            get() =
                if (intervalSumNs > 0 && intervalCount > 0) {
                    intervalCount * ONE_SECOND_NS.toDouble() / intervalSumNs
                } else {
                    0.0
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

    var rawStats = IntervalStats()
        private set
    var gravityStats = IntervalStats()
        private set
    var linearStats = IntervalStats()
        private set
    private var running = false

    fun start(): Boolean {
        stop()
        if (rawSensor == null || gravitySensor == null || linearSensor == null) return false
        rawStats = IntervalStats()
        gravityStats = IntervalStats()
        linearStats = IntervalStats()
        running = true

        val rawRegistered =
            sensorManager.registerListener(this, rawSensor, SAMPLING_PERIOD_US)
        val gravityRegistered =
            sensorManager.registerListener(this, gravitySensor, SAMPLING_PERIOD_US)
        val linearRegistered =
            sensorManager.registerListener(this, linearSensor, SAMPLING_PERIOD_US)
        if (!rawRegistered || !gravityRegistered || !linearRegistered) {
            stop()
            return false
        }
        return true
    }

    fun stop() {
        running = false
        sensorManager.unregisterListener(this)
    }

    override fun onSensorChanged(event: SensorEvent?) {
        if (!running || event == null) return
        val timestampNs = event.timestamp
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]
        val kind: SensorKind
        val stats: IntervalStats
        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                kind = SensorKind.RAW
                stats = rawStats
            }
            Sensor.TYPE_GRAVITY -> {
                kind = SensorKind.GRAVITY
                stats = gravityStats
            }
            Sensor.TYPE_LINEAR_ACCELERATION -> {
                kind = SensorKind.LINEAR
                stats = linearStats
            }
            else -> return
        }
        val intervalNs = updateStats(stats, timestampNs)
        onOriginal(OriginalSample(kind, timestampNs, intervalNs, x, y, z))
    }

    private fun updateStats(stats: IntervalStats, timestampNs: Long): Long {
        stats.count++
        var intervalNs = 0L
        if (stats.previousTimestampNs > 0L && timestampNs > stats.previousTimestampNs) {
            intervalNs = timestampNs - stats.previousTimestampNs
            stats.intervalCount++
            stats.intervalSumNs += intervalNs
            stats.minIntervalNs = minOf(stats.minIntervalNs, intervalNs)
            stats.maxIntervalNs = maxOf(stats.maxIntervalNs, intervalNs)
        }
        stats.previousTimestampNs = timestampNs
        return intervalNs
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 수신 주기 검증에서는 정확도 등급 변경을 사용하지 않는다.
    }
}
