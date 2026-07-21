package com.batechnology.elderzha

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences

/**
 * BootReceiver — reschedules all alarms after phone restart.
 * Android clears all AlarmManager alarms on reboot.
 * This receiver fires on BOOT_COMPLETED and reschedules from SharedPreferences.
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON") return

        val prefs: SharedPreferences = context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE)
        val masterEnabled = prefs.getBoolean("alarms_enabled", true)
        if (!masterEnabled) return

        val alarmIds = prefs.getStringSet("alarm_ids", emptySet()) ?: return
        val now = System.currentTimeMillis()

        for (idStr in alarmIds) {
            val id       = idStr.toLongOrNull() ?: continue
            val title    = prefs.getString("alarm_${id}_title",    "ElderZha Reminder") ?: continue
            val type     = prefs.getString("alarm_${id}_type",     "daily")              ?: "daily"
            val soundUrl = prefs.getString("alarm_${id}_soundUrl", "")                   ?: ""
            val imageUrl = prefs.getString("alarm_${id}_imageUrl", "")                   ?: ""
            val notes    = prefs.getString("alarm_${id}_notes",    "")                   ?: ""
            val date     = prefs.getString("alarm_${id}_date",     "")                   ?: ""
            var triggerAt = prefs.getLong("alarm_${id}_triggerAt", 0L)

            if (triggerAt <= 0L) continue

            // Compute next valid trigger time
            triggerAt = nextFutureTrigger(triggerAt, type, now)
            if (triggerAt <= 0L) continue

            // Reschedule via AlarmReceiver
            AlarmReceiver.schedule(
                context,
                id.toInt(),
                triggerAt,
                title,
                type,
                notes,
                soundUrl,
                imageUrl,
            )

            // Update stored trigger time
            prefs.edit().putLong("alarm_${id}_triggerAt", triggerAt).apply()
        }
    }

    private fun nextFutureTrigger(triggerAt: Long, type: String, now: Long): Long {
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = triggerAt }
        while (cal.timeInMillis <= now) {
            when (type.lowercase()) {
                "daily"   -> cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
                "yearly"  -> cal.add(java.util.Calendar.YEAR, 1)
                "monthly" -> cal.add(java.util.Calendar.MONTH, 1)
                else      -> return 0L // "once" alarms don't repeat
            }
        }
        return cal.timeInMillis
    }
}
