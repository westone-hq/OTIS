package com.otis.vibration_checker.verify

import android.content.Context
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager

/**
 * FASTEST 원본 수신 → 간격 통계 → 256Hz 선형 보간 핵심만 분리한 코드.
 *
 * 포함:
 * 1. 센서 등록
 * 2. raw / gravity / linear 수신
 * 3. SensorEvent.timestamp 기준 수신 간격 통계
 * 4. 256Hz 선형 보간
 *
 * 제외:
 * txt, 파일 저장, 임시 파일, Writer, EventChannel, Flutter 통신
 */
class Fastest256Core(
    context: Context,
    /** Android가 실제로 준 원본이 들어올 때 호출된다. */
    private val onOriginal: (OriginalSample) -> Unit,
    /** 256Hz 샘플이 하나 만들어질 때 호출되는 최소 출력 함수 */
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

    /** 같은 센서 타입끼리의 수신 간격 통계 */
    data class IntervalStats(
        var count: Long = 0, // 받은 원본 총개수
        var previousTimestampNs: Long = 0, // 같은 센서의 직전 timestamp
        var intervalCount: Long = 0, // 정상 간격 개수
        var intervalSumNs: Long = 0, // 간격 합계
        var minIntervalNs: Long = Long.MAX_VALUE, // 최소 간격
        var maxIntervalNs: Long = 0, // 최대 간격
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

    /** 256Hz의 같은 timestamp에 맞춘 linear / raw / gravity 결과 */
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

    /** 선형 보간에 필요한 직전점과 현재점 */
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
        /** 새 원본이 오면 현재점을 직전점으로 옮기고 새 값을 현재점에 넣는다. */
        fun push(timestampNs: Long, x: Float, y: Float, z: Float) {
            if (currentTimestampNs == 0L) {
                // 첫 원본은 비교할 이전점이 없으므로 양쪽에 같은 값을 넣는다.
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

            // timestamp가 과거로 돌아간 이벤트는 보간 순서를 깨므로 무시한다.
            if (timestampNs <= currentTimestampNs) return

            // 기존 현재점 → 직전점
            previousTimestampNs = currentTimestampNs
            previousX = currentX
            previousY = currentY
            previousZ = currentZ

            // 새 센서값 → 현재점
            currentTimestampNs = timestampNs
            currentX = x
            currentY = y
            currentZ = z
        }

        /** 직전점과 현재점을 연결한 직선 위에서 targetTimestampNs의 값을 계산한다. */
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

            // alpha=0이면 직전점, alpha=1이면 현재점이다.
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

    private val rawSensor =
        sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
    private val gravitySensor =
        sensorManager.getDefaultSensor(Sensor.TYPE_GRAVITY)
    private val linearSensor =
        sensorManager.getDefaultSensor(Sensor.TYPE_LINEAR_ACCELERATION)

    private val rawPoints = SensorPointPair()
    private val gravityPoints = SensorPointPair()
    private val linearPoints = SensorPointPair()

    val rawStats = IntervalStats()
    val gravityStats = IntervalStats()
    val linearStats = IntervalStats()

    // 1초 / 256 = 3,906,250ns = 약 3.90625ms
    private val targetIntervalNs = ONE_SECOND_NS / TARGET_HZ
    private var nextTargetTimestampNs = 0L
    private var running = false

    // -------------------------------------------------------------------------
    // 1. 센서 등록
    // -------------------------------------------------------------------------
    fun start(): Boolean {
        if (rawSensor == null || gravitySensor == null || linearSensor == null) {
            return false
        }

        running = true

        // 같은 리스너(this)에 세 센서를 FASTEST로 등록한다.
        val rawRegistered =
            sensorManager.registerListener(
                this,
                rawSensor,
                SensorManager.SENSOR_DELAY_FASTEST,
            )
        val gravityRegistered =
            sensorManager.registerListener(
                this,
                gravitySensor,
                SensorManager.SENSOR_DELAY_FASTEST,
            )
        val linearRegistered =
            sensorManager.registerListener(
                this,
                linearSensor,
                SensorManager.SENSOR_DELAY_FASTEST,
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

    // -------------------------------------------------------------------------
    // 2. onSensorChanged에서 raw / gravity / linear 수신
    // -------------------------------------------------------------------------
    override fun onSensorChanged(event: SensorEvent?) {
        if (!running || event == null) return

        val timestampNs = event.timestamp // Android 센서 하드웨어 시각
        val x = event.values[0]
        val y = event.values[1]
        val z = event.values[2]

        when (event.sensor.type) {
            Sensor.TYPE_ACCELEROMETER -> {
                // 3. raw 원본 수신 간격 통계
                val intervalNs = updateIntervalStats(rawStats, timestampNs)
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

                // 4. raw 선형 보간에 사용할 직전점/현재점 갱신
                rawPoints.push(timestampNs, x, y, z)
                return
            }

            Sensor.TYPE_GRAVITY -> {
                // 3. gravity 원본 수신 간격 통계
                val intervalNs = updateIntervalStats(gravityStats, timestampNs)
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

                // 4. gravity 선형 보간에 사용할 직전점/현재점 갱신
                gravityPoints.push(timestampNs, x, y, z)
                return
            }

            Sensor.TYPE_LINEAR_ACCELERATION -> {
                // 3. linear 원본 수신 간격 통계
                val intervalNs = updateIntervalStats(linearStats, timestampNs)
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

                // linear timestamp를 256Hz 생성의 기준 시계로 사용한다.
                processLinearEvent(timestampNs, x, y, z)
            }
        }
    }

    // -------------------------------------------------------------------------
    // 3. SensorEvent.timestamp 기준으로 센서별 수신 간격 통계 계산
    // -------------------------------------------------------------------------
    private fun updateIntervalStats(
        stats: IntervalStats,
        timestampNs: Long,
    ): Long {
        stats.count++ // 해당 센서 원본 총개수 +1

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

        // 다음 원본과의 차이를 계산하기 위해 이번 timestamp를 보관한다.
        stats.previousTimestampNs = timestampNs
        return intervalNs
    }

    // -------------------------------------------------------------------------
    // 4. FASTEST 원본값을 256Hz 등간격으로 선형 보간
    // -------------------------------------------------------------------------
    private fun processLinearEvent(
        timestampNs: Long,
        x: Float,
        y: Float,
        z: Float,
    ) {
        if (linearPoints.currentTimestampNs == 0L) {
            // 첫 linear 원본은 보간 구간이 없으므로 시작점만 정한다.
            linearPoints.push(timestampNs, x, y, z)
            nextTargetTimestampNs = timestampNs
            return
        }

        // 기존 linear 현재점이 직전점이 되고 이번 원본이 현재점이 된다.
        linearPoints.push(timestampNs, x, y, z)

        // 현재 실제 timestamp까지 필요한 256Hz 목표점을 모두 생성한다.
        while (nextTargetTimestampNs <= timestampNs) {
            val linear =
                linearPoints.interpolate(nextTargetTimestampNs)
            val raw =
                rawPoints.interpolate(nextTargetTimestampNs)
            val gravity =
                gravityPoints.interpolate(nextTargetTimestampNs)

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

            // 다음 목표 시각은 항상 3,906,250ns 뒤다.
            nextTargetTimestampNs += targetIntervalNs
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {
        // 이 핵심 검증에서는 정확도 변경 이벤트를 사용하지 않는다.
    }
}
