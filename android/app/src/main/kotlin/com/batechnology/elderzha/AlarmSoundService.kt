package com.batechnology.elderzha

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.AudioManager
import android.media.MediaPlayer
import android.net.Uri
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import java.io.File

class AlarmSoundService : Service() {

    private var player: MediaPlayer? = null
    private var audioManager: AudioManager? = null
    private var previousAlarmVolume: Int? = null
    private var activeAlarmId: Int = 0

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> {
                stopAlarmSound()
                stopSelf()
                return START_NOT_STICKY
            }
            else -> {
                val alarmId   = intent?.getIntExtra(EXTRA_ALARM_ID, 0) ?: 0
                val soundUrl  = intent?.getStringExtra(EXTRA_SOUND_URL) ?: ""
                val title     = intent?.getStringExtra(EXTRA_TITLE) ?: "ElderZha Reminder"
                val notes     = intent?.getStringExtra(EXTRA_NOTES) ?: "Alarm is ringing."
                val imageUrl  = intent?.getStringExtra(EXTRA_IMAGE_URL) ?: ""

                // Start foreground IMMEDIATELY (Android requires within 5s)
                val notification = buildNotification(alarmId, title, notes, soundUrl, imageUrl)
                startForeground(FOREGROUND_ID, notification)

                // Launch AlarmActivity directly for locked screen
                // fullScreenIntent handles it automatically on most devices
                // but we also launch directly as backup
                try {
                    val actIntent = Intent(this, AlarmActivity::class.java).apply {
                        flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                                Intent.FLAG_ACTIVITY_SINGLE_TOP
                        putExtra(AlarmActivity.EXTRA_TITLE, title)
                        putExtra(AlarmActivity.EXTRA_NOTES, notes)
                        putExtra(AlarmActivity.EXTRA_SOUND_URL, soundUrl)
                        putExtra(AlarmActivity.EXTRA_IMAGE_URL, imageUrl)
                        putExtra(AlarmActivity.EXTRA_PLAY_SOUND, false)
                        putExtra(AlarmActivity.EXTRA_NOTIFICATION_ID, alarmId)
                    }
                    startActivity(actIntent)
                } catch (_: Exception) {
                    // Blocked by Android — fullScreenIntent will handle it
                }

                // Start sound only if not already playing for this alarm
                if (player == null || activeAlarmId != alarmId) {
                    activeAlarmId = alarmId
                    play(soundUrl)
                }
            }
        }
        return START_STICKY
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onDestroy() {
        stopAlarmSound()
        super.onDestroy()
    }

    private fun play(soundUrl: String) {
        stopAlarmSound()
        try {
            boostAlarmVolume()
            player = MediaPlayer().apply {
                setAudioAttributes(
                    AudioAttributes.Builder()
                        .setUsage(AudioAttributes.USAGE_ALARM)
                        .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                        .build()
                )
                setAlarmDataSource(soundUrl)
                isLooping = true
                setVolume(1f, 1f)
                prepare()
                start()
            }
        } catch (_: Exception) {
            try {
                boostAlarmVolume()
                player = MediaPlayer.create(
                    this,
                    android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI
                )?.apply {
                    isLooping = true
                    setVolume(1f, 1f)
                    start()
                }
            } catch (_: Exception) {}
        }
    }

    private fun buildNotification(
        alarmId: Int,
        title: String,
        notes: String,
        soundUrl: String,
        imageUrl: String,
    ): Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val ch = NotificationChannel(
                CHANNEL_ID, "ElderZha Alarms",
                NotificationManager.IMPORTANCE_MAX
            ).apply {
                description = "Medication, food and family alarms"
                enableVibration(true)
                setSound(null, null)
                lockscreenVisibility = Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(ch)
        }

        // fullScreenIntent → opens AlarmActivity (premium UI) over lock screen
        val fullScreenPi = PendingIntent.getActivity(
            this, alarmId + 200_000,
            Intent(this, AlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(AlarmActivity.EXTRA_TITLE, title)
                putExtra(AlarmActivity.EXTRA_NOTES, notes)
                putExtra(AlarmActivity.EXTRA_SOUND_URL, soundUrl)
                putExtra(AlarmActivity.EXTRA_IMAGE_URL, imageUrl)
                putExtra(AlarmActivity.EXTRA_PLAY_SOUND, false)
                putExtra(AlarmActivity.EXTRA_NOTIFICATION_ID, alarmId)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // dismissIntent → stops sound service directly
        val dismissServiceIntent = Intent(this, AlarmSoundService::class.java).apply {
            action = ACTION_STOP
        }
        val dismissPi = PendingIntent.getService(
            this, alarmId + 500_000,
            dismissServiceIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText("Tap 'Dismiss' to stop the alarm")
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setOnlyAlertOnce(true)
            // contentIntent = dismiss (tapping notification stops alarm, not open app)
            .setContentIntent(dismissPi)
            .setDeleteIntent(dismissPi)
            // fullScreenIntent = shows AlarmActivity immediately over lock screen
            .setFullScreenIntent(fullScreenPi, true)
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Dismiss Alarm",
                dismissPi
            )
            .build()
    }

    private fun MediaPlayer.setAlarmDataSource(soundUrl: String) {
        val raw = soundUrl.trim()
        when {
            raw.startsWith("http://") || raw.startsWith("https://") ->
                setDataSource(this@AlarmSoundService, Uri.parse(raw))
            raw.startsWith("file://") -> {
                val file = File(Uri.parse(raw).path ?: raw.removePrefix("file://"))
                if (file.exists()) setDataSource(file.absolutePath)
                else setDataSource(this@AlarmSoundService,
                    android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI)
            }
            raw.isNotBlank() && File(raw).exists() ->
                setDataSource(File(raw).absolutePath)
            else ->
                setDataSource(this@AlarmSoundService,
                    android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI)
        }
    }

    private fun boostAlarmVolume() {
        val mgr = getSystemService(AUDIO_SERVICE) as AudioManager
        audioManager = mgr
        if (previousAlarmVolume == null) {
            previousAlarmVolume = mgr.getStreamVolume(AudioManager.STREAM_ALARM)
        }
        try {
            val max = mgr.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            if (max > 0) mgr.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
        } catch (_: Exception) {}
    }

    private fun stopAlarmSound() {
        try { player?.stop() } catch (_: Exception) {}
        try { player?.release() } catch (_: Exception) {}
        player = null
        previousAlarmVolume?.let {
            try { audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, it, 0) }
            catch (_: Exception) {}
        }
        previousAlarmVolume = null
        activeAlarmId = 0
    }

    companion object {
        const val CHANNEL_ID           = "elderzha_alarm_v5"
        const val FOREGROUND_ID        = 9999  // fixed ID for foreground notification
        private const val ACTION_STOP  = "com.batechnology.elderzha.STOP_ALARM_SOUND"
        private const val EXTRA_ALARM_ID  = "alarmId"
        private const val EXTRA_SOUND_URL = "soundUrl"
        private const val EXTRA_IMAGE_URL = "imageUrl"
        private const val EXTRA_TITLE     = "title"
        private const val EXTRA_NOTES     = "notes"

        fun start(
            context: Context, alarmId: Int, soundUrl: String,
            title: String = "ElderZha Reminder",
            notes: String = "Alarm is ringing.",
            imageUrl: String = "",
        ) {
            val i = Intent(context, AlarmSoundService::class.java).apply {
                putExtra(EXTRA_ALARM_ID, alarmId)
                putExtra(EXTRA_SOUND_URL, soundUrl)
                putExtra(EXTRA_IMAGE_URL, imageUrl)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_NOTES, notes)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
                context.startForegroundService(i)
            else
                context.startService(i)
        }

        fun stop(context: Context) {
            val i = Intent(context, AlarmSoundService::class.java).apply {
                action = ACTION_STOP
            }
            try { context.startService(i) } catch (_: Exception) {}
            // Also force stop after brief delay to ensure onDestroy is called
            context.stopService(Intent(context, AlarmSoundService::class.java))
        }
    }
}
