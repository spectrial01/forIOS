package com.example.project_nexus

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "location_permission_helper"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openAppLocationPermissionSettings" -> {
                    openAppLocationPermissionSettings(result)
                }
                "isLocationAlwaysGranted" -> {
                    checkLocationAlwaysGranted(result)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun openAppLocationPermissionSettings(result: MethodChannel.Result) {
        try {
            // Open APP-SPECIFIC permission settings (NOT system location settings)
            val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
                data = Uri.fromParts("package", packageName, null)
                flags = Intent.FLAG_ACTIVITY_NEW_TASK
            }
            startActivity(intent)
            result.success(true)
        } catch (e: Exception) {
            // Fallback to general app settings
            try {
                val fallbackIntent = Intent(Settings.ACTION_MANAGE_APPLICATIONS_SETTINGS)
                fallbackIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(fallbackIntent)
                result.success(true)
            } catch (fallbackException: Exception) {
                result.error("ERROR", "Failed to open app settings: ${fallbackException.message}", null)
            }
        }
    }

    private fun checkLocationAlwaysGranted(result: MethodChannel.Result) {
        try {
            val isAlwaysGranted = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                // For Android 10+ (API 29+), check background location permission
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_BACKGROUND_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            } else {
                // For older versions, fine location permission is enough for "always"
                ContextCompat.checkSelfPermission(
                    this,
                    Manifest.permission.ACCESS_FINE_LOCATION
                ) == PackageManager.PERMISSION_GRANTED
            }
            
            result.success(isAlwaysGranted)
        } catch (e: Exception) {
            result.error("ERROR", "Failed to check background location permission: ${e.message}", null)
        }
    }

}
