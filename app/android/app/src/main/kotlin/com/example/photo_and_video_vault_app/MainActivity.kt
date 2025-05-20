package com.example.photo_and_video_vault_app

import io.flutter.embedding.android.FlutterActivity
import android.content.ComponentName
import android.content.pm.PackageManager
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import androidx.annotation.NonNull
import android.util.Log

private const val CHANNEL = "com.example.photo_and_video_vault_app/launcher"
private const val TAG = "MainActivity"

class MainActivity: FlutterActivity() {
    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->
            if (call.method == "setLauncherAlias") {
                val alias = call.argument<String>("alias")
                try {
                    setLauncherAlias(alias)
                    result.success(true)
                } catch (e: Exception) {
                    Log.e(TAG, "Error setting launcher alias: ${e.message}", e)
                    result.error("UNAVAILABLE", "Error setting launcher alias: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun setLauncherAlias(alias: String?) {
        val packageName = "com.example.photo_and_video_vault_app"
        val pm = packageManager

        // Define all activity alias component names
        val mainAlias = ComponentName(packageName, "$packageName.MainActivity")
        val calculatorAlias = ComponentName(packageName, "$packageName.MainActivityAliasCalculator")
        val calendarAlias = ComponentName(packageName, "$packageName.MainActivityAliasCalendar")
        val notesAlias = ComponentName(packageName, "$packageName.MainActivityAliasNotes")
        val weatherAlias = ComponentName(packageName, "$packageName.MainActivityAliasWeather")
        val clockAlias = ComponentName(packageName, "$packageName.MainActivityAliasClock")

        // List of all alias components
        val allAliases = listOf(mainAlias, calculatorAlias, calendarAlias, notesAlias, weatherAlias, clockAlias)

        // Disable all aliases first
        for (component in allAliases) {
            pm.setComponentEnabledSetting(
                component,
                // PackageManager.COMPONENT_ENABLED_STATE_DEFAULT,
                PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP
            )
        }

        // Enable the requested alias (or default to main activity if alias is null)
        val targetComponent = when (alias) {
            "MainActivityAliasCalculator" -> calculatorAlias
            "MainActivityAliasCalendar" -> calendarAlias
            "MainActivityAliasNotes" -> notesAlias
            "MainActivityAliasWeather" -> weatherAlias
            "MainActivityAliasClock" -> clockAlias
            else -> mainAlias // Default to main activity if alias is null or unknown
        }

        pm.setComponentEnabledSetting(
            targetComponent,
            PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
            PackageManager.DONT_KILL_APP
        )

        Log.d(TAG, "App launcher changed to: ${alias ?: "default"}")
    }
}
