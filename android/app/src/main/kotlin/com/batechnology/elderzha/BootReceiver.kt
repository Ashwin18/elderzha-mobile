package com.batechnology.elderzha

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONObject

/**
 * BootReceiver — reschedules all alarms after phone restart.
 * Reads from Flutter DailyScheduler's SharedPreferences:
 *   key: 'scheduled_alarms' (default prefs) → List of JSON strings
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON") return

        // Read from Flutter's default SharedPreferences
        // Flutter uses: context.getSharedPreferences(packageName + "_preferences", MODE_PRIVATE)
        val packageName = context.packageName
        val prefs = context.getSharedPreferences(
            "${packageName}_preferences", Context.MODE_PRIVATE)

        val alarmsJson = prefs.getString("scheduled_alarms", null)
        if (alarmsJson.isNullOrEmpty()) return

        val now = System.currentTimeMillis()

        try {
            // scheduled_alarms is stored as JSON array string by Flutter
            // Each item is a JSON string of alarm data
            val alarmsListStr = prefs.getStringSet("flutter.scheduled_alarms", null)
                ?: prefs.getAll().entries
                    .firstOrNull { it.key.contains("scheduled_alarms") }
                    ?.let { (it.value as? String)?.let { v -> setOf(v) } }
                ?: return

            for (alarmStr in alarmsListStr) {
                try {
                    // Try parsing as JSON array (Flutter stores as stringified list)
                    val arr = JSONArray(alarmStr)
                    for (i in 0 until arr.length()) {
                        rescheduleAlarm(context, arr.getJSONObject(i), now, prefs)
                    }
                } catch (_: Exception) {
                    try {
                        rescheduleAlarm(context, JSONObject(alarmStr), now, prefs)
                    } catch (_: Exception) {}
                }
            }
        } catch (_: Exception) {}
    }

    private fun rescheduleAlarm(
        context: Context,
        alarm: JSONObject,
        now: Long,
        prefs: SharedPreferences,
    ) {
        val id        = alarm.optInt("id", 0)
        val title     = alarm.optString("title", "ElderZha Reminder")
        val type      = alarm.optString("scheduleType", "daily")
        val soundUrl  = alarm.optString("soundUrl", "")
        val imageUrl  = alarm.optString("imageUrl", "")
        val notes     = alarm.optString("notes", "")
        var triggerAt = alarm.optLong("triggerAt", 0L)

        if (id == 0 || triggerAt <= 0L) return

        triggerAt = nextFutureTrigger(triggerAt, type, now)
        if (triggerAt <= 0L) return

        AlarmReceiver.schedule(context, id, triggerAt, title, type, notes, soundUrl, imageUrl)
    }

    private fun nextFutureTrigger(triggerAt: Long, type: String, now: Long): Long {
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = triggerAt }
        while (cal.timeInMillis <= now) {
            when (type.lowercase()) {
                "daily"   -> cal.add(java.util.Calendar.DAY_OF_YEAR, 1)
                "yearly"  -> cal.add(java.util.Calendar.YEAR, 1)
                "monthly" -> cal.add(java.util.Calendar.MONTH, 1)
                else      -> return 0L
            }
        }
        return cal.timeInMillis
    }
}
