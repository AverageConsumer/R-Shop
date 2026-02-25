package com.retro.rshop

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.StatFs
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import java.io.*
import java.util.concurrent.Executors
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.retro.rshop/zip"
    private val STORAGE_CHANNEL = "com.retro.rshop/storage"
    private val PROGRESS_CHANNEL = "com.retro.rshop/zip_progress"
    private val TAG = "MainActivity"

    private val extractorPool = Executors.newFixedThreadPool(2)
    private val mainHandler = Handler(Looper.getMainLooper())

    private var progressSink: EventChannel.EventSink? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity onCreate")
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        EventChannel(flutterEngine.dartExecutor.binaryMessenger, PROGRESS_CHANNEL).setStreamHandler(
            object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    progressSink = events
                }
                override fun onCancel(arguments: Any?) {
                    progressSink = null
                }
            }
        )

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "extractZip" -> {
                    val zipPath = call.argument<String>("zipPath")
                    val targetPath = call.argument<String>("targetPath")

                    if (zipPath == null || targetPath == null) {
                        result.error("INVALID_ARGS", "zipPath and targetPath required", null)
                        return@setMethodCallHandler
                    }

                    extractorPool.execute {
                        try {
                            val extractedFiles = extractZip(zipPath, targetPath)
                            mainHandler.post {
                                result.success(extractedFiles)
                            }
                        } catch (e: Exception) {
                            mainHandler.post {
                                result.error("EXTRACT_ERROR", e.message, null)
                            }
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, STORAGE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getFreeSpace" -> {
                    val path = call.argument<String>("path")
                    if (path == null) {
                        result.error("INVALID_ARGS", "path required", null)
                        return@setMethodCallHandler
                    }
                    try {
                        val stat = StatFs(path)
                        val freeBytes = stat.availableBytes
                        val totalBytes = stat.totalBytes
                        result.success(mapOf("freeBytes" to freeBytes, "totalBytes" to totalBytes))
                    } catch (e: Exception) {
                        result.error("STAT_ERROR", e.message, null)
                    }
                }
                "getDeviceMemory" -> {
                    try {
                        val am = getSystemService(android.content.Context.ACTIVITY_SERVICE) as android.app.ActivityManager
                        val memInfo = android.app.ActivityManager.MemoryInfo()
                        am.getMemoryInfo(memInfo)
                        result.success(mapOf("totalBytes" to memInfo.totalMem))
                    } catch (e: Exception) {
                        result.error("MEMORY_ERROR", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        extractorPool.shutdown()
        super.onDestroy()
    }

    private fun sendProgress(extractedBytes: Long, totalBytes: Long) {
        val sink = progressSink ?: return
        if (totalBytes <= 0) return
        val percent = (extractedBytes.toDouble() / totalBytes * 100).toInt().coerceIn(0, 100)
        mainHandler.post {
            sink.success(mapOf("extracted" to extractedBytes, "total" to totalBytes, "percent" to percent))
        }
    }

    private fun extractZip(zipPath: String, targetPath: String): List<String> {
        val extractedFiles = mutableListOf<String>()
        val buffer = ByteArray(8192)
        var totalBytes = 0L
        var extractedBytes = 0L

        // Get total size for progress
        File(zipPath).inputStream().use { fis ->
            val zis = ZipInputStream(BufferedInputStream(fis))
            var entry = zis.nextEntry
            while (entry != null) {
                if (entry.size > 0) totalBytes += entry.size
                entry = zis.nextEntry
            }
            zis.close()
        }

        // Extract files
        File(zipPath).inputStream().use { fis ->
            val zis = ZipInputStream(BufferedInputStream(fis))
            var entry = zis.nextEntry

            val canonicalTarget = File(targetPath).canonicalPath
            var lastReportedPercent = -1

            while (entry != null) {
                val file = File(targetPath, entry.name)

                // Zip Slip protection: reject entries that escape the target directory
                if (!file.canonicalPath.startsWith(canonicalTarget + File.separator) &&
                    file.canonicalPath != canonicalTarget) {
                    entry = zis.nextEntry
                    continue
                }

                if (entry.isDirectory) {
                    file.mkdirs()
                } else {
                    file.parentFile?.mkdirs()

                    FileOutputStream(file).use { fos ->
                        var len: Int
                        while (zis.read(buffer).also { len = it } > 0) {
                            fos.write(buffer, 0, len)
                            extractedBytes += len
                        }
                    }

                    extractedFiles.add(entry.name)

                    // Report progress (throttle: only on percent change)
                    if (totalBytes > 0) {
                        val currentPercent = (extractedBytes.toDouble() / totalBytes * 100).toInt()
                        if (currentPercent != lastReportedPercent) {
                            lastReportedPercent = currentPercent
                            sendProgress(extractedBytes, totalBytes)
                        }
                    }
                }

                entry = zis.nextEntry
            }

            zis.close()
        }

        return extractedFiles
    }

}
