package com.otis.vibration_checker.verify

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager

/**
 * 1ms·3ms 원본 수신 → 간격 통계 → 각각 256Hz 선형 보간 핵심만 분리한 코드.
 *
 * 포함:
 * 1. 1000µs(1ms), 3000µs(3ms) 센서 등록
 * 2. 각 요청에서 raw / gravity / linear 수신
 * 3. SensorEvent.timestamp 기준 센서별 수신 간격 통계
 * 4. 각 요청의 원본을 독립적으로 256Hz 선형 보간
 *
 * 제외:
 * txt, 파일 저장, 임시 파일, Writer, EventChannel, Flutter 통신
 */
class FixedRate256Core(
    context: Context,
    /** 1ms 또는 3ms 요청에서 실제 원본이 들어올 때 호출된다. */
    private val onOriginal: (RequestedRate, OriginalSample) -> Unit,
    /** 1ms 또는 3ms의 256Hz 샘플이 만들어질 때 호출되는 최소 출력 함수 */
    private val onResampled: (RequestedRate, ResampledSample) -> Unit,
) {
    companion object {
        const val TARGET_HZ = 256
        private const val ONE_MS_US = 1000
        private const val THREE_MS_US = 3000
        private const val ONE_SECOND_NS = 1_000_000_000L
    }

    enum class RequestedRate {
        ONE_MS,
        THREE_MS,
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

    /** 센서 하나의 원본 개수와 수신 간격 통계 */
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
                } else {
                    0.0
                }

        val minIntervalMs: Double
            get() =
                if (minIntervalNs == Long.MAX_VALUE) {
                    0.0
                } else {
                    minIntervalNs / 1_000_000.0
                }

        val maxIntervalMs: Double
            get() = maxIntervalNs / 1_000_000.0

        val measuredHz: Double
            get() =
                if (intervalSumNs > 0 && intervalCount > 0) {
                    intervalCount * ONE_SECOND_NS.toDouble() / intervalSumNs
                } else {
                    0.0
                }
    }

    /** 한 요청 주기에서 계산한 raw / gravity / linear 통계 */
    data class RateStats(
        val raw: IntervalStats,
        val gravity: IntervalStats,
        val linear: IntervalStats,
    )

    /** 같은 256Hz timestamp에 맞춘 linear / raw / gravity 결과 */
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

    /** 선형 보간에 필요한 직전 원본점과 현재 원본점 */
    private data class SensorPointPair(
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
                // 첫 원본은 직전점이 없으므로 이전점/현재점에 같은 값을 넣는다.
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

            // 기존 현재점 → 직전점
            previousTimestampNs = currentTimestampNs
            previousX = currentX
            previousY = currentY
            previousZ = currentZ

            // 새 원본 → 현재점
            currentTimestampNs = timestampNs
            currentX = x
            currentY = y
            currentZ = z
        }

        fun interpolate(targetTimestampNs: Long): Triple<Double, Double, Double> {
            if (currentTimestampNs == 0L) return Triple(0.0, 0.0, 0.0)

            val sourceIntervalNs = currentTimestampNs - previousTimestampNs
            if (sourceIntervalNs <= 0L) {
                return Triple(
                    currentX.toDouble(),
                    currentY.toDouble(),
                    currentZ.toDouble(),
                )
            }

            val alpha =
                (
                    (targetTimestampNs - previousTimestampNs).toDouble() /
                        sourceIntervalNs
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

    // 1ms 요청과 3ms 요청은 각각 별도 리스너와 별도 보간 상태를 가진다.
    private val oneMsLane =
        RateLane(
            requestedRate = RequestedRate.ONE_MS,
            samplingPeriodUs = ONE_MS_US,
        )

    private val threeMsLane =
        RateLane(
            requestedRate = RequestedRate.THREE_MS,
            samplingPeriodUs = THREE_MS_US,
        )

    val oneMsStats: RateStats
        get() = oneMsLane.stats

    val threeMsStats: RateStats
        get() = threeMsLane.stats

    // -------------------------------------------------------------------------
    // 1. 1ms와 3ms 센서 등록
    // -------------------------------------------------------------------------
    fun start(): Boolean {
        stop()

        val oneMsStarted = oneMsLane.start()
        val threeMsStarted = threeMsLane.start()

        if (!oneMsStarted || !threeMsStarted) {
            stop()
            return false
        }
        return true
    }

    fun stop() {
        oneMsLane.stop()
        threeMsLane.stop()
    }

    /**
     * 요청 주기 하나의 센서 등록·수신·통계·256Hz 보간을 담당한다.
     * oneMsLane과 threeMsLane은 상태를 공유하지 않는다.
     */
    private inner class RateLane(
        private val requestedRate: RequestedRate,
        private val samplingPeriodUs: Int,
    ) : SensorEventListener {
        private val rawSensor =
            sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        private val gravitySensor =
            sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
        private val linearSensor =
            sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)

        private var rawPoints = SensorPointPair()
        private var gravityPoints = SensorPointPair()
        private var linearPoints = SensorPointPair()

        private var rawIntervalStats = IntervalStats()
        private var gravityIntervalStats = IntervalStats()
        private var linearIntervalStats = IntervalStats()

        val stats: RateStats
            get() =
                RateStats(
                    raw = rawIntervalStats,
                    gravity = gravityIntervalStats,
                    linear = linearIntervalStats,
                )

        // 두 요청 모두 결과는 256Hz이므로 목표 간격은 약 3.90625ms로 같다.
        private val targetIntervalNs = ONE_SECOND_NS / TARGET_HZ
        private var nextTargetTimestampNs = 0L
        private var running = false

        fun start(): Boolean {
            if (rawSensor == null || gravitySensor == null || linearSensor == null) {
                return false
            }

            // 이전 실행 데이터가 섞이지 않게 lane 내부 상태만 초기화한다.
            rawPoints = SensorPointPair()
            gravityPoints = SensorPointPair()
            linearPoints = SensorPointPair()
            rawIntervalStats = IntervalStats()
            gravityIntervalStats = IntervalStats()
            linearIntervalStats = IntervalStats()
            nextTargetTimestampNs = 0L
            running = true

            // samplingPeriodUs=1000 또는 3000을 숫자로 직접 지정한다.
            val rawRegistered =
                sensorManager.registerListener(
                    this,
                    rawSensor,
                    samplingPeriodUs,
                )
            val gravityRegistered =
                sensorManager.registerListener(
                    this,
                    gravitySensor,
                    samplingPeriodUs,
                )
            val linearRegistered =
                sensorManager.registerListener(
                    this,
                    linearSensor,
                    samplingPeriodUs,
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
        }

        // ---------------------------------------------------------------------
        // 2. 해당 요청의 raw / gravity / linear 수신
        // ---------------------------------------------------------------------
        override fun onSensorChanged(event: SensorEvent?) {
            if (!running || event == null) return

            val timestampNs = event.timestamp
            val x = event.values[0]
            val y = event.values[1]
            val z = event.values[2]

            when (event.sensor.type) {
                Sensor.TYPE_ACCELEROMETER -> {
                    val intervalNs =
                        updateIntervalStats(rawIntervalStats, timestampNs)
                    onOriginal(
                        requestedRate,
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
                    val intervalNs =
                        updateIntervalStats(gravityIntervalStats, timestampNs)
                    onOriginal(
                        requestedRate,
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
                    val intervalNs =
                        updateIntervalStats(linearIntervalStats, timestampNs)
                    onOriginal(
                        requestedRate,
                        OriginalSample(
                            SensorKind.LINEAR,
                            timestampNs,
                            intervalNs,
                            x,
                            y,
                            z,
                        ),
                    )
                    processLinearEvent(timestampNs, x, y, z)
                }
            }
        }

        // ---------------------------------------------------------------------
        // 3. SensorEvent.timestamp 기준 센서별 수신 간격 통계
        // ---------------------------------------------------------------------
        private fun updateIntervalStats(
            intervalStats: IntervalStats,
            timestampNs: Long,
        ): Long {
            intervalStats.count++

            var intervalNs = 0L
            if (
                intervalStats.previousTimestampNs > 0L &&
                timestampNs > intervalStats.previousTimestampNs
            ) {
                intervalNs =
                    timestampNs - intervalStats.previousTimestampNs

                intervalStats.intervalCount++
                intervalStats.intervalSumNs += intervalNs
                intervalStats.minIntervalNs =
                    minOf(intervalStats.minIntervalNs, intervalNs)
                intervalStats.maxIntervalNs =
                    maxOf(intervalStats.maxIntervalNs, intervalNs)
            }

            intervalStats.previousTimestampNs = timestampNs
            return intervalNs
        }

        // ---------------------------------------------------------------------
        // 4. 이 요청의 FAST 원본을 독립적으로 256Hz 선형 보간
        // ---------------------------------------------------------------------
        private fun processLinearEvent(
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
                val linear =
                    linearPoints.interpolate(nextTargetTimestampNs)
                val raw =
                    rawPoints.interpolate(nextTargetTimestampNs)
                val gravity =
                    gravityPoints.interpolate(nextTargetTimestampNs)

                onResampled(
                    requestedRate,
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

        override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
            // 이 핵심 검증에서는 정확도 변경 이벤트를 사용하지 않는다.
        }
    }
}
