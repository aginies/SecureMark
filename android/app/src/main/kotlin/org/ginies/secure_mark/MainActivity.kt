package org.ginies.secure_mark

import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.core.view.WindowCompat // Import for WindowCompat
import android.os.Bundle // Import for Bundle
import java.io.File // Added import
import java.io.FileOutputStream // Added import
import java.io.InputStream // Added import

class MainActivity : FlutterActivity() {
    private val CHANNEL = "secure_mark/sharing"
    private var sharedFiles: List<String> = listOf()
    private var methodChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        // Enable edge-to-edge display
        WindowCompat.setDecorFitsSystemWindows(window, false)
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFiles" -> {
                    Log.d("SecureMark", "Flutter requested shared files: ${sharedFiles.size} files")
                    val filesToReturn = sharedFiles
                    result.success(filesToReturn)
                    // Clear after returning so we don't return the same files again
                    sharedFiles = listOf()
                }
                "clearSharedFiles" -> {
                    Log.d("SecureMark", "Clearing shared files")
                    sharedFiles = listOf()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }

        Log.d("SecureMark", "Flutter engine configured, method channel ready")
        // Process any pending intent - but wait a bit for Flutter to be ready
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            handleSharedIntent(intent)
        }, 500)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleSharedIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        handleSharedIntent(intent)
    }

    private fun handleSharedIntent(intent: Intent?) {
        if (intent == null) {
            Log.d("SecureMark", "Intent is null")
            return
        }

        // Don't process intents from history
        if ((intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) {
            Log.d("SecureMark", "Ignoring intent from history")
            return
        }

        val action = intent.action
        if (action == null) {
            Log.d("SecureMark", "Intent action is null (already processed)")
            return
        }

        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) {
            Log.d("SecureMark", "Intent action not relevant: $action")
            return
        }

        Log.d("SecureMark", "Processing share intent: $action")

        val files = mutableListOf<String>()

        if (Intent.ACTION_SEND == action) {
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            Log.d("SecureMark", "Received single URI: $uri")
            uri?.let {
                val path = getRealPathFromUri(it)
                if (path != null) {
                    Log.d("SecureMark", "Converted URI to path: $path")
                    files.add(path)
                } else {
                    Log.e("SecureMark", "Failed to convert URI to path: $it")
                }
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            Log.d("SecureMark", "Received ${uris?.size ?: 0} URIs")
            uris?.forEach { uri ->
                val path = getRealPathFromUri(uri)
                if (path != null) {
                    Log.d("SecureMark", "Converted URI to path: $path")
                    files.add(path)
                } else {
                    Log.e("SecureMark", "Failed to convert URI to path: $uri")
                }
            }
        }

        if (files.isNotEmpty()) {
            Log.d("SecureMark", "Successfully processed ${files.size} shared files")
            sharedFiles = files
            // Clear the intent action so we don't process it again
            intent.action = null

            // Notify Flutter that new files are available (with retry)
            notifyFlutter(files.size, 0)
        } else {
            Log.w("SecureMark", "No files extracted from share intent")
        }
    }

    private fun notifyFlutter(fileCount: Int, retryCount: Int) {
        if (methodChannel != null) {
            Log.d("SecureMark", "Notifying Flutter: $fileCount files ready")
            try {
                methodChannel?.invokeMethod("onSharedFilesReceived", fileCount)
            } catch (e: Exception) {
                Log.e("SecureMark", "Error notifying Flutter", e)
                if (retryCount < 3) {
                    Log.d("SecureMark", "Retrying notification in 500ms...")
                    android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                        notifyFlutter(fileCount, retryCount + 1)
                    }, 500)
                }
            }
        } else {
            Log.w("SecureMark", "Method channel not ready, retrying...")
            if (retryCount < 5) {
                android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
                    notifyFlutter(fileCount, retryCount + 1)
                }, 500)
            } else {
                Log.e("SecureMark", "Failed to notify Flutter after 5 retries")
            }
        }
    }

    private fun getRealPathFromUri(uri: Uri): String? {
        return try {
            Log.d("SecureMark", "getRealPathFromUri: scheme=${uri.scheme}, uri=$uri")
            when (uri.scheme) {
                "file" -> {
                    Log.d("SecureMark", "File URI, returning path: ${uri.path}")
                    uri.path
                }
                "content" -> {
                    Log.d("SecureMark", "Content URI, copying to cache...")
                    copyUriToCache(uri)
                }
                else -> {
                    Log.e("SecureMark", "Unknown URI scheme: ${uri.scheme}")
                    null
                }
            }
        } catch (e: Exception) {
            Log.e("SecureMark", "Error in getRealPathFromUri", e)
            e.printStackTrace()
            null
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val contentResolver = contentResolver

            // Try to get original file name to preserve extension
            var fileName = "shared_${System.currentTimeMillis()}.tmp"
            var mimeType: String? = null

            contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (cursor.moveToFirst()) {
                    val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                    if (nameIndex != -1) {
                        val originalName = cursor.getString(nameIndex)
                        Log.d("SecureMark", "Original file name: $originalName")
                        fileName = "shared_${System.currentTimeMillis()}_${originalName}"
                    }
                }
            }

            // Get MIME type
            mimeType = contentResolver.getType(uri)
            Log.d("SecureMark", "MIME type: $mimeType")

            // If we still don't have an extension, try to infer from MIME type
            if (!fileName.contains('.') && mimeType != null) {
                val extension = when {
                    mimeType.startsWith("image/jpeg") -> ".jpg"
                    mimeType.startsWith("image/png") -> ".png"
                    mimeType.startsWith("image/webp") -> ".webp"
                    mimeType.startsWith("image/heic") -> ".heic"
                    mimeType.startsWith("image/heif") -> ".heif"
                    mimeType == "application/pdf" -> ".pdf"
                    else -> ""
                }
                if (extension.isNotEmpty()) {
                    fileName += extension
                    Log.d("SecureMark", "Added extension from MIME type: $extension")
                }
            }

            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val cacheFile = File(cacheDir, fileName)
                Log.d("SecureMark", "Copying to cache: ${cacheFile.absolutePath}")

                val outputStream = FileOutputStream(cacheFile)

                val bytesWritten = inputStream.copyTo(outputStream)
                inputStream.close()
                outputStream.close()

                Log.d("SecureMark", "Successfully copied $bytesWritten bytes to cache")
                cacheFile.absolutePath
            } else {
                Log.e("SecureMark", "Failed to open input stream for URI: $uri")
                null
            }
        } catch (e: Exception) {
            Log.e("SecureMark", "Error copying URI to cache", e)
            e.printStackTrace()
            null
        }
    }
}
