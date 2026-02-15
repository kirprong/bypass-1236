package com.bypass1236.bypass_1236

import android.content.Context
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.bypass1236.bypass_1236/foreground_service"
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "startForegroundService" -> {
                    val title = call.argument<String>("title") ?: "BYPASS-1236"
                    val body = call.argument<String>("body") ?: "Таймер работает"
                    TimerForegroundService.startService(this, title, body)
                    result.success(null)
                }
                "stopForegroundService" -> {
                    TimerForegroundService.stopService(this)
                    result.success(null)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
