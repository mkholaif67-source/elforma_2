package com.elforma.elforma

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class StepTrackingBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent?.action == Intent.ACTION_BOOT_COMPLETED ||
            intent?.action == Intent.ACTION_MY_PACKAGE_REPLACED ||
            intent?.action == "android.intent.action.QUICKBOOT_POWERON") {
            if (StepTrackingStore.isEnabled(context)) {
                try { StepTrackingService.startIfAllowed(context) } catch (_: Exception) { /* Android/OEM may defer boot starts */ }
            }
        }
    }
}
