package com.example.mockup_project

import android.content.Context
import android.media.AudioAttributes
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var alertVibrator: Vibrator? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "smart_drive_guard/alarm"
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startVibration" -> {
                    startAlertVibration()
                    result.success(null)
                }
                "stopVibration" -> {
                    stopAlertVibration()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun getAlertVibrator(): Vibrator {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val manager = getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager
            manager.defaultVibrator
        } else {
            getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }

    @Suppress("DEPRECATION")
    private fun startAlertVibration() {
        val vibrator = getAlertVibrator()
        alertVibrator = vibrator
        if (!vibrator.hasVibrator()) return

        // Vibrate for 700 ms, pause for 300 ms, and repeat until AlertScreen closes.
        val pattern = longArrayOf(0, 700, 300)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val attributes = AudioAttributes.Builder()
                .setUsage(AudioAttributes.USAGE_ALARM)
                .build()
            vibrator.vibrate(VibrationEffect.createWaveform(pattern, 0), attributes)
        } else {
            vibrator.vibrate(pattern, 0)
        }
    }

    private fun stopAlertVibration() {
        alertVibrator?.cancel()
        alertVibrator = null
    }

    override fun onDestroy() {
        stopAlertVibration()
        super.onDestroy()
    }
}
