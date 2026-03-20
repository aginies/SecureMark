package org.ginies.secure_mark

import android.content.Intent
import android.net.Uri
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.io.FileOutputStream
import java.io.InputStream

class MainActivity : FlutterActivity() {
    private val CHANNEL = "secure_mark/sharing"
    private var sharedFiles: List<String> = listOf()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSharedFiles" -> {
                    result.success(sharedFiles)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
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
        if (intent == null || (intent.flags and Intent.FLAG_ACTIVITY_LAUNCHED_FROM_HISTORY) != 0) return
        
        val action = intent.action ?: return // Intent action may be null if we already handled it
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_SEND_MULTIPLE) return

        val files = mutableListOf<String>()
        
        // Ensure we have read permissions for the URIs from Google Photos
        intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)

        if (Intent.ACTION_SEND == action) {
            val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
            uri?.let { 
                val path = getRealPathFromUri(it)
                if (path != null) {
                    files.add(path)
                }
            }
        } else if (Intent.ACTION_SEND_MULTIPLE == action) {
            val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
            uris?.forEach { uri ->
                val path = getRealPathFromUri(uri)
                if (path != null) {
                    files.add(path)
                }
            }
        }
        
        if (files.isNotEmpty()) {
            sharedFiles = files
            // Clear the intent action so we don't process it again on next resume
            intent.action = null
        }
    }

    private fun getRealPathFromUri(uri: Uri): String? {
        return try {
            when (uri.scheme) {
                "file" -> uri.path
                "content" -> {
                    val cursor = contentResolver.query(uri, null, null, null, null)
                    cursor?.use {
                        if (it.moveToFirst()) {
                            val columnIndex = it.getColumnIndex(MediaStore.Images.Media.DATA)
                            if (columnIndex != -1) {
                                val path = it.getString(columnIndex)
                                if (path != null && File(path).exists()) {
                                    return path
                                }
                            }
                        }
                    }
                    
                    // Fallback: copy the file to app's cache directory
                    copyUriToCache(uri)
                }
                else -> null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }

    private fun copyUriToCache(uri: Uri): String? {
        return try {
            val contentResolver = contentResolver
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                // Try to get original file name to preserve extension
                var fileName = "shared_${System.currentTimeMillis()}.tmp"
                contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                    if (cursor.moveToFirst()) {
                        val nameIndex = cursor.getColumnIndex(android.provider.OpenableColumns.DISPLAY_NAME)
                        if (nameIndex != -1) {
                            fileName = "shared_${System.currentTimeMillis()}_${cursor.getString(nameIndex)}"
                        }
                    }
                }
                
                val cacheFile = File(cacheDir, fileName)
                val outputStream = FileOutputStream(cacheFile)
                
                inputStream.copyTo(outputStream)
                inputStream.close()
                outputStream.close()
                
                cacheFile.absolutePath
            } else {
                null
            }
        } catch (e: Exception) {
            e.printStackTrace()
            null
        }
    }
}
