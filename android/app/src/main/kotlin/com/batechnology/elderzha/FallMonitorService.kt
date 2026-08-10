package com.batechnology.elderzha

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import androidx.core.app.NotificationCompat
import kotlin.math.sqrt

/**
 * Native foreground service — runs independently of Flutter.
 * Survives the app being swiped from Recent Apps (does NOT survive a
 * manual Force Stop — that is an Android OS restriction, not fixable
 * by any app).
 *
 * Detection: impact-first pattern proven in the standalone POC —
 * triggers on a strong impact even without a clean freefall first
 * (realistic for falls with the phone in a pocket), then confirms
 * the phone goes still afterwards using mean + variance of the
 * post-impact readings.
 */
class FallMonitorService : Service(), SensorEventListener {

    private lateinit var sensorManager: SensorManager
    private var accelerometer: Sensor? = null
    private var wakeLock: PowerManager.WakeLock? = null

    private val freefallThreshold = 5.0
    private val impactThreshold = 15.5
    private val stillnessWindowMs = 1200L

    private var freefallDetected = false
    private var freefallTime = 0L
    private var impactDetected = false
    private var impactTime = 0L
    private val postImpactReadings = mutableListOf<Double>()
    private var alertShowing = false

    override fun onCreate() {
        super.onCreate()
        sensorManager = getSystemService(Context.SENSOR_SERVICE) as SensorManager
        accelerometer = sensorManager.getDefaultSensor(Sensor.TYPE_ACCELEROMETER)
        wakeLock = (getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "$packageName:fall-monitor")
            .apply { setReferenceCounted(false) }
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        startForeground(NOTIF_ID, buildNotification())
        if (wakeLock?.isHeld != true) wakeLock?.acquire()
        sensorManager.unregisterListener(this)
        accelerometer?.let {
            sensorManager.registerListener(this, it, SensorManager.SENSOR_DELAY_GAME)
        }
        isServiceRunning = true
        if (intent?.action == ACTION_TEST_ALERT) {
            triggerFallAlert()
        }
        return START_STICKY
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        if (wakeLock?.isHeld == true) wakeLock?.release()
        isServiceRunning = false
        super.onDestroy()
    }

    // Fights OEM behavior (Samsung/MIUI/OxygenOS) that kills a foreground
    // service the moment its task is swiped from Recent Apps.
    override fun onTaskRemoved(rootIntent: Intent?) {
        super.onTaskRemoved(rootIntent)
        val restartIntent = Intent(applicationContext, FallMonitorService::class.java).apply {
            setPackage(packageName)
        }
        val pendingIntent = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            PendingIntent.getForegroundService(
                this, 1, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
        } else {
            PendingIntent.getService(
                this, 1, restartIntent,
                PendingIntent.FLAG_ONE_SHOT or PendingIntent.FLAG_IMMUTABLE
            )
        }
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as android.app.AlarmManager
        alarmManager.setAndAllowWhileIdle(
            android.app.AlarmManager.RTC,
            System.currentTimeMillis() + 500,
            pendingIntent
        )
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onSensorChanged(event: SensorEvent) {
        val g = sqrt(
            (event.values[0] * event.values[0] +
                event.values[1] * event.values[1] +
                event.values[2] * event.values[2]).toDouble()
        )
        val now = System.currentTimeMillis()

        if (impactDetected) {
            postImpactReadings.add(g)
            if (now - impactTime >= stillnessWindowMs) {
                val mean = postImpactReadings.average()
                val variance = postImpactReadings
                    .map { (it - mean) * (it - mean) }
                    .average()
                if (mean in 7.0..13.0 && variance < 8.0 && !alertShowing) {
                    triggerFallAlert()
                }
                resetState()
            }
            return
        }

        if (!freefallDetected && g < freefallThreshold) {
            freefallDetected = true
            freefallTime = now
            return
        }

        if (g > impactThreshold) {
            impactDetected = true
            impactTime = now
            postImpactReadings.clear()
            return
        }

        if (freefallDetected && now - freefallTime > 2000) {
            resetState()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun resetState() {
        freefallDetected = false
        freefallTime = 0L
        impactDetected = false
        impactTime = 0L
        postImpactReadings.clear()
    }

    private fun triggerFallAlert() {
        alertShowing = true

        val alertIntent = Intent(this, FallSOSActivity::class.java).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        val fullScreenPendingIntent = PendingIntent.getActivity(
            this, 2, alertIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            manager.createNotificationChannel(
                NotificationChannel(
                    ALERT_CHANNEL_ID,
                    "Fall SOS alerts",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Urgent fall detection and SOS alerts"
                    enableVibration(true)
                    lockscreenVisibility = Notification.VISIBILITY_PUBLIC
                }
            )
        }
        val alertNotification = NotificationCompat.Builder(this, ALERT_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_alert)
            .setContentTitle("Possible fall detected")
            .setContentText("Tap immediately if you are safe")
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setDefaults(NotificationCompat.DEFAULT_ALL)
            .setOngoing(true)
            .setAutoCancel(true)
            .setContentIntent(fullScreenPendingIntent)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .build()
        manager.notify(ALERT_NOTIF_ID, alertNotification)

        android.os.Handler(mainLooper).postDelayed({ alertShowing = false }, 35_000)
    }

    private fun buildNotification(): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "Fall Detection",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps fall detection running in the background"
            }
            manager.createNotificationChannel(channel)
        }

        val openAppIntent = PendingIntent.getActivity(
            this, 0,
            Intent(this, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_mylocation)
            .setContentTitle("ElderZha — Fall Detection Active")
            .setContentText("Monitoring for falls in the background")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .setContentIntent(openAppIntent)
            .build()
    }

    companion object {
        const val CHANNEL_ID = "elderzha_fall_monitor_channel"
        const val ALERT_CHANNEL_ID = "elderzha_fall_sos_alert_channel"
        const val NOTIF_ID = 7777
        const val ALERT_NOTIF_ID = 7778
        const val ACTION_TEST_ALERT = "com.batechnology.elderzha.TEST_FALL_ALERT"
        var isServiceRunning = false
            private set

        fun isMonitoringEnabled(context: Context): Boolean {
            val prefs: SharedPreferences = context.getSharedPreferences(
                "${context.packageName}_preferences", Context.MODE_PRIVATE
            )
            return prefs.getBoolean("flutter.fall_monitor_enabled", false)
        }
    }
}
