package com.otis.vibration_checker.verify

import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter
import java.util.Locale
import kotlin.math.floor
import kotlin.math.roundToLong

/**
 * FASTEST 원본 txt를 50배·100배로 촘촘하게 만드는 가상 선형 보간 코드.
 *
 * 입력 형식:
 * `type tsUs dtUs x_mg y_mg z_mg`
 *
 * 출력 주파수:
 * - 50배: 256 × 50 = 12,800Hz, 약 78.125us 간격
 * - 100배: 256 × 100 = 25,600Hz, 약 39.0625us 간격
 *
 * 실제 센서 수신률을 높이는 코드가 아니다. 측정된 두 원본점 사이를 직선으로 채우는
 * 그래프 확대·확인용 결과이며 거리·속도·진동 계산에는 사용하지 않는다.
 */
object FastestDenseInterpolation {
    const val RATE_50X_HZ = 256 * 50
    const val RATE_100X_HZ = 256 * 100
    private const val MAX_OUTPUT_ROWS = 2_000_000

    private data class SensorPoint(
        val timestampUs: Long,
        val xMg: Double,
        val yMg: Double,
        val zMg: Double,
    )

    private data class Vector3(
        val x: Double,
        val y: Double,
        val z: Double,
    )

    /**
     * FASTEST 원본 본문 하나에서 50배·100배 파일을 모두 만든다.
     * 두 파일 중 하나라도 실패하면 생성 중인 두 파일을 삭제하고 false를 반환한다.
     */
    fun generate(
        fastestOriginalBody: File,
        output50x: File,
        output100x: File,
    ): Boolean {
        return try {
            val points = readOriginalPoints(fastestOriginalBody)
            writeDenseFile(points, RATE_50X_HZ, "FASTEST 원본 50배 가상 보간", output50x)
            writeDenseFile(points, RATE_100X_HZ, "FASTEST 원본 100배 가상 보간", output100x)
            true
        } catch (_: Exception) {
            output50x.delete()
            output100x.delete()
            false
        }
    }

    /** 원본 txt를 raw·gravity·linear 센서별 시간순 목록으로 읽는다. */
    private fun readOriginalPoints(source: File): Map<String, List<SensorPoint>> {
        val grouped: LinkedHashMap<String, MutableList<SensorPoint>> =
            linkedMapOf(
                "raw" to mutableListOf<SensorPoint>(),
                "gravity" to mutableListOf<SensorPoint>(),
                "linear" to mutableListOf<SensorPoint>(),
            )

        source.forEachLine { line ->
            val parts = line.trim().split(Regex("\\s+"))
            if (parts.size < 6) return@forEachLine
            val type = parts[0]
            val target = grouped[type] ?: return@forEachLine
            val timestampUs = parts[1].toLongOrNull() ?: return@forEachLine
            // parts[2]는 원본 수신 간격 dtUs이므로 좌표 계산에서는 사용하지 않는다.
            val xMg = parts[3].toDoubleOrNull() ?: return@forEachLine
            val yMg = parts[4].toDoubleOrNull() ?: return@forEachLine
            val zMg = parts[5].toDoubleOrNull() ?: return@forEachLine
            target.add(SensorPoint(timestampUs, xMg, yMg, zMg))
        }

        for (series in grouped.values) {
            series.sortBy { it.timestampUs }
        }
        return grouped
    }

