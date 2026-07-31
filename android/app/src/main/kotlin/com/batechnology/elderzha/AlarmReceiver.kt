package com.batechnology.elderzha

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build

class AlarmReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {

        // Handle dismiss action
        if (intent.action == ACTION_DISMISS) {
            val id = intent.getIntExtra(EXTRA_ID, 0)
            // Stop sound service — this removes foreground notification too
            AlarmSoundService.stop(context)
            // Cancel any stray notification
            if (id != 0) {
                (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager)
                    .cancel(id)
            }
            return
        }

        val id        = intent.getIntExtra(EXTRA_ID, 0)
        val title     = intent.getStringExtra(EXTRA_TITLE)     ?: "ElderZha Reminder"
        val notes     = intent.getStringExtra(EXTRA_NOTES)     ?: "It is time for your reminder."
        val type      = intent.getStringExtra(EXTRA_TYPE)      ?: "once"
        val triggerAt = intent.getLongExtra(EXTRA_TRIGGER_AT,  0L)
        val soundUrl  = intent.getStringExtra(EXTRA_SOUND_URL) ?: ""
        val imageUrl  = intent.getStringExtra(EXTRA_IMAGE_URL) ?: ""

        // Log alarm fired
        logAlarmFired(context, title, type)

        // Start AlarmSoundService — it handles:
        //   1. Playing the alarm sound
        //   2. Showing ONE foreground notification with fullScreenIntent
        //   3. fullScreenIntent auto-shows AlarmActivity over lock screen
        AlarmSoundService.start(context, id, soundUrl, title, notes, imageUrl)

        // Reschedule for next occurrence
        val next = nextTriggerAt(triggerAt, type.lowercase())
        if (next > 0L) {
            schedule(context, id, next, title, type, notes, soundUrl, imageUrl)
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

    private fun logAlarmFired(context: Context, title: String, type: String) {
        try {
            val prefs = context.getSharedPreferences(
                "${context.packageName}_preferences", Context.MODE_PRIVATE)
            val log = prefs.getStringSet("flutter.alarm_fired_log",
                mutableSetOf())?.toMutableSet() ?: mutableSetOf()
            val entry = org.json.JSONObject()
            entry.put("title", title)
            entry.put("firedAt", System.currentTimeMillis())
            entry.put("type", type)
            log.add(entry.toString())
            val trimmed = if (log.size > 30) log.drop(log.size - 30).toMutableSet() else log
            prefs.edit().putStringSet("flutter.alarm_fired_log", trimmed).apply()
        } catch (_: Exception) {}
    }

    companion object {
        const val ACTION_DISMISS         = "com.batechnology.elderzha.DISMISS_ALARM"
        const val EXTRA_ID               = "id"
        const val EXTRA_TRIGGER_AT       = "triggerAt"
        const val EXTRA_TITLE            = "title"
        const val EXTRA_TYPE             = "type"
        const val EXTRA_NOTES            = "notes"
        const val EXTRA_SOUND_URL        = "soundUrl"
        const val EXTRA_IMAGE_URL        = "imageUrl"

        fun intent(context: Context, id: Int, triggerAt: Long, title: String,
                   type: String, notes: String, soundUrl: String, imageUrl: String
        ): Intent = Intent(context, AlarmReceiver::class.java).apply {
            putExtra(EXTRA_ID, id)
            putExtra(EXTRA_TRIGGER_AT, triggerAt)
            putExtra(EXTRA_TITLE, title)
            putExtra(EXTRA_TYPE, type)
            putExtra(EXTRA_NOTES, notes)
            putExtra(EXTRA_SOUND_URL, soundUrl)
            putExtra(EXTRA_IMAGE_URL, imageUrl)
        }

        fun schedule(context: Context, id: Int, triggerAt: Long, title: String,
                     type: String, notes: String, soundUrl: String, imageUrl: String) {
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = PendingIntent.getBroadcast(
                context, id,
                intent(context, id, triggerAt, title, type, notes, soundUrl, imageUrl),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !am.canScheduleExactAlarms()) {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            } else {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pi)
            }
        }
    }
}
