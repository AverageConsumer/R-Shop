package com.retro.rshop

import android.util.Log
import com.hierynomus.msdtyp.AccessMask
import com.hierynomus.msfscc.FileAttributes
import com.hierynomus.msfscc.fileinformation.FileIdBothDirectoryInformation
import com.hierynomus.mssmb2.SMB2CreateDisposition
import com.hierynomus.mssmb2.SMB2CreateOptions
import com.hierynomus.mssmb2.SMB2ShareAccess
import com.hierynomus.mssmb2.SMBApiException
import com.hierynomus.protocol.transport.TransportException
import com.hierynomus.smbj.SMBClient
import com.hierynomus.smbj.SmbConfig
import com.hierynomus.smbj.auth.AuthenticationContext
import com.hierynomus.smbj.session.Session
import com.hierynomus.smbj.share.DiskShare
import io.flutter.plugin.common.EventChannel
import java.io.BufferedOutputStream
import java.io.File
import java.io.FileOutputStream
import java.net.ConnectException
import java.util.EnumSet
import java.util.concurrent.ConcurrentHashMap
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicBoolean

class SmbService {
    companion object {
        private const val TAG = "SmbService"
        private const val READ_BUFFER_SIZE = 1_048_576 // 1MB
        private const val WRITE_BUFFER_SIZE = 1_048_576 // 1MB
        private const val CONNECT_TIMEOUT_SECONDS = 30L
        private const val READ_TIMEOUT_SECONDS = 60L
        private const val INACTIVITY_TIMEOUT_MS = 60_000L
    }

    internal val smbPool = Executors.newFixedThreadPool(2)
    private val cancelFlags = ConcurrentHashMap<String, AtomicBoolean>()

