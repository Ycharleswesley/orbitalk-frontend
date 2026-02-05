package com.orbitalk.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.view.WindowManager

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.orbitalk.screenshot"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "enableScreenshotPrevention" -> {
                    try {
                        // Enable FLAG_SECURE to prevent screenshots
                        window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Screenshot prevention couldn't be enabled.", null)
                    }
                }
                "disableScreenshotPrevention" -> {
                    try {
                        // Disable FLAG_SECURE to allow screenshots
                        window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        result.success(null)
                    } catch (e: Exception) {
                        result.error("UNAVAILABLE", "Screenshot prevention couldn't be disabled.", null)
                    }
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
}
