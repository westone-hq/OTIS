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
 *
 * 일반 [Fastest256Core]와 비교할 핵심은 센서 요청 속도가 아니라 콜백 처리 스레드다.
 * 이 파일은 FASTEST 등록·통계·256Hz 보간을 모두 전용 HandlerThread에서 실행한다.
 *
 * 읽는 순서:
 * [start] HandlerThread 생성 및 센서 등록 → [onSensorChanged] 원본 분류
 * → [updateStats] 실측 간격 계산 → [processLinear] 256Hz 선형 보간 → [stop] 스레드 종료.
 */
class HandlerThread256Core(
    context: Context,
    /** 전용 센서 스레드에서 원본 한 건을 받을 때 실행된다. */
    private val onOriginal: (OriginalSample) -> Unit,
    /** 전용 센서 스레드에서 256Hz 보간 한 건을 만들 때 실행된다. */
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

    /** 같은 256Hz 목표 시각에 정렬한 linear·raw·gravity 결과다. */
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

    /** 각 센서의 실제 수신 개수·평균/최소/최대 간격·실측 Hz를 계산한다. */
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

    /** 보간에 필요한 센서별 직전점과 현재점이다. */
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
                // 첫 점은 보간할 이전점이 없으므로 양쪽에 같은 값을 저장한다.
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
            // 역순 또는 중복 timestamp는 무시한다.
            if (timestampNs <= currentTimestampNs) return
            // 기존 현재점은 이전점으로, 새 센서값은 현재점으로 이동한다.
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
            // 목표 시각이 두 원본점 사이에서 차지하는 비율이다.
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

    // 측정을 다시 시작할 때 새 객체로 교체하므로 이전 측정값이 섞이지 않는다.
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
    /** onSensorChanged가 실제로 실행될 전용 백그라운드 스레드다. */
    private var sensorThread: HandlerThread? = null
    private var running = false

    fun start(): Boolean {
        // 중복 리스너와 남은 스레드를 제거한 뒤 새 측정을 시작한다.
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

        // Looper를 가진 센서 전용 스레드를 만들고 Handler로 콜백 목적지를 지정한다.
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
        // 먼저 센서 콜백을 막고, 큐에 남은 작업을 안전하게 처리한 뒤 스레드를 끝낸다.
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
                // raw 원본의 간격을 기록하고 보간용 최근점도 갱신한다.
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
                // gravity 원본의 간격을 기록하고 보간용 최근점도 갱신한다.
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
                // linear 이벤트가 256Hz 목표 시계를 진행시키는 기준이 된다.
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
        // 벽시계가 아닌 센서 하드웨어 timestamp 차이로 실제 수신 간격을 구한다.
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
            // 첫 linear 원본에서는 시작 시각만 정하고 두 번째 값부터 보간한다.
            linearPoints.push(timestampNs, x, y, z)
            nextTargetTimestampNs = timestampNs
            return
        }
        linearPoints.push(timestampNs, x, y, z)

        while (nextTargetTimestampNs <= timestampNs) {
            // 같은 목표 시각으로 세 센서를 맞춘 후 외부 Writer에 전달한다.
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
            // 1초 / 256 = 3,906,250ns만큼 목표 시각을 전진시킨다.
            nextTargetTimestampNs += targetIntervalNs
        }
    }

    // 이번 수신 속도 검증에서는 정확도 등급 변경을 사용하지 않는다.
    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
}
