package com.example.realme_alarm_manager

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.PowerManager
import android.provider.AlarmClock
import android.provider.Settings
import android.net.Uri
import androidx.annotation.NonNull
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.example.realme_alarm/native_clock"

    private val REALME_CLOCK_PACKAGES = arrayOf(
        "com.coloros.alarm",        // Primary Realme X China ROM
        "com.heytap.deskclock",     // Newer Realme UI / HeyTap
        "com.android.deskclock",    // Generic AOSP
        "com.google.android.deskclock" // Google Clock
    )

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "setAlarm" -> {
                    val hour = call.argument<Int>("hour") ?: 0
                    val minutes = call.argument<Int>("minutes") ?: 0
                    val message = call.argument<String>("message") ?: "Custom Alarm"
                    val skipUi = call.argument<Boolean>("skipUi") ?: false
                    val vibrate = call.argument<Boolean>("vibrate") ?: true

                    val response = dispatchAlarmIntent(hour, minutes, message, skipUi, vibrate)
                    result.success(response)
                }
                "openClockApp" -> {
                    val opened = openRealmeClock()
                    result.success(opened)
                }
                "checkClockAvailability" -> {
                    val available = isAlarmIntentResolvable()
                    result.success(available)
                }
                "checkBatteryOptimization" -> {
                    val isIgnoring = isIgnoringBatteryOptimizations()
                    result.success(isIgnoring)
                }
                "requestIgnoreBatteryOptimization" -> {
                    requestBatteryOptimizationExemption()
                    result.success(true)
                }
                "getPresetStoragePath" -> {
                    // App-private files directory: persistent across restarts.
                    val presetFile = File(filesDir, "quick_presets.json")
                    result.success(presetFile.absolutePath)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }

    private fun dispatchAlarmIntent(
        hour: Int,
        minutes: Int,
        message: String,
        skipUi: Boolean,
        vibrate: Boolean
    ): Map<String, Any> {
        val intent = Intent(AlarmClock.ACTION_SET_ALARM).apply {
            putExtra(AlarmClock.EXTRA_HOUR, hour)
            putExtra(AlarmClock.EXTRA_MINUTES, minutes)
            putExtra(AlarmClock.EXTRA_MESSAGE, message)
            putExtra(AlarmClock.EXTRA_SKIP_UI, skipUi)
            putExtra(AlarmClock.EXTRA_VIBRATE, vibrate)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }

        for (pkg in REALME_CLOCK_PACKAGES) {
            val targetedIntent = Intent(intent).setPackage(pkg)
            if (packageManager.resolveActivity(targetedIntent, 0) != null) {
                return try {
                    startActivity(targetedIntent)
                    mapOf(
                        "success" to true,
                        "dispatched" to true,
                        "targetPackage" to pkg,
                        "note" to "Dispatched to $pkg."
                    )
                } catch (e: Exception) {
                    mapOf(
                        "success" to false,
                        "dispatched" to false,
                        "error" to (e.localizedMessage ?: "Failed to start intent"),
                        "targetPackage" to pkg
                    )
                }
            }
        }

        if (packageManager.resolveActivity(intent, 0) != null) {
            return try {
                startActivity(intent)
                mapOf("success" to true, "dispatched" to true, "targetPackage" to "android.default")
            } catch (e: Exception) {
                mapOf("success" to false, "dispatched" to false, "error" to e.localizedMessage)
            }
        }

        return mapOf(
            "success" to false,
            "dispatched" to false,
            "error" to "No compatible Clock application found on this Realme device."
        )
    }

    private fun openRealmeClock(): Boolean {
        val showAlarmsIntent = Intent(AlarmClock.ACTION_SHOW_ALARMS).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        if (packageManager.resolveActivity(showAlarmsIntent, 0) != null) {
            startActivity(showAlarmsIntent)
            return true
        }

        for (pkg in REALME_CLOCK_PACKAGES) {
            val launchIntent = packageManager.getLaunchIntentForPackage(pkg)
            if (launchIntent != null) {
                launchIntent.flags = Intent.FLAG_ACTIVITY_NEW_TASK
                startActivity(launchIntent)
                return true
            }
        }
        return false
    }

    private fun isAlarmIntentResolvable(): Boolean {
        val testIntent = Intent(AlarmClock.ACTION_SET_ALARM)
        return packageManager.resolveActivity(testIntent, 0) != null
    }

    private fun isIgnoringBatteryOptimizations(): Boolean {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val pm = getSystemService(Context.POWER_SERVICE) as PowerManager
            return pm.isIgnoringBatteryOptimizations(packageName)
        }
        return true
    }

    private fun requestBatteryOptimizationExemption() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
            } catch (e: Exception) {}
        }
    }
}
