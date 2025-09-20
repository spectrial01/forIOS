package com.example.project_nexus

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.util.Log
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.project_nexus/installer"
    private val EMERGENCY_CHANNEL = "emergency_update_channel"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d("MainActivity", "Configuring Flutter engine")
        
        // Start the listener service
        try {
            startService(Intent(this, TaskRemovedListenerService::class.java))
            Log.d("MainActivity", "TaskRemovedListenerService started")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to start TaskRemovedListenerService: ${e.message}")
        }
        
        // Set up method channel for APK installation
        try {
            MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
                Log.d("MainActivity", "Method called: ${call.method}")
                when (call.method) {
                    "installApk" -> {
                        val apkPath = call.argument<String>("apkPath")
                        val authority = call.argument<String>("authority")
                        
                        Log.d("MainActivity", "installApk called with path: $apkPath, authority: $authority")
                        
                        if (apkPath != null && authority != null) {
                            val success = installApk(apkPath, authority)
                            Log.d("MainActivity", "Installation result: $success")
                            result.success(success)
                        } else {
                            Log.e("MainActivity", "Invalid arguments: apkPath=$apkPath, authority=$authority")
                            result.error("INVALID_ARGUMENTS", "APK path and authority are required", null)
                        }
                    }
                    else -> {
                        Log.w("MainActivity", "Unknown method: ${call.method}")
                        result.notImplemented()
                    }
                }
            }
            Log.d("MainActivity", "Method channel registered successfully")
        } catch (e: Exception) {
            Log.e("MainActivity", "Failed to register method channel: ${e.message}")
        }

        // NEW: Set up method channel for emergency updates (silent installation)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, EMERGENCY_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "installApk" -> {
                    val apkPath = call.argument<String>("apkPath")
                    
                    if (apkPath != null) {
                        val success = installApkSilently(apkPath)
                        result.success(success)
                    } else {
                        result.error("INVALID_ARGUMENTS", "APK path is required", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun installApk(apkPath: String, authority: String): Boolean {
        return try {
            val apkFile = File(apkPath)
            if (!apkFile.exists()) {
                Log.e("MainActivity", "APK file does not exist: $apkPath")
                return false
            }
            
            Log.d("MainActivity", "Installing APK from: $apkPath")
            Log.d("MainActivity", "File size: ${apkFile.length()} bytes")
            
            val intent = Intent(Intent.ACTION_VIEW)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Use FileProvider for Android 7+ (API 24+)
                try {
                    val apkUri = FileProvider.getUriForFile(this, authority, apkFile)
                    Log.d("MainActivity", "FileProvider URI: $apkUri")
                    intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
                    intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                } catch (e: Exception) {
                    Log.e("MainActivity", "FileProvider failed: ${e.message}")
                    // Fallback to file:// URI
                    intent.setDataAndType(Uri.fromFile(apkFile), "application/vnd.android.package-archive")
                }
            } else {
                // For older Android versions, use file:// URI
                intent.setDataAndType(Uri.fromFile(apkFile), "application/vnd.android.package-archive")
            }
            
            startActivity(intent)
            Log.d("MainActivity", "Installation intent started successfully")
            true
        } catch (e: Exception) {
            Log.e("MainActivity", "Installation failed: ${e.message}")
            e.printStackTrace()
            false
        }
    }

    // NEW: Silent APK installation for emergency updates (no user notification)
    private fun installApkSilently(apkPath: String): Boolean {
        return try {
            val apkFile = File(apkPath)
            if (!apkFile.exists()) {
                return false
            }
            
            // For emergency updates, we still need to show the installation dialog
            // but we can make it less intrusive by using a different approach
            val intent = Intent(Intent.ACTION_VIEW)
            intent.flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_NO_ANIMATION
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // Use FileProvider for Android 7+ (API 24+)
                val apkUri = FileProvider.getUriForFile(this, "com.example.project_nexus.fileprovider", apkFile)
                intent.setDataAndType(apkUri, "application/vnd.android.package-archive")
                intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
            } else {
                // For older Android versions, use file:// URI
                intent.setDataAndType(Uri.fromFile(apkFile), "application/vnd.android.package-archive")
            }
            
            // Start installation in background
            startActivity(intent)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }
}