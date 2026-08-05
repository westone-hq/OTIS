package com.otis.vibration_checker

import android.content.Context
import android.util.Log
import java.io.BufferedWriter
import java.io.File
import java.io.FileWriter

/**
 * 보간 전 센서 이벤트를 줄 단위로 기록한다.
 * columns: type tsUs x_mg y_mg z_mg dtUs
 */
class NativeDumpWriter(
    private val context: Context,
    private val tag: String,
    private val requestLabel: String,
) {
    companion object {
        private const val MPS2_TO_MG = 101.97162129779283
    }

    private var file: File? = null
    private var writer: BufferedWriter? = null
    private var lastAccelNs = 0L
    private var lastGravityNs = 0L
    private var lastLinearNs = 0L
    var accelCount = 0
        private set
    var gravityCount = 0
        private set
    var linearCount = 0
        private set

    fun open() {
        close()
        lastClosedPath = null
        try {
            val f = File(
                context.cacheDir,
                "otis_${tag}_${System.currentTimeMillis()}.txt",
            )
            val w = BufferedWriter(FileWriter(f))
            w.write("# OTIS native dump · $requestLabel\n")
            w.write("# columns: type tsUs x_mg y_mg z_mg dtUs\n")
            w.write("# type: raw | gravity | linear\n")
            w.write("# raw = TYPE_ACCELEROMETER (rawX/Y/Z, 중력 포함)\n")
            w.flush()
            file = f
            writer = w
            lastAccelNs = 0L
            lastGravityNs = 0L
            lastLinearNs = 0L
            accelCount = 0
            gravityCount = 0
            linearCount = 0
        } catch (e: Exception) {
            Log.e(tag, "Failed to open native dump", e)
            file = null
            writer = null
        }
    }

    fun append(type: String, timestampNs: Long, x: Float, y: Float, z: Float) {
        val w = writer ?: return
        val prevNs = when (type) {
            "raw" -> lastAccelNs
            "gravity" -> lastGravityNs
            else -> lastLinearNs
        }
        val dtUs = if (prevNs > 0L && timestampNs > prevNs) {
            (timestampNs - prevNs) / 1000L
        } else {
            0L
        }
        when (type) {
            "raw" -> {
                lastAccelNs = timestampNs
                accelCount++
            }
            "gravity" -> {
                lastGravityNs = timestampNs
                gravityCount++
            }
            else -> {
                lastLinearNs = timestampNs
                linearCount++
            }
        }
        try {
            w.write(
                "$type ${timestampNs / 1000L} " +
                    "${x * MPS2_TO_MG} ${y * MPS2_TO_MG} ${z * MPS2_TO_MG} $dtUs\n",
            )
        } catch (e: Exception) {
            Log.e(tag, "Failed to append native event", e)
        }
    }

    /** 마지막으로 close된 파일 경로 (중복 stop/onCancel 대비) */
    private var lastClosedPath: String? = null

    fun close(): String? {
        try {
            writer?.flush()
            writer?.close()
        } catch (_: Exception) {
        }
        writer = null
        val path = file?.absolutePath
        file = null
        if (!path.isNullOrEmpty()) {
            lastClosedPath = path
        }
        return lastClosedPath
    }
}
