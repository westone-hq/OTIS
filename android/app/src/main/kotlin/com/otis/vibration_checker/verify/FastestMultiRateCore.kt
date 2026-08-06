package com.otis.vibration_checker.verify

/**
 * 기본 FASTEST 원본 하나에서 256Hz·128Hz·64Hz를 각각 독립적으로 선형 보간한다.
 *
 * 센서를 다시 등록하지 않고 [Fastest256Core]가 받은 원본을 [accept]로 전달받는다.
 * 각 Hz는 자기 목표 시각(nextTargetNs)을 따로 가지므로 단순 행 건너뛰기가 아니다.
 */
class FastestMultiRateCore(
    private val onResampled: (rateHz: Int, sample: ResampledSample) -> Unit,
) {
    companion object {
        val TARGET_RATES_HZ = intArrayOf(256, 128, 64)
        private const val ONE_SECOND_NS = 1_000_000_000L
    }

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

    private data class PointPair(
        var previousTimestampNs: Long = 0L,
        var previousX: Float = 0f,
        var previousY: Float = 0f,
        var previousZ: Float = 0f,
        var currentTimestampNs: Long = 0L,
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

    private data class RateClock(
        val rateHz: Int,
        val intervalNs: Long,
        var nextTargetNs: Long = 0L,
    )

    private val rawPoints = PointPair()
    private val gravityPoints = PointPair()
    private val linearPoints = PointPair()
    private val clocks =
        TARGET_RATES_HZ.map { rate ->
            RateClock(
                rateHz = rate,
                intervalNs = ONE_SECOND_NS / rate,
            )
        }

    /** 일반 FASTEST 리스너가 받은 원본을 센서 타입별로 전달받는다. */
    fun accept(original: Fastest256Core.OriginalSample) {
        when (original.kind) {
            Fastest256Core.SensorKind.RAW -> {
                rawPoints.push(
                    original.timestampNs,
                    original.x,
                    original.y,
                    original.z,
                )
            }
            Fastest256Core.SensorKind.GRAVITY -> {
                gravityPoints.push(
                    original.timestampNs,
                    original.x,
                    original.y,
                    original.z,
                )
            }
            Fastest256Core.SensorKind.LINEAR -> {
                processLinear(original)
            }
        }
    }

    private fun processLinear(original: Fastest256Core.OriginalSample) {
        val timestampNs = original.timestampNs
        if (linearPoints.currentTimestampNs == 0L) {
            linearPoints.push(timestampNs, original.x, original.y, original.z)
            // 세 보간 시계가 같은 첫 원본 시각에서 출발한다.
            for (clock in clocks) clock.nextTargetNs = timestampNs
            return
        }

        linearPoints.push(timestampNs, original.x, original.y, original.z)

        // 각 Hz가 서로 독립적인 목표 시각을 사용해 원본 사이를 보간한다.
        for (clock in clocks) {
            while (clock.nextTargetNs <= timestampNs) {
                val linear = linearPoints.interpolate(clock.nextTargetNs)
                val raw = rawPoints.interpolate(clock.nextTargetNs)
                val gravity = gravityPoints.interpolate(clock.nextTargetNs)
                onResampled(
                    clock.rateHz,
                    ResampledSample(
                        timestampNs = clock.nextTargetNs,
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
                clock.nextTargetNs += clock.intervalNs
            }
        }
    }
}
