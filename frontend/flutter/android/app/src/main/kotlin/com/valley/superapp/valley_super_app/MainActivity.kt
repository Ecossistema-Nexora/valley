package com.valley.superapp.valley_super_app

import android.Manifest
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "valley/live_tracking",
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startTracking" -> {
                    requestNotificationPermissionIfNeeded()
                    startLiveTracking(call, ValleyLiveTrackingService.ACTION_START)
                    result.success(true)
                }
                "updateTracking" -> {
                    startLiveTracking(call, ValleyLiveTrackingService.ACTION_UPDATE)
                    result.success(true)
                }
                "stopTracking" -> {
                    val intent = Intent(this, ValleyLiveTrackingService::class.java).apply {
                        action = ValleyLiveTrackingService.ACTION_STOP
                    }
                    startService(intent)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun startLiveTracking(call: MethodCall, actionName: String) {
        val args = call.arguments as? Map<*, *> ?: emptyMap<String, Any?>()
        val intent = Intent(this, ValleyLiveTrackingService::class.java).apply {
            action = actionName
            putStringArg(args, "order_id")
            putStringArg(args, "order_label")
            putStringArg(args, "status")
            putStringArg(args, "status_label")
            putStringArg(args, "courier_name")
            putStringArg(args, "vehicle_label")
            putStringArg(args, "tracking_url")
            putStringArg(args, "auth_token")
            putStringArg(args, "map_snapshot_url")
            putIntArg(args, "eta_minutes")
            putIntArg(args, "progress")
            putDoubleArg(args, "courier_lat")
            putDoubleArg(args, "courier_lng")
            putDoubleArg(args, "pickup_lat")
            putDoubleArg(args, "pickup_lng")
            putDoubleArg(args, "destination_lat")
            putDoubleArg(args, "destination_lng")
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            startForegroundService(intent)
        } else {
            startService(intent)
        }
    }

    private fun requestNotificationPermissionIfNeeded() {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) {
            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 7201)
        }
    }

    private fun Intent.putStringArg(args: Map<*, *>, key: String) {
        (args[key] as? String)?.takeIf { it.isNotBlank() }?.let { putExtra(key, it) }
    }

    private fun Intent.putIntArg(args: Map<*, *>, key: String) {
        when (val value = args[key]) {
            is Int -> putExtra(key, value)
            is Number -> putExtra(key, value.toInt())
        }
    }

    private fun Intent.putDoubleArg(args: Map<*, *>, key: String) {
        when (val value = args[key]) {
            is Double -> putExtra(key, value)
            is Number -> putExtra(key, value.toDouble())
        }
    }
}
