package com.batechnology.elderzha

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import org.json.JSONArray
import org.json.JSONException
import org.json.JSONObject

/**
 * BootReceiver — reschedules all alarms after phone restart.
 *
 * Gap 3 Fix: Flutter stores scheduled_alarms as StringList via
 * SharedPreferences.setStringList() which uses a Set<String> internally.
 * Must be read via getStringSet(), not getString().
 */
class BootReceiver : BroadcastReceiver() {

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action != Intent.ACTION_BOOT_COMPLETED &&
            intent.action != "android.intent.action.QUICKBOOT_POWERON") return

        // Flutter SharedPreferences stores data in:
        // <packageName>_preferences (Flutter SDK default)
        val packageName = context.packageName
        val prefs = context.getSharedPreferences(
            "${packageName}_preferences", Context.MODE_PRIVATE)

        val now = System.currentTimeMillis()

        // Gap 3 Fix: Flutter setStringList stores as Set<String> internally
        // The actual key has "flutter." prefix added by the Flutter plugin
        val alarmStrings = getFlutterStringList(prefs, "scheduled_alarms")
        if (alarmStrings.isEmpty()) return

        for (alarmStr in alarmStrings) {
            try {
                val alarm = JSONObject(alarmStr)
                rescheduleAlarm(context, alarm, now)
            } catch (_: JSONException) {}
        }
    }

    private fun getFlutterStringList(prefs: SharedPreferences, key: String): List<String> {
        // Flutter stores StringList with "flutter." prefix
        val flutterKey = "flutter.$key"
        // Try as Set<String> first (how Flutter stores StringList)
        val asSet = try { prefs.getStringSet(flutterKey, null) } catch (_: Exception) { null }
        if (asSet != null) return asSet.toList()

        // Try without prefix
        val asSet2 = try { prefs.getStringSet(key, null) } catch (_: Exception) { null }
        if (asSet2 != null) return asSet2.toList()

        // Try as plain string (JSON array format)
        val asStr = prefs.getString(flutterKey, null) ?: prefs.getString(key, null)
        if (asStr != null) {
            return try {
                val arr = JSONArray(asStr)
                (0 until arr.length()).map { arr.getString(it) }
            } catch (_: Exception) { emptyList() }
        }
        return emptyList()
    }

    private fun rescheduleAlarm(context: Context, alarm: JSONObject, now: Long) {
        val id        = alarm.optInt("id", 0).takeIf { it != 0 }
                        ?: (alarm.optLong("triggerAt", 0L) and 0x7FFFFFFF).toInt()
        val title     = alarm.optString("title", "ElderZha Reminder")
        val type      = alarm.optString("scheduleType", "daily")
        val soundUrl  = alarm.optString("soundUrl", "")
        val imageUrl  = alarm.optString("imageUrl", "")
        val notes     = alarm.optString("notes", "")
        var triggerAt = alarm.optLong("triggerAt", 0L)

        if (id == 0 || triggerAt <= 0L) return

        // Advance to next future trigger
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
                else      -> return 0L // 'once' — don't reschedule
            }
        }
        return cal.timeInMillis
    }
}
