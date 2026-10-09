package com.elderzha.app

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
            try { AlarmStore.acknowledge(context, id, AlarmStore.ACK_DISMISSED) } catch (_: Exception) {}
            AlarmSoundService.stop(context)
            if (id != 0) {
                val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                manager.cancel(id)
            }
            return
        }

        // A stray alarm that fires while the plan is lapsed does nothing.
        if (AlarmStore.isPaused(context)) return

        val id        = intent.getIntExtra(EXTRA_ID, 0)
        val title     = intent.getStringExtra(EXTRA_TITLE)    ?: "ElderZha reminder"
        val notes     = intent.getStringExtra(EXTRA_NOTES)    ?: "It is time for your reminder."
        val type      = intent.getStringExtra(EXTRA_TYPE)     ?: "once"
        val triggerAt = intent.getLongExtra(EXTRA_TRIGGER_AT, 0L)
        val soundUrl  = intent.getStringExtra(EXTRA_SOUND_URL) ?: ""
        val imageUrl  = intent.getStringExtra(EXTRA_IMAGE_URL) ?: ""

        // STEP 1 — keep the chain alive BEFORE doing anything that can fail.
        // This used to be the very last statement, after starting the sound
        // service and the alarm screen. If either of those threw (for
        // example Android refusing a foreground-service or background
        // activity start), onReceive exited early, the next day's alarm
        // was never scheduled, and the alarm rang exactly once and never
        // again.
        try {
            val next = nextTriggerAt(triggerAt, type.lowercase())
            if (next > 0L) {
                schedule(context, id, next, title, type, notes, soundUrl, imageUrl)
            } else {
                AlarmStore.remove(context, id) // one-off alarm: nothing left to arm
            }
        } catch (_: Exception) {}

        // STEP 2 — record that it rang (shown in Profile > Alarm history).
        try {
            AlarmStore.recordEvent(context, id, title, type, triggerAt, AlarmStore.STATUS_RANG)
        } catch (_: Exception) {}

        // STEP 3 — make noise. Each part is independent so one failure
        // (e.g. the sound service refusing to start) still leaves the
        // notification and the alarm screen.
        try {
            AlarmSoundService.start(context, id, soundUrl, title, notes, imageUrl)
        } catch (_: Exception) {}

        // Gap 7 Fix: Use goAsync() to allow background work in BroadcastReceiver
        val pendingResult = goAsync()
        Thread {
            try {
                showNotification(context, id, title, notes, imageUrl, soundUrl)
            } catch (_: Exception) {
            } finally {
                pendingResult.finish()
            }
        }.start()

        // Gap 6 Fix: Show AlarmActivity always for alarms (both locked and unlocked)
        // This is intentional for medication alarms — user MUST acknowledge
        try {
            val alarmIntent = Intent(context, AlarmActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP
                putExtra(AlarmActivity.EXTRA_TITLE, title)
                putExtra(AlarmActivity.EXTRA_NOTES, notes)
                putExtra(AlarmActivity.EXTRA_SOUND_URL, soundUrl)
                putExtra(AlarmActivity.EXTRA_IMAGE_URL, imageUrl)
                putExtra(AlarmActivity.EXTRA_PLAY_SOUND, false) // sound already started
                putExtra(AlarmActivity.EXTRA_NOTIFICATION_ID, id)
            }
            context.startActivity(alarmIntent)
        } catch (_: Exception) {}

        // STEP 4 — whenever any alarm fires, also repair the others: marks
        // any that silently never rang as missed and re-arms them.
        try {
            AlarmStore.sweepAndRearm(context)
        } catch (_: Exception) {}
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
            }
            manager.createNotificationChannel(channel) // idempotent — safe to call repeatedly
        }

        val launchIntent = Intent(context, AlarmActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                    Intent.FLAG_ACTIVITY_CLEAR_TOP or
                    Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(AlarmActivity.EXTRA_TITLE, title)
            putExtra(AlarmActivity.EXTRA_NOTES, notes)
            putExtra(AlarmActivity.EXTRA_SOUND_URL, soundUrl)
            putExtra(AlarmActivity.EXTRA_IMAGE_URL, imageUrl)
            putExtra(AlarmActivity.EXTRA_PLAY_SOUND, false)
            putExtra(AlarmActivity.EXTRA_NOTIFICATION_ID, id)
        }
        val fullScreenIntent = PendingIntent.getActivity(
            context, id, launchIntent,
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
        // R.mipmap.ic_launcher is an adaptive-icon XML on Android 8+, which
        // BitmapFactory cannot decode (it returned null, so alarms lost
        // their large icon). The launcher foreground is a real PNG.
        val defaultLargeIcon: Bitmap? = try {
            BitmapFactory.decodeResource(context.resources, R.drawable.ic_launcher_foreground)
        } catch (_: Exception) { null }
        val builder = NotificationCompat.Builder(context, CHANNEL_ID)
            .setSmallIcon(R.drawable.ic_notification)
            .setColor(android.graphics.Color.parseColor("#FFCC01"))
            .setContentTitle(title)
            .setContentText(notes.ifBlank { "Tap to open ElderZha." })
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 600, 250, 600))
            .setContentIntent(fullScreenIntent)
            .setDeleteIntent(dismissIntent) // swipe = dismiss + stop sound
            .setFullScreenIntent(fullScreenIntent, true) // always show full screen
            .setOnlyAlertOnce(true)
            .setLargeIcon(image ?: defaultLargeIcon)
            // Gap 3 Fix: Explicit "Dismiss" action button on notification
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Dismiss",
                dismissIntent
            )

        if (image != null) {
            builder.setStyle(
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
        const val ACTION_DISMISS        = "com.elderzha.app.DISMISS_ALARM"
        const val DISMISS_REQUEST_OFFSET = 500_000
        const val CHANNEL_ID            = "elderzha_alarm_channel_v4"
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
            // Plan lapsed: remember the alarm but do not arm it. It is armed
            // again by AlarmStore.resumeAll once the user renews.
            if (AlarmStore.isPaused(context)) {
                AlarmStore.upsert(context, id, triggerAt, title, type, notes, soundUrl, imageUrl)
                return
            }
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
            // Remember what is armed, natively, so boot / self-repair /
            // the history screen never depend on Flutter's preferences file.
            AlarmStore.upsert(context, id, triggerAt, title, type, notes, soundUrl, imageUrl)
        }

        fun cancelAll(context: Context) { /* managed from Flutter side */ }
    }
}
