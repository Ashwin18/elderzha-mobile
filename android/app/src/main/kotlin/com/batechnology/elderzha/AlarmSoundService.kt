package com.batechnology.elderzha

import android.app.Service
import android.app.NotificationChannel
import android.app.NotificationManager
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
                val alarmId = intent?.getIntExtra(EXTRA_ALARM_ID, 0) ?: 0
                val soundUrl = intent?.getStringExtra(EXTRA_SOUND_URL) ?: ""
                val title = intent?.getStringExtra(EXTRA_TITLE) ?: "ElderZha reminder"
                val notes = intent?.getStringExtra(EXTRA_NOTES) ?: "Alarm is ringing."
                startForeground(alarmId.coerceAtLeast(1), notification(title, notes))
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
                player = MediaPlayer.create(this, android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI)
                player?.isLooping = true
                player?.setVolume(1f, 1f)
                player?.start()
            } catch (_: Exception) {
            }
        }
    }

    private fun notification(title: String, notes: String): android.app.Notification {
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "ElderZha Alarms",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Medical, food, family, and reminder alarms"
                enableVibration(true)
                setSound(null, null)
            }
            manager.createNotificationChannel(channel)
        }
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(notes.ifBlank { "Alarm is ringing." })
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .build()
    }

    private fun MediaPlayer.setAlarmDataSource(soundUrl: String) {
        val raw = soundUrl.trim()
        when {
            raw.startsWith("http://") || raw.startsWith("https://") ->
                setDataSource(this@AlarmSoundService, Uri.parse(raw))
            raw.startsWith("file://") -> {
                val file = File(Uri.parse(raw).path ?: raw.removePrefix("file://"))
                if (file.exists()) {
                    setDataSource(file.absolutePath)
                } else {
                    setDataSource(this@AlarmSoundService, android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI)
                }
            }
            raw.isNotBlank() && File(raw).exists() ->
                setDataSource(File(raw).absolutePath)
            else ->
                setDataSource(this@AlarmSoundService, android.provider.Settings.System.DEFAULT_ALARM_ALERT_URI)
        }
    }

    private fun boostAlarmVolume() {
        val manager = getSystemService(AUDIO_SERVICE) as AudioManager
        audioManager = manager
        if (previousAlarmVolume == null) {
            previousAlarmVolume = manager.getStreamVolume(AudioManager.STREAM_ALARM)
        }
        try {
            val max = manager.getStreamMaxVolume(AudioManager.STREAM_ALARM)
            if (max > 0) manager.setStreamVolume(AudioManager.STREAM_ALARM, max, 0)
        } catch (_: Exception) {
        }
    }

    private fun stopAlarmSound() {
        try {
            player?.stop()
        } catch (_: Exception) {
        }
        try {
            player?.release()
        } catch (_: Exception) {
        }
        player = null
        val previous = previousAlarmVolume
        if (previous != null) {
            try {
                audioManager?.setStreamVolume(AudioManager.STREAM_ALARM, previous, 0)
            } catch (_: Exception) {
            }
        }
        previousAlarmVolume = null
        activeAlarmId = 0
    }

    companion object {
        private const val ACTION_STOP = "com.batechnology.elderzha.STOP_ALARM_SOUND"
        private const val EXTRA_ALARM_ID = "alarmId"
        private const val EXTRA_SOUND_URL = "soundUrl"
        private const val EXTRA_TITLE = "title"
        private const val EXTRA_NOTES = "notes"
        private const val CHANNEL_ID = "elderzha_alarm_channel_v4"

        fun start(
            context: Context,
            alarmId: Int,
            soundUrl: String,
            title: String = "ElderZha reminder",
            notes: String = "Alarm is ringing.",
        ) {
            val intent = Intent(context, AlarmSoundService::class.java).apply {
                putExtra(EXTRA_ALARM_ID, alarmId)
                putExtra(EXTRA_SOUND_URL, soundUrl)
                putExtra(EXTRA_TITLE, title)
                putExtra(EXTRA_NOTES, notes)
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            val intent = Intent(context, AlarmSoundService::class.java).apply {
                action = ACTION_STOP
            }
            context.startService(intent)
        }
    }
}
