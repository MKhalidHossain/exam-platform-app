package com.khalid.inspectorspath

import android.Manifest
import android.content.ContentValues
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.provider.MediaStore
import android.util.Log
import androidx.activity.result.contract.ActivityResultContracts
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.IOException
import java.net.HttpURLConnection
import java.net.URL

class MainActivity : FlutterFragmentActivity() {
    private val logTag = "PdfDownload"
    private val downloadChannelName = "com.khalid.inspectorspath/downloads"
    private val mainHandler = Handler(Looper.getMainLooper())
    private var pendingDownloadUrl: String? = null
    private var pendingDownloadFileName: String? = null
    private var pendingDownloadResult: MethodChannel.Result? = null

    private val storagePermissionLauncher =
        registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
            val result = pendingDownloadResult
            val url = pendingDownloadUrl
            val fileName = pendingDownloadFileName

            pendingDownloadResult = null
            pendingDownloadUrl = null
            pendingDownloadFileName = null

            if (result == null || url.isNullOrBlank() || fileName.isNullOrBlank()) {
                return@registerForActivityResult
            }

            if (granted) {
                downloadPdfToDownloads(url, fileName, result)
            } else {
                result.error(
                    "permission_denied",
                    "Storage permission is required to save PDFs to Downloads on this Android version.",
                    null
                )
            }
        }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, downloadChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "downloadPdfToDownloads" -> handleDownloadPdfToDownloads(call, result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun handleDownloadPdfToDownloads(call: MethodCall, result: MethodChannel.Result) {
        val url = call.argument<String>("url")?.trim().orEmpty()
        val fileName = sanitizeFileName(call.argument<String>("fileName"))

        if (url.isBlank()) {
            Log.e(logTag, "downloadPdfToDownloads failed: PDF URL is missing")
            result.error("invalid_url", "PDF URL is missing.", null)
            return
        }

        if (!isNetworkAvailable()) {
            Log.e(logTag, "downloadPdfToDownloads failed: Internet connection is not available")
            result.error("network_unavailable", "Internet connection is not available.", null)
            return
        }

        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q &&
            ContextCompat.checkSelfPermission(
                this,
                Manifest.permission.WRITE_EXTERNAL_STORAGE
            ) != PackageManager.PERMISSION_GRANTED
        ) {
            pendingDownloadUrl = url
            pendingDownloadFileName = fileName
            pendingDownloadResult = result
            storagePermissionLauncher.launch(Manifest.permission.WRITE_EXTERNAL_STORAGE)
            return
        }

        downloadPdfToDownloads(url, fileName, result)
    }

    private fun downloadPdfToDownloads(
        url: String,
        fileName: String,
        result: MethodChannel.Result
    ) {
        Thread {
            try {
                val savedPath = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    savePdfWithMediaStore(url, fileName)
                } else {
                    savePdfToLegacyDownloads(url, fileName)
                }

                mainHandler.post {
                    result.success(
                        mapOf(
                            "relativePath" to "Downloads",
                            "fileName" to "$fileName.pdf",
                            "path" to savedPath
                        )
                    )
                }
            } catch (error: Exception) {
                Log.e(logTag, "downloadPdfToDownloads failed for $url", error)
                mainHandler.post {
                    result.error(
                        "download_failed",
                        error.message ?: "Unable to save PDF to Downloads.",
                        error.stackTraceToString()
                    )
                }
            } catch (error: Error) {
                Log.e(logTag, "downloadPdfToDownloads fatal error for $url", error)
                mainHandler.post {
                    result.error(
                        "download_failed",
                        error.message ?: "Unable to save PDF to Downloads.",
                        null
                    )
                }
            }
        }.start()
    }

    private fun savePdfWithMediaStore(url: String, fileName: String): String {
        val resolver = applicationContext.contentResolver
        val fullFileName = "$fileName.pdf"
        val contentValues = ContentValues().apply {
            put(MediaStore.Downloads.DISPLAY_NAME, fullFileName)
            put(MediaStore.Downloads.MIME_TYPE, "application/pdf")
            put(MediaStore.Downloads.RELATIVE_PATH, Environment.DIRECTORY_DOWNLOADS)
            put(MediaStore.Downloads.IS_PENDING, 1)
        }

        val targetUri = resolver.insert(
            MediaStore.Downloads.EXTERNAL_CONTENT_URI,
            contentValues
        ) ?: throw IOException("Unable to create Downloads entry.")

        try {
            resolver.openOutputStream(targetUri)?.use { outputStream ->
                copyUrlToStream(url, outputStream)
            } ?: throw IOException("Unable to open Downloads output stream.")

            val completedValues = ContentValues().apply {
                put(MediaStore.Downloads.IS_PENDING, 0)
            }
            resolver.update(targetUri, completedValues, null, null)
            return "Downloads/$fullFileName"
        } catch (error: Exception) {
            resolver.delete(targetUri, null, null)
            throw error
        }
    }

    private fun savePdfToLegacyDownloads(url: String, fileName: String): String {
        val downloadsDirectory =
            Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
        if (!downloadsDirectory.exists() && !downloadsDirectory.mkdirs()) {
            throw IOException("Unable to access Downloads folder.")
        }

        val destinationFile = File(downloadsDirectory, "$fileName.pdf")
        FileOutputStream(destinationFile).use { outputStream ->
            copyUrlToStream(url, outputStream)
        }

        return destinationFile.absolutePath
    }

    private fun copyUrlToStream(url: String, outputStream: java.io.OutputStream) {
        val connection = (URL(url).openConnection() as HttpURLConnection).apply {
            requestMethod = "GET"
            connectTimeout = 15000
            readTimeout = 30000
            instanceFollowRedirects = true
            setRequestProperty("Accept", "application/pdf,*/*")
        }

        try {
            val responseCode = connection.responseCode
            if (responseCode !in 200..299) {
                throw IOException("Download failed with HTTP $responseCode.")
            }

            connection.inputStream.use { inputStream ->
                inputStream.copyTo(outputStream)
                outputStream.flush()
            }
        } finally {
            connection.disconnect()
        }
    }

    private fun isNetworkAvailable(): Boolean {
        val connectivityManager = getSystemService(ConnectivityManager::class.java)
        val network = connectivityManager?.activeNetwork ?: return false
        val capabilities = connectivityManager.getNetworkCapabilities(network) ?: return false
        return capabilities.hasCapability(android.net.NetworkCapabilities.NET_CAPABILITY_INTERNET)
    }

    private fun sanitizeFileName(rawValue: String?): String {
        val sanitized = rawValue
            ?.trim()
            ?.replace(Regex("[^A-Za-z0-9._ -]"), "")
            ?.replace(Regex("\\s+"), "_")
            .orEmpty()

        return sanitized.ifBlank { "ebook" }
    }
}
