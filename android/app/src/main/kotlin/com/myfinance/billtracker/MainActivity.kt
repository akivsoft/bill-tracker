package com.myfinance.billtracker

import android.Manifest
import android.app.AlarmManager
import android.app.NotificationManager
import android.content.Intent
import android.os.Build
import android.provider.Settings
import androidx.core.content.ContextCompat
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val notificationChannel = "com.myfinance.billtracker/notifications"
    private val permissionPrefs by lazy {
        getSharedPreferences("notification_permissions", MODE_PRIVATE)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, notificationChannel)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "deviceState" -> result.success(notificationDeviceState())
                    "markNotificationPermissionRequested" -> {
                        permissionPrefs.edit().putBoolean("requested", true).apply()
                        result.success(null)
                    }
                    "openNotificationSettings" -> {
                        val intent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                        } else {
                            Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS)
                                .setData(android.net.Uri.parse("package:$packageName"))
                        }
                        startActivity(intent)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun notificationDeviceState(): Map<String, Any> {
        val notificationsEnabled = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
            getSystemService(NotificationManager::class.java).areNotificationsEnabled()
        } else true
        val runtimePermissionGranted = Build.VERSION.SDK_INT < 33 ||
            ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) ==
            android.content.pm.PackageManager.PERMISSION_GRANTED
        val hasRequested = permissionPrefs.getBoolean("requested", false)
        val shouldShowRationale = Build.VERSION.SDK_INT >= 33 &&
            shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS)
        val exactAlarmAllowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
            getSystemService(AlarmManager::class.java).canScheduleExactAlarms()
        return mapOf(
            "notificationsEnabled" to (notificationsEnabled && runtimePermissionGranted),
            "shouldShowRationale" to shouldShowRationale,
            "permanentlyDenied" to (
                (Build.VERSION.SDK_INT >= 33 && hasRequested &&
                    !runtimePermissionGranted && !shouldShowRationale) ||
                    (runtimePermissionGranted && !notificationsEnabled)
                ),
            "exactAlarmAllowed" to exactAlarmAllowed,
            "timeZoneId" to java.util.TimeZone.getDefault().id,
        )
    }
}
