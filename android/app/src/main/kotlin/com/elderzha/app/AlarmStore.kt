package com.elderzha.app

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import org.json.JSONArray
import org.json.JSONObject
import java.util.Calendar

/**
 * Native, Flutter-independent record of (a) every alarm that is currently
 * armed and (b) a history of whether each one rang.
 *
 * Why this exists:
 *  - Flutter's shared_preferences plugin writes to its own file
 *    ("FlutterSharedPreferences"), but the native receivers were reading
 *    "<package>_preferences" — a different file — so after a phone
 *    restart BootReceiver found nothing to restore, and
 *    cancelAllAlarms found nothing to cancel. Keeping our own store
 *    here, written at the same moment an alarm is armed, removes that
 *    dependency entirely (same approach already used for the cached
 *    auth token: "elderzha_native_cache").
 *  - The old "alarm_fired_log" was written where Flutter could never
 *    read it, and nothing displayed it.
 *
 * An alarm that is armed has an entry in "armed" whose triggerAt is its
 * NEXT scheduled time. When it rings, AlarmReceiver advances the entry to
 * the following day, so an entry whose triggerAt is well in the past means
 * "this alarm never rang" — that is how a miss is detected, and how the
 * chain is repaired (sweepAndRearm).
 */
object AlarmStore {
    private const val PREFS = "elderzha_alarm_store"
    private const val KEY_ARMED = "armed"
    private const val KEY_EVENTS = "events"

    // How late an alarm may be (Doze can delay delivery) before it counts
    // as missed.
    private const val GRACE_MS = 3 * 60_000L
    private const val MAX_EVENTS = 200

    const val STATUS_RANG = "rang"
    const val STATUS_MISSED = "missed"

    private val lock = Any()

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    // ── Armed alarms ─────────────────────────────────────────────────────

    private fun readArmed(context: Context): JSONObject =
        try {
            JSONObject(prefs(context).getString(KEY_ARMED, "{}") ?: "{}")
        } catch (_: Exception) {
            JSONObject()
        }

    private fun writeArmed(context: Context, armed: JSONObject) {
        prefs(context).edit().putString(KEY_ARMED, armed.toString()).apply()
    }

    fun upsert(
        context: Context, id: Int, triggerAt: Long, title: String, type: String,
        notes: String, soundUrl: String, imageUrl: String,
    ) {
        if (id == 0 || triggerAt <= 0L) return
        synchronized(lock) {
            val armed = readArmed(context)
            armed.put(id.toString(), JSONObject().apply {
                put("id", id)
                put("triggerAt", triggerAt)
                put("title", title)
                put("type", type)
                put("notes", notes)
                put("soundUrl", soundUrl)
                put("imageUrl", imageUrl)
            })
            writeArmed(context, armed)
        }
    }

    fun remove(context: Context, id: Int) {
        synchronized(lock) {
            val armed = readArmed(context)
            armed.remove(id.toString())
            writeArmed(context, armed)
        }
    }

    fun contains(context: Context, id: Int): Boolean =
        synchronized(lock) { readArmed(context).has(id.toString()) }

    /** Cancels every armed alarm's pending intent and forgets them. */
    fun cancelAllArmed(context: Context) {
        synchronized(lock) {
            val armed = readArmed(context)
            val keys = armed.keys().asSequence().toList()
            for (k in keys) {
                val id = armed.optJSONObject(k)?.optInt("id", 0) ?: 0
                if (id != 0) cancelPending(context, id)
            }
            writeArmed(context, JSONObject())
        }
    }

    fun cancelPending(context: Context, id: Int) {
        try {
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pi = PendingIntent.getBroadcast(
                context, id, Intent(context, AlarmReceiver::class.java),
                PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
            )
            if (pi != null) alarmManager.cancel(pi)
        } catch (_: Exception) {}
    }

    fun clearAll(context: Context) {
        synchronized(lock) {
            cancelAllArmed(context)
            prefs(context).edit().remove(KEY_EVENTS).apply()
        }
    }

    // ── History ──────────────────────────────────────────────────────────

    private fun readEvents(context: Context): JSONArray =
        try {
            JSONArray(prefs(context).getString(KEY_EVENTS, "[]") ?: "[]")
        } catch (_: Exception) {
            JSONArray()
        }