    /** 목표 주파수의 등간격 timestamp를 만들고 세 센서를 같은 시각으로 보간한다. */
    private fun writeDenseFile(
        points: Map<String, List<SensorPoint>>,
        targetHz: Int,
        label: String,
        output: File,
    ) {
        val raw = points["raw"].orEmpty()
        val gravity = points["gravity"].orEmpty()
        val linear = points["linear"].orEmpty()
        val allFirst = listOfNotNull(raw.firstOrNull(), gravity.firstOrNull(), linear.firstOrNull())
        val allLast = listOfNotNull(raw.lastOrNull(), gravity.lastOrNull(), linear.lastOrNull())

        BufferedWriter(FileWriter(output)).use { writer ->
            writeHeader(writer, label, targetHz)
            if (allFirst.isEmpty() || allLast.isEmpty()) return

            val startUs = allFirst.minOf { it.timestampUs }
            val endUs = allLast.maxOf { it.timestampUs }
            if (endUs <= startUs) return

            val periodUs = 1_000_000.0 / targetHz
            val requestedCount = floor((endUs - startUs) / periodUs).toLong() + 1L
            val safeCount = requestedCount.coerceIn(1L, MAX_OUTPUT_ROWS.toLong())

            for (index in 0L until safeCount) {
                val targetUs = startUs + (index * periodUs).roundToLong()
                if (targetUs > endUs) break
                val elapsedSec = (targetUs - startUs) / 1_000_000.0
                val rawValue = interpolateAt(raw, targetUs)
                val gravityValue = interpolateAt(gravity, targetUs)
                val linearValue = interpolateAt(linear, targetUs)
                writer.write(
                    String.format(
                        Locale.US,
                        "%.9f,%s,%s,%s,%s,%s,%s,%s,%s,%s%n",
                        elapsedSec,
                        format(rawValue?.x),
                        format(rawValue?.y),
                        format(rawValue?.z),
                        format(gravityValue?.x),
                        format(gravityValue?.y),
                        format(gravityValue?.z),
                        format(linearValue?.x),
                        format(linearValue?.y),
                        format(linearValue?.z),
                    ),
                )
            }
        }
    }

    private fun writeHeader(
        writer: BufferedWriter,
        label: String,
        targetHz: Int,
    ) {
        writer.write("# $label\n")
        writer.write("# INTERPOLATED / VISUALIZATION ONLY / NOT MEASURED SAMPLE\n")
        writer.write("# source: FASTEST_원본.txt\n")
        writer.write("# method: linear interpolation between original sensor events\n")
        writer.write("# target_rate_hz: $targetHz\n")
        writer.write("# 실제 센서 측정값이 아니라 그래프 확대 확인용 가상 보간 데이터\n")
        writer.write(
            "t_sec,raw_x_mg,raw_y_mg,raw_z_mg," +
                "gravity_x_mg,gravity_y_mg,gravity_z_mg," +
                "linear_x_mg,linear_y_mg,linear_z_mg\n",
        )
    }

    /** targetUs 앞뒤의 실제 원본 두 점을 찾아 선형 보간한다. */
    private fun interpolateAt(
        series: List<SensorPoint>,
        targetUs: Long,
    ): Vector3? {
        if (series.isEmpty()) return null
        if (targetUs <= series.first().timestampUs) {
            val point = series.first()
            return Vector3(point.xMg, point.yMg, point.zMg)
        }
        if (targetUs >= series.last().timestampUs) {
            val point = series.last()
            return Vector3(point.xMg, point.yMg, point.zMg)
        }

        var leftIndex = 0
        var rightIndex = series.lastIndex
        while (leftIndex + 1 < rightIndex) {
            val middleIndex = (leftIndex + rightIndex) ushr 1
            if (series[middleIndex].timestampUs <= targetUs) {
                leftIndex = middleIndex
            } else {
                rightIndex = middleIndex
            }
        }

        val left = series[leftIndex]
        val right = series[rightIndex]
        val sourceIntervalUs = right.timestampUs - left.timestampUs
        if (sourceIntervalUs <= 0L) {
            return Vector3(left.xMg, left.yMg, left.zMg)
        }
        val alpha =
            ((targetUs - left.timestampUs).toDouble() / sourceIntervalUs)
                .coerceIn(0.0, 1.0)
        return Vector3(
            left.xMg + alpha * (right.xMg - left.xMg),
            left.yMg + alpha * (right.yMg - left.yMg),
            left.zMg + alpha * (right.zMg - left.zMg),
        )
    }

    private fun format(value: Double?): String =
        value?.let { String.format(Locale.US, "%.9f", it) } ?: ""
}
