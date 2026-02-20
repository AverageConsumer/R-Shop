package com.retro.rshop

import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.util.Log
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel
import java.io.*
import java.util.zip.ZipInputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.retro.rshop/zip"
    private val TAG = "MainActivity"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        Log.d(TAG, "MainActivity onCreate")
    }

    override fun configureFlutterEngine(flutterEngine: io.flutter.embedding.engine.FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "extractZip" -> {
                    val zipPath = call.argument<String>("zipPath")
                    val targetPath = call.argument<String>("targetPath")
                    
                    if (zipPath == null || targetPath == null) {
                        result.error("INVALID_ARGS", "zipPath and targetPath required", null)
                        return@setMethodCallHandler
                    }

                    Thread {
                        try {
                            val extractedFiles = extractZip(zipPath, targetPath)
                            Handler(Looper.getMainLooper()).post {
                                result.success(extractedFiles)
                            }
                        } catch (e: Exception) {
                            Handler(Looper.getMainLooper()).post {
                                result.error("EXTRACT_ERROR", e.message, null)
                            }
                        }
                    }.start()
                }
                else -> result.notImplemented()
            }
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
                }
                
                entry = zis.nextEntry
            }
            
            zis.close()
        }

        return extractedFiles
    }

}