    private fun buildClient(): SMBClient {
        val config = SmbConfig.builder()
            .withTimeout(CONNECT_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .withSoTimeout(READ_TIMEOUT_SECONDS, TimeUnit.SECONDS)
            .withReadBufferSize(READ_BUFFER_SIZE)
            .withWriteBufferSize(WRITE_BUFFER_SIZE)
            .withMultiProtocolNegotiate(true)
            .build()
        return SMBClient(config)
    }

    private fun buildAuth(user: String, pass: String, domain: String): AuthenticationContext {
        return if (user.isEmpty() || user == "guest") {
            AuthenticationContext.guest()
        } else {
            AuthenticationContext(user, pass.toCharArray(), domain)
        }
    }

    fun testConnection(args: Map<*, *>): Map<String, Any?> {
        val host = args["host"] as? String ?: return mapOf("success" to false, "error" to "Host is required")
        val port = (args["port"] as? Number)?.toInt() ?: 445
        val share = args["share"] as? String ?: return mapOf("success" to false, "error" to "Share is required")
        val path = args["path"] as? String ?: ""
        val user = args["user"] as? String ?: "guest"
        val pass = args["pass"] as? String ?: ""
        val domain = args["domain"] as? String ?: ""

        var client: SMBClient? = null
        try {
            client = buildClient()
            val connection = client.connect(host, port)
            val auth = buildAuth(user, pass, domain)
            val session = connection.authenticate(auth)
            val diskShare = session.connectShare(share) as DiskShare

            // Verify we can list the path
            val listPath = if (path.isEmpty() || path == "/") "" else path.trimStart('/')
            diskShare.list(listPath)

            diskShare.close()
            session.close()
            connection.close()

            return mapOf("success" to true)
        } catch (e: Exception) {
            return mapOf("success" to false, "error" to mapError(e))
        } finally {
            try { client?.close() } catch (e: Exception) {
                Log.d(TAG, "Client close error: ${e.message}")
            }
        }
    }

    fun listFiles(args: Map<*, *>): List<Map<String, Any?>> {
        val host = args["host"] as? String ?: throw IllegalArgumentException("Host is required")
        val port = (args["port"] as? Number)?.toInt() ?: 445
        val share = args["share"] as? String ?: throw IllegalArgumentException("Share is required")
        val path = args["path"] as? String ?: ""
        val user = args["user"] as? String ?: "guest"
        val pass = args["pass"] as? String ?: ""
        val domain = args["domain"] as? String ?: ""
        // Backward compat: scanSubdirs: true → maxDepth 1
        val maxDepth = (args["maxDepth"] as? Number)?.toInt()
            ?: if (args["scanSubdirs"] as? Boolean == true) 1 else 0

        var client: SMBClient? = null
        try {
            client = buildClient()
            val connection = client.connect(host, port)
            val auth = buildAuth(user, pass, domain)
            val session = connection.authenticate(auth)
            val diskShare = session.connectShare(share) as DiskShare

            val listPath = if (path.isEmpty() || path == "/") "" else path.trimStart('/')
            val results = mutableListOf<Map<String, Any?>>()

            scanDirectory(diskShare, listPath, null, maxDepth, 0, results)

            diskShare.close()
            session.close()
            connection.close()

            return results
        } catch (e: Exception) {
            throw Exception(mapError(e))
        } finally {
            try { client?.close() } catch (e: Exception) {
                Log.d(TAG, "Client close error: ${e.message}")
            }
        }
    }

    private fun scanDirectory(
        share: DiskShare,
        absolutePath: String,
        parentPath: String?,
        maxDepth: Int,
        currentDepth: Int,
        results: MutableList<Map<String, Any?>>
    ) {
        val entries = share.list(absolutePath)
        for (entry in entries) {
            val name = entry.fileName
            if (name == "." || name == "..") continue

            val isDir = isDirectory(entry)
            val entryPath = if (absolutePath.isEmpty()) name else "$absolutePath/$name"

            results.add(buildMap {
                put("name", name)
                put("path", entryPath)
                put("isDirectory", isDir)
                put("size", entry.endOfFile)
                if (parentPath != null) put("parentPath", parentPath)
            })

            if (isDir && !name.startsWith(".") && currentDepth < maxDepth) {
                try {
                    // relativePath from scan root for this subdirectory
                    val childParentPath = if (parentPath != null) "$parentPath/$name" else name
                    scanDirectory(share, entryPath, childParentPath, maxDepth, currentDepth + 1, results)
                } catch (e: Exception) {
                    Log.d(TAG, "Failed to scan subdirectory $entryPath: ${e.message}")
                }
            }
        }
    }

    fun startDownload(
        args: Map<*, *>,
        progressSink: EventChannel.EventSink?,
        mainHandler: android.os.Handler
    ) {
        val downloadId = args["downloadId"] as? String ?: throw IllegalArgumentException("downloadId is required")
        val host = args["host"] as? String ?: throw IllegalArgumentException("Host is required")
        val port = (args["port"] as? Number)?.toInt() ?: 445
        val share = args["share"] as? String ?: throw IllegalArgumentException("Share is required")
        val filePath = args["filePath"] as? String ?: throw IllegalArgumentException("filePath is required")
        val outputPath = args["outputPath"] as? String ?: throw IllegalArgumentException("outputPath is required")
        val user = args["user"] as? String ?: "guest"
        val pass = args["pass"] as? String ?: ""
        val domain = args["domain"] as? String ?: ""

        val cancelFlag = AtomicBoolean(false)
        cancelFlags[downloadId] = cancelFlag

        smbPool.execute {
            var client: SMBClient? = null
            try {
                client = buildClient()
                val connection = client.connect(host, port)
                val auth = buildAuth(user, pass, domain)
                val session = connection.authenticate(auth)
                val diskShare = session.connectShare(share) as DiskShare

                val cleanPath = filePath.trimStart('/')
                val fileInfo = diskShare.getFileInformation(cleanPath)
                val totalBytes = fileInfo.standardInformation.endOfFile

                val file = diskShare.openFile(
                    cleanPath,
                    EnumSet.of(AccessMask.GENERIC_READ),
                    EnumSet.of(FileAttributes.FILE_ATTRIBUTE_NORMAL),
                    EnumSet.of(SMB2ShareAccess.FILE_SHARE_READ),
                    SMB2CreateDisposition.FILE_OPEN,
                    EnumSet.of(SMB2CreateOptions.FILE_NON_DIRECTORY_FILE)
                )

                val outputFile = File(outputPath)
                outputFile.parentFile?.mkdirs()

                val buffer = ByteArray(READ_BUFFER_SIZE)
                var bytesWritten = 0L
                var lastProgressTime = System.currentTimeMillis()
                var lastDataTime = System.currentTimeMillis()

                BufferedOutputStream(FileOutputStream(outputFile), WRITE_BUFFER_SIZE).use { bos ->
                    file.inputStream.use { fis ->
                        while (!cancelFlag.get()) {
                            // Check inactivity timeout
                            val now = System.currentTimeMillis()
                            if (now - lastDataTime > INACTIVITY_TIMEOUT_MS) {
                                throw Exception("Download stalled - no data received for 60 seconds")
                            }

                            val bytesRead = fis.read(buffer)
                            if (bytesRead <= 0) break // EOF

                            bos.write(buffer, 0, bytesRead)
                            bytesWritten += bytesRead
                            lastDataTime = System.currentTimeMillis()

                            // Throttle progress reports to ~500ms
                            if (System.currentTimeMillis() - lastProgressTime >= 500) {
                                lastProgressTime = System.currentTimeMillis()
                                sendProgress(progressSink, mainHandler, downloadId, bytesWritten, totalBytes, "progress")
                            }
                        }
                    }
                }

                file.close()
                diskShare.close()
                session.close()
                connection.close()

                if (cancelFlag.get()) {
                    // Clean up incomplete file on cancel
                    try { File(outputPath).delete() } catch (e: Exception) {
                        Log.d(TAG, "Cancel cleanup failed: ${e.message}")
                    }
                    sendProgress(progressSink, mainHandler, downloadId, bytesWritten, totalBytes, "cancelled")
                } else {
                    sendProgress(progressSink, mainHandler, downloadId, bytesWritten, totalBytes, "complete")
                }
            } catch (e: Exception) {
                Log.e(TAG, "Download error for $downloadId: ${e.message}")
                // Clean up incomplete file on error
                try { File(outputPath).delete() } catch (cleanupEx: Exception) {
                    Log.d(TAG, "Error cleanup failed: ${cleanupEx.message}")
                }
                mainHandler.post {
                    progressSink?.success(mapOf(
                        "downloadId" to downloadId,
                        "bytesWritten" to 0L,
                        "totalBytes" to 0L,
                        "status" to "error",
                        "error" to mapError(e)
                    ))
                }
            } finally {
                cancelFlags.remove(downloadId)
                try { client?.close() } catch (e: Exception) {
                    Log.d(TAG, "Client close error: ${e.message}")
                }
            }
        }
    }

    fun cancelDownload(downloadId: String) {
        cancelFlags[downloadId]?.set(true)
    }

    fun shutdown() {
        // Cancel all active downloads
        cancelFlags.values.forEach { it.set(true) }
        cancelFlags.clear()
        smbPool.shutdown()
        try {
            if (!smbPool.awaitTermination(5, TimeUnit.SECONDS)) {
                smbPool.shutdownNow()
            }
        } catch (e: InterruptedException) {
            smbPool.shutdownNow()
        }
    }

    private fun sendProgress(
        sink: EventChannel.EventSink?,
        handler: android.os.Handler,
        downloadId: String,
        bytesWritten: Long,
        totalBytes: Long,
        status: String
    ) {
        handler.post {
            sink?.success(mapOf(
                "downloadId" to downloadId,
                "bytesWritten" to bytesWritten,
                "totalBytes" to totalBytes,
                "status" to status
            ))
        }
    }

    private fun isDirectory(entry: FileIdBothDirectoryInformation): Boolean {
        return (entry.fileAttributes and FileAttributes.FILE_ATTRIBUTE_DIRECTORY.value) != 0L
    }

    private fun mapError(e: Exception): String {
        return when {
            e is SMBApiException && e.status.toString().contains("ACCESS_DENIED") ->
                "Access denied. Check your username and password."
            e is SMBApiException && e.status.toString().contains("BAD_NETWORK_NAME") ->
                "Share not found. Check the share name."
            e is SMBApiException && e.status.toString().contains("LOGON_FAILURE") ->
                "Authentication failed. Check your credentials."
            e is SMBApiException && e.status.toString().contains("OBJECT_NAME_NOT_FOUND") ->
                "Path not found on the server."
            e is SMBApiException ->
                "SMB error: ${e.statusCode} - ${e.message}"
            e is TransportException ->
                "Server not reachable. Check host and port."
            e is ConnectException ->
                "Cannot connect to server. Check host and port."
            e.message?.contains("timeout", ignoreCase = true) == true ->
                "Connection timeout after ${CONNECT_TIMEOUT_SECONDS} seconds."
            e.message?.contains("stalled", ignoreCase = true) == true ->
                e.message ?: "Download stalled."
            else -> e.message ?: "Unknown SMB error"
        }
    }
}
