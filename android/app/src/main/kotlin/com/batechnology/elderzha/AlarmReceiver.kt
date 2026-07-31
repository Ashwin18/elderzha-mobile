package com.batechnology.elderzha

import android.app.AlarmManager
import android.app.KeyguardManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.os.Build
import androidx.core.app.NotificationCompat
import java.io.File
import java.net.URL

class AlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_DISMISS) {
            val id = intent.getIntExtra(EXTRA_ID, 0)
            AlarmSoundService.stop(context)
            if (id != 0) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.cancel(id)
            }
            return
        }

        val id        = intent.getIntExtra(EXTRA_ID, 0)
        val title     = intent.getStringExtra(EXTRA_TITLE)    ?: "ElderZha reminder"
        val notes     = intent.getStringExtra(EXTRA_NOTES)    ?: "It is time for your reminder."
        val type      = intent.getStringExtra(EXTRA_TYPE)     ?: "once"
        val triggerAt = intent.getLongExtra(EXTRA_TRIGGER_AT, 0L)
        val soundUrl  = intent.getStringExtra(EXTRA_SOUND_URL) ?: ""
        val imageUrl  = intent.getStringExtra(EXTRA_IMAGE_URL) ?: ""

        // Gap 12 Fix: Log alarm fired for history
        try {
            val prefs = context.getSharedPreferences("${context.packageName}_preferences", android.content.Context.MODE_PRIVATE)
            val log = prefs.getStringSet("flutter.alarm_fired_log", mutableSetOf())?.toMutableSet() ?: mutableSetOf()
            val entry = org.json.JSONObject()
            entry.put("title", title)
            entry.put("firedAt", System.currentTimeMillis())
            entry.put("type", type)
            log.add(entry.toString())
            // Keep only last 30 entries
            val trimmed = if (log.size > 30) log.drop(log.size - 30).toMutableSet() else log
            prefs.edit().putStringSet("flutter.alarm_fired_log", trimmed).apply()
        } catch (_: Exception) {}

        // Start sound service first
        AlarmSoundService.start(context, id, soundUrl, title, notes, imageUrl)

        // Show notification with fullScreenIntent (correct way to show AlarmActivity)
        // fullScreenIntent works on BOTH locked and unlocked screens
        // Android 10+ blocks startActivity() from BroadcastReceiver background
        val pendingResult = goAsync()
        Thread {
            try {
                showNotification(context, id, title, notes, imageUrl, soundUrl)
            } finally {
                pendingResult.finish()
            }
        }.start()

        // Reschedule for next occurrence
        val nextTriggerAt = nextTriggerAt(triggerAt, type.lowercase())
        if (nextTriggerAt > 0L) {
            schedule(context, id, nextTriggerAt, title, type, notes, soundUrl, imageUrl)
        }
    }

    private fun nextTriggerAt(triggerAt: Long, type: String): Long {
        if (triggerAt <= 0L) return 0L
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = triggerAt }
        when (type) {
            "daily"   -> cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
            "monthly" -> cal.add(java.util.Calendar.MONTH, 1)
            "yearly"  -> cal.add(java.util.Calendar.YEAR, 1)
            else      -> return 0L
        }
        while (cal.timeInMillis <= System.currentTimeMillis()) {
            when (type) {
                "daily"   -> cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
                "monthly" -> cal.add(java.util.Calendar.MONTH, 1)
                "yearly"  -> cal.add(java.util.Calendar.YEAR, 1)
            }
        }
        return cal.timeInMillis
    }

    private fun showNotification(
        context: Context,
        id: Int,
        title: String,
        notes: String,
        imageUrl: String,
        soundUrl: String,
    ) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID, "ElderZha Alarms",
                NotificationManager.IMPORTANCE_HIGH,
            ).apply {
                description = "Medical, food, and family reminders"
                enableVibration(true)
                setSound(null, null)
                // Allow full screen intent to bypass DND
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            // Also create a MAX importance channel for alarm full screen
            val alarmChannel = NotificationChannel(
                ALARM_CHANNEL_ID, "ElderZha Alarm Fullscreen",
                NotificationManager.IMPORTANCE_MAX,
            ).apply {
                description = "Full screen alarm alerts"
                enableVibration(true)
                setSound(null, null)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            manager.createNotificationChannel(alarmChannel)
            manager.createNotificationChannel(channel) // idempotent — safe to call repeatedly
        }

        // fullScreenIntent — shows AlarmActivity over lock screen AND when unlocked
        val launchIntent = Intent(context, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP or
                    Intent.FLAG_ACTIVITY_NO_HISTORY
            putExtra(AlarmActivity.EXTRA_TITLE, title)
            putExtra(AlarmActivity.EXTRA_NOTES, notes)
            putExtra(AlarmActivity.EXTRA_SOUND_URL, soundUrl)
            putExtra(AlarmActivity.EXTRA_IMAGE_URL, imageUrl)
            putExtra(AlarmActivity.EXTRA_PLAY_SOUND, false) // sound already started by service
            putExtra(AlarmActivity.EXTRA_NOTIFICATION_ID, id)
        }
        val fullScreenIntent = PendingIntent.getActivity(
            context, id + 100_000, launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        // Gap 3 Fix: Dismiss action button on notification
        val dismissIntent = PendingIntent.getBroadcast(
            context,
            id + DISMISS_REQUEST_OFFSET,
            Intent(context, AlarmReceiver::class.java).apply {
                action = ACTION_DISMISS
                putExtra(EXTRA_ID, id)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val image = loadBitmap(imageUrl)
        // Use MAX importance channel for full screen
        val builder = NotificationCompat.Builder(context, ALARM_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle(title)
            .setContentText(notes.ifBlank { "Tap Dismiss to stop alarm" })
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(false)   // keep showing until dismissed
            .setOngoing(true)       // can't be swiped away accidentally
            .setVibrate(longArrayOf(0, 600, 250, 600))
            // contentIntent = dismiss (NOT open AlarmActivity — causes cache issue)
            .setContentIntent(dismissIntent)
            .setDeleteIntent(dismissIntent)
            // fullScreenIntent = opens AlarmActivity over lock screen automatically
            .setFullScreenIntent(fullScreenIntent, true)
            // Dismiss button in notification
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Dismiss Alarm",
                dismissIntent
            )

        if (image != null) {
            builder
                .setLargeIcon(image)
                .setStyle(
                    NotificationCompat.BigPictureStyle()
                        .bigPicture(image)
                        .bigLargeIcon(null as Bitmap?)
                )
        }

        manager.notify(id, builder.build())
    }

    private fun loadBitmap(imageUrl: String): Bitmap? {
        if (imageUrl.isBlank()) return null
        return try {
            when {
                imageUrl.startsWith("http://") || imageUrl.startsWith("https://") ->
                    URL(imageUrl).openStream().use { BitmapFactory.decodeStream(it) }
                imageUrl.startsWith("file://") ->
                    BitmapFactory.decodeFile(imageUrl.removePrefix("file://"))
                File(imageUrl).exists() ->
                    BitmapFactory.decodeFile(imageUrl)
                else -> null
            }
        } catch (_: Exception) { null }
    }

    companion object {
        const val ACTION_DISMISS        = "com.batechnology.elderzha.DISMISS_ALARM"
        const val DISMISS_REQUEST_OFFSET = 500_000
        const val CHANNEL_ID            = "elderzha_alarm_channel_v4"
        const val ALARM_CHANNEL_ID      = "elderzha_alarm_fullscreen_v1"
        const val EXTRA_ID              = "id"
        const val EXTRA_TRIGGER_AT      = "triggerAt"
        const val EXTRA_TITLE           = "title"
        const val EXTRA_TYPE            = "type"
        const val EXTRA_NOTES           = "notes"
        const val EXTRA_SOUND_URL       = "soundUrl"
        const val EXTRA_IMAGE_URL       = "imageUrl"

        fun intent(context: Context, id: Int, triggerAt: Long, title: String,
                   type: String, notes: String, soundUrl: String, imageUrl: String
        ): Intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(EXTRA_ID, id); putExtra(EXTRA_TRIGGER_AT, triggerAt)
            putExtra(EXTRA_TITLE, title); putExtra(EXTRA_TYPE, type)
            putExtra(EXTRA_NOTES, notes); putExtra(EXTRA_SOUND_URL, soundUrl)
            putExtra(EXTRA_IMAGE_URL, imageUrl)
        }

        fun schedule(context: Context, id: Int, triggerAt: Long, title: String,
                     type: String, notes: String, soundUrl: String, imageUrl: String) {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pendingIntent = PendingIntent.getBroadcast(
                context, id,
                intent(context, id, triggerAt, title, type, notes, soundUrl, imageUrl),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
                alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            } else {
                alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            }
        }

        fun cancelAll(context: Context) { /* managed from Flutter side */ }
    }
}
