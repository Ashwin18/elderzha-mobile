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
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import android.os.PowerManager
import android.util.Log
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
    private var sosPlayer: MediaPlayer? = null
    private var previousAlarmVolume: Int? = null

    // ── Two-tier detection thresholds ───────────────────────────────────────
    // Tier 1: freefall THEN impact — the reliable combo. A genuine fall
    //   makes the phone briefly weightless before hitting something; an
    //   ordinary hand shake essentially never does. Because this combo is
    //   already a strong signal on its own, the impact bar for this tier
    //   can stay moderate.
    // Tier 2: impact with NO preceding freefall — covers falls where the
    //   phone was slowed by pocket/clothing friction and never went fully
    //   weightless. Without the freefall precondition to rule out shakes,
    //   this tier needs a much higher, harder-to-fake impact spike.
    private val freefallThreshold = 4.5       // g < this = near-weightless
    private val freefallMinDurationMs = 100L  // must SUSTAIN freefall briefly,
                                               // filters single-sample noise
    private val impactThresholdWithFreefall = 18.0   // Tier 1 (~1.8G)
    private val impactThresholdNoFreefall   = 27.0   // Tier 2 (~2.75G) —
                                               // well above what a firm
                                               // hand shake typically produces
    private val stillnessWindowMs = 1600L     // slightly longer — real
                                               // falls onto a bed/soft
                                               // surface can bounce/settle
                                               // for a bit before going still

    private var freefallDetected = false
    private var freefallTime = 0L
    private var freefallConfirmedTime = 0L    // when duration requirement was met
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
        if (intent?.action == ACTION_STOP_SOS_SIREN) {
            stopSosSiren()
            // Immediately allow a new fall to be detected — don't wait
            // out the full 35s cooldown once this alert is genuinely
            // handled (I'm Fine, Send SOS, notification dismissed).
            alertShowing = false
            try {
                val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.cancel(ALERT_NOTIF_ID)
            } catch (_: Exception) {}
        }
        return START_STICKY
    }

    override fun onDestroy() {
        sensorManager.unregisterListener(this)
        if (wakeLock?.isHeld == true) wakeLock?.release()
        stopSosSiren()
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
                // Widened tolerance — a real fall onto carpet/bed/mattress
                // can bounce or keep settling slightly rather than going
                // instantly still, unlike a hard floor.
                if (mean in 5.0..15.0 && variance < 14.0 && !alertShowing) {
                    triggerFallAlert()
                }
                resetState()
            }
            return
        }

        // Track freefall state — must SUSTAIN below threshold for
        // freefallMinDurationMs, not just a single noisy sample, before
        // it counts as a confirmed freefall precondition for Tier 1.
        if (g < freefallThreshold) {
            if (!freefallDetected) {
                freefallDetected = true
                freefallTime = now
            }
        } else if (freefallDetected && freefallConfirmedTime == 0L &&
            now - freefallTime >= freefallMinDurationMs
        ) {
            freefallConfirmedTime = now
        }

        val freefallWasConfirmed = freefallConfirmedTime != 0L &&
            (now - freefallConfirmedTime) <= 2000

        val requiredImpact = if (freefallWasConfirmed)
            impactThresholdWithFreefall else impactThresholdNoFreefall

        if (g > requiredImpact) {
            impactDetected = true
            impactTime = now
            postImpactReadings.clear()
            return
        }

        // Reset if freefall was seen but nothing else happened for too long
        if (freefallDetected && now - freefallTime > 2500) {
            resetState()
        }
    }

    override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}

    private fun resetState() {
        freefallDetected = false
        freefallTime = 0L
        freefallConfirmedTime = 0L
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
        val stopIntent = Intent(this, FallMonitorService::class.java).apply {
            action = ACTION_STOP_SOS_SIREN
        }
        val stopPendingIntent = PendingIntent.getService(
            this, 3, stopIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
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
            // If the OS allows this to be swiped away (some devices permit
            // swiping ongoing notifications), stop the siren and reset the
            // detection lock immediately instead of leaving both stuck
            // until the 35s safety-net timer.
            .setDeleteIntent(stopPendingIntent)
            .build()
        manager.notify(ALERT_NOTIF_ID, alertNotification)

        // Play the siren directly inside THIS already-running foreground
        // service, instead of starting a second separate foreground
        // service (AlarmSoundService) — Android can silently block a
        // service starting another foreground service in some situations,
        // which is the likely reason no sound was heard previously even
        // though the visual alert worked fine.
        playSosSiren()
        android.os.Handler(mainLooper).postDelayed({ alertShowing = false }, 35_000)
    }

    private fun playSosSiren() {
        stopSosSiren()
        try {
            val am = getSystemService(AUDIO_SERVICE) as AudioManager
            if (previousAlarmVolume == null) {
                previousAlarmVolume = am.getStreamVolume(AudioManager.STREAM_ALARM)
            }
            try {
                val max = am.getStreamMaxVolume(AudioManager.STREAM_ALARM)
                if (max > 0) am.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
            } catch (_: Exception) {}

            val uri = Uri.parse("android.resource://$packageName/raw/sos_alarm")
            sosPlayer = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                        .build()
                )
                setDataSource(this@FallMonitorService, uri)
                isLooping = true
                setVolume(1f, 1f)
                prepare()
                start()
            }
        } catch (e: Exception) {
            Log.e("FallMonitorService", "Bundled siren failed, using system fallback", e)
            try {
                sosPlayer = MediaPlayer.create(
                    this, android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
                )?.apply {
                    isLooping = true
                    setVolume(1f, 1f)
                    start()
                }
            } catch (e2: Exception) {
                Log.e("FallMonitorService", "System fallback siren also failed", e2)
            }
        }
    }

    private fun stopSosSiren() {
        try { sosPlayer?.stop() } catch (_: Exception) {}
        try { sosPlayer?.release() } catch (_: Exception) {}
        sosPlayer = null
        previousAlarmVolume?.let {
            try {
                val am = getSystemService(AUDIO_SERVICE) as AudioManager
                am.setStreamVolume(AudioManager.STREAM_ALARM, it, 0)
            } catch (_: Exception) {}
        }
        previousAlarmVolume = null
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
        const val FALL_ALARM_SOUND_ID = 7779 // distinct from real scheduled alarms
        const val ALERT_NOTIF_ID = 7778
        const val ACTION_TEST_ALERT = "com.batechnology.elderzha.TEST_FALL_ALERT"
        const val ACTION_STOP_SOS_SIREN = "com.batechnology.elderzha.STOP_SOS_SIREN"
        var isServiceRunning = false
            private set

        fun isMonitoringEnabled(context: Context): Boolean {
            val prefs: SharedPreferences = context.getSharedPreferences(
                "${context.packageName}_preferences", Context.MODE_PRIVATE
            )
            return prefs.getBoolean("flutter.fall_monitor_enabled", false)
        }

        /** Called from FallSOSActivity when the user responds — stops the siren. */
        fun stopSiren(context: Context) {
            val i = Intent(context, FallMonitorService::class.java).apply {
                action = ACTION_STOP_SOS_SIREN
            }
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    context.startForegroundService(i)
                } else {
                    context.startService(i)
                }
            } catch (_: Exception) {}
        }
    }
}
