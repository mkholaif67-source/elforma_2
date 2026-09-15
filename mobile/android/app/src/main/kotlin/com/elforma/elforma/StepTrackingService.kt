package com.elforma.elforma

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import java.time.LocalDate

/** Lightweight foreground sensor listener. The hardware sensor and this local
 * store work without internet. Android may stop it only after Force stop or
 * aggressive vendor battery restrictions; reopening the app starts it again. */
class StepTrackingService : Service(), SensorEventListener {
    private lateinit var manager: SensorManager
    private var sensor: Sensor? = null

    override fun onCreate() {
        super.onCreate()
        createChannel()
        startForeground(NOTIFICATION_ID, NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("الفورمة يتابع خطواتك")
            .setContentText("كل خطوة بتقربك من هدفك")
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(NotificationCompat.CATEGORY_SERVICE)
            .build())
        manager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        registerSensor()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        StepTrackingStore.enable(this)
        if (sensor == null) registerSensor()
        return START_STICKY
    }

    private fun registerSensor() {
        if (!permissionGranted(this)) return
        sensor = manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
            ?: manager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR)
        sensor?.let { manager.registerListener(this, it, SensorManager.SENSOR_DELAY_NORMAL) }
    }

    override fun onSensorChanged(event: SensorEvent) {
        val today = LocalDate.now()
        when (event.sensor.type) {
            Sensor.TYPE_STEP_COUNTER -> StepTrackingStore.recordCounter(this, event.values.firstOrNull() ?: return, today)
            Sensor.TYPE_STEP_DETECTOR -> StepTrackingStore.recordDetector(this, (event.values.firstOrNull() ?: 1f).toInt().coerceAtLeast(1), today)
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) = Unit
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        if (::manager.isInitialized) manager.unregisterListener(this)
        sensor = null
        super.onDestroy()
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(CHANNEL_ID, "تتبع الخطوات", NotificationManager.IMPORTANCE_LOW).apply {
                description = "تشغيل عداد الخطوات في الخلفية"
                setSound(null, null)
                enableVibration(false)
                setShowBadge(false)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    companion object {
        private const val CHANNEL_ID = "step_tracking_v1"
        private const val NOTIFICATION_ID = 1907

        fun permissionGranted(context: Context): Boolean =
            Build.VERSION.SDK_INT < Build.VERSION_CODES.Q ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.ACTIVITY_RECOGNITION) == PackageManager.PERMISSION_GRANTED

        fun hasSensor(context: Context): Boolean {
            val manager = context.getSystemService(Context.SENSOR_SERVICE) as SensorManager
            return manager.getDefaultSensor(Sensor.TYPE_STEP_COUNTER) != null ||
                manager.getDefaultSensor(Sensor.TYPE_STEP_DETECTOR) != null
        }

        fun startIfAllowed(context: Context) {
            if (!permissionGranted(context) || !hasSensor(context)) return
            StepTrackingStore.enable(context)
            val intent = Intent(context, StepTrackingService::class.java)
            try { ContextCompat.startForegroundService(context, intent) } catch (_: Exception) { /* app resume retries */ }
        }
    }
}