    /**
     * One event per scheduled occurrence. "rang" replaces an earlier
     * "missed" for the same occurrence (a late-delivered alarm), never the
     * other way round.
     */
    fun recordEvent(
        context: Context, id: Int, title: String, type: String,
        scheduledFor: Long, status: String,
    ) {
        if (scheduledFor <= 0L) return
        synchronized(lock) {
            val key = "${id}_$scheduledFor"
            val old = readEvents(context)
            val list = ArrayList<JSONObject>()
            for (i in 0 until old.length()) old.optJSONObject(i)?.let { list.add(it) }

            val existing = list.indexOfFirst { it.optString("localId") == key }
            if (existing >= 0) {
                val prev = list[existing]
                if (prev.optString("status") == STATUS_RANG) return
                if (status != STATUS_RANG) return
                list.removeAt(existing)
            }
            list.add(JSONObject().apply {
                put("localId", key)
                put("alarmId", id)
                put("title", title)
                put("type", type)
                put("scheduledFor", scheduledFor)
                put("recordedAt", System.currentTimeMillis())
                put("status", status)
                put("synced", false)
            })
            list.sortBy { it.optLong("scheduledFor") }
            val trimmed = if (list.size > MAX_EVENTS) list.takeLast(MAX_EVENTS) else list
            val out = JSONArray()
            trimmed.forEach { out.put(it) }
            prefs(context).edit().putString(KEY_EVENTS, out.toString()).apply()
        }
    }

    const val ACK_OK = "ok"
    const val ACK_SNOOZED = "snoozed"
    const val ACK_DISMISSED = "dismissed"

    /**
     * The user responded to the alarm that is ringing for [id]: pressed OK,
     * snoozed, or swiped the notification away. Attached to the latest "rang"
     * event of that alarm. OK / snooze may replace a "dismissed" (a tap on the
     * notification can report a dismissal first), never the other way round.
     * The event is marked unsynced so the new detail reaches the server.
     */
    fun acknowledge(context: Context, id: Int, action: String) {
        if (id == 0) return
        synchronized(lock) {
            val arr = readEvents(context)
            var idx = -1
            var latest = -1L
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                if (o.optInt("alarmId") == id && o.optString("status") == STATUS_RANG) {
                    val at = o.optLong("recordedAt")
                    if (at >= latest) { latest = at; idx = i }
                }
            }
            if (idx < 0) return
            val o = arr.getJSONObject(idx)
            val prev = o.optString("ack", "")
            if (prev.isNotEmpty() && !(prev == ACK_DISMISSED && action != ACK_DISMISSED)) return
            o.put("ack", action)
            o.put("ackAt", System.currentTimeMillis())
            o.put("synced", false)
            prefs(context).edit().putString(KEY_EVENTS, arr.toString()).apply()
        }
    }

    fun eventsJson(context: Context): String =
        synchronized(lock) { readEvents(context).toString() }

    fun markSynced(context: Context, localIds: Set<String>) {
        if (localIds.isEmpty()) return
        synchronized(lock) {
            val arr = readEvents(context)
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                if (localIds.contains(o.optString("localId"))) o.put("synced", true)
            }
            prefs(context).edit().putString(KEY_EVENTS, arr.toString()).apply()
        }
    }

    // ── Self-repair ──────────────────────────────────────────────────────

    /** The next occurrence strictly after [now], or 0 for a one-off alarm. */
    fun nextFuture(triggerAt: Long, type: String, now: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = triggerAt }
        var guard = 0
        while (cal.timeInMillis <= now && guard++ < 4000) {
            when (type.lowercase()) {
                "daily" -> cal.add(Calendar.DAY_OF_YEAR, 1)
                "monthly" -> cal.add(Calendar.MONTH, 1)
                "yearly" -> cal.add(Calendar.YEAR, 1)
                else -> return 0L
            }
        }
        return cal.timeInMillis
    }

    /**
     * For every armed alarm:
     *  - its time passed more than GRACE_MS ago and it never rang
     *    -> record "missed", then move it to its next future time;
     *  - otherwise re-arm it with AlarmManager (idempotent: same request
     *    code replaces the existing pending intent), which repairs alarms
     *    the OS dropped (phone restart, force-stop, OEM battery killers).
     * Safe to call often.
     */
    fun sweepAndRearm(context: Context): Int {
        var rearmed = 0
        val now = System.currentTimeMillis()
        val snapshot: List<JSONObject> = synchronized(lock) {
            val armed = readArmed(context)
            armed.keys().asSequence().mapNotNull { armed.optJSONObject(it) }.toList()
        }
        for (e in snapshot) {
            try {
                val id = e.optInt("id", 0)
                var triggerAt = e.optLong("triggerAt", 0L)
                val title = e.optString("title", "ElderZha reminder")
                val type = e.optString("type", "daily")
                if (id == 0 || triggerAt <= 0L) continue

                if (triggerAt < now - GRACE_MS) {
                    recordEvent(context, id, title, type, triggerAt, STATUS_MISSED)
                    triggerAt = nextFuture(triggerAt, type, now)
                    if (triggerAt <= 0L) {
                        remove(context, id) // one-off alarm, nothing left to arm
                        continue
                    }
                } else if (triggerAt < now) {
                    continue // inside the grace window — may still be delivered
                }
                AlarmReceiver.schedule(
                    context, id, triggerAt, title, type,
                    e.optString("notes", ""), e.optString("soundUrl", ""),
                    e.optString("imageUrl", ""),
                )
                rearmed++
            } catch (_: Exception) {}
        }
        return rearmed
    }
}
