package com.example.watermark_app

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
    private val CHANNEL = "watermark_app/sharing"
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
        handleSharedIntent(intent)
    }

    override fun onResume() {
        super.onResume()
        handleSharedIntent(intent)
    }

    private fun handleSharedIntent(intent: Intent?) {
        if (intent == null) return
        
        val files = mutableListOf<String>()
        
        when (intent.action) {
            Intent.ACTION_SEND -> {
                val uri = intent.getParcelableExtra<Uri>(Intent.EXTRA_STREAM)
                uri?.let { 
                    val path = getRealPathFromUri(it)
                    if (path != null) {
                        files.add(path)
                    }
                }
            }
            Intent.ACTION_SEND_MULTIPLE -> {
                val uris = intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM)
                uris?.forEach { uri ->
                    val path = getRealPathFromUri(uri)
                    if (path != null) {
                        files.add(path)
                    }
                }
            }
        }
        
        sharedFiles = files
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
            val inputStream: InputStream? = contentResolver.openInputStream(uri)
            if (inputStream != null) {
                val fileName = "shared_${System.currentTimeMillis()}.tmp"
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
