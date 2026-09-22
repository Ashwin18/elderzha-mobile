package com.batechnology.elderzha

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.hardware.Sensor
import android.hardware.SensorEvent
import android.hardware.SensorEventListener
import android.hardware.SensorManager
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "alarm_service"
    private var recorder: MediaRecorder? = null
    private var recordingPath: String? = null
    private var previewPlayer: MediaPlayer? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> {
                        scheduleAlarm(
                            id = (call.argument<Number>("id") ?: 0).toInt(),
                            triggerAt = (call.argument<Number>("triggerAt") ?: 0).toLong(),
                            title = call.argument<String>("title") ?: "ElderZha reminder",
                            type = call.argument<String>("type") ?: "once",
                            notes = call.argument<String>("notes") ?: "",
                            soundUrl = call.argument<String>("soundUrl") ?: "",
                            imageUrl = call.argument<String>("imageUrl") ?: "",
                        )
                        result.success(true)
                    }
                    "cancelAlarm" -> {
                        cancelAlarm((call.argument<Number>("id") ?: 0).toInt())
                        result.success(true)
                    }
                    "cancelAllAlarms" -> {
                        // Gap 5 Fix: actually cancel all pending AlarmManager intents
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        // Cancel a range of known IDs — we use triggerAt-based IDs
                        // Flutter will cancel individually via cancelAlarm calls too
                        // This is belt-and-suspenders for orphaned alarms
                        try {
                            val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
                            val stored = prefs.getStringSet("flutter.scheduled_alarms", emptySet()) ?: emptySet()
                            for (alarmStr in stored) {
                                try {
                                    val obj = org.json.JSONObject(alarmStr)
                                    val id = obj.optInt("id", 0).takeIf { it != 0 }
                                             ?: (obj.optLong("triggerAt", 0L) and 0x7FFFFFFF).toInt()
                                    if (id != 0) {
                                        val pi = PendingIntent.getBroadcast(
                                            this, id,
                                            Intent(this, AlarmReceiver::class.java),
                                            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                                        )
                                        if (pi != null) alarmManager.cancel(pi)
                                    }
                                } catch (_: Exception) {}
                            }
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    "cancelAllAlarmsAndMonitoring" -> {
                        // Used when an account is confirmed deleted server-side —
                        // a deleted account should never keep ringing alarms or
                        // running fall/SOS monitoring in the background.
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        try {
                            val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
                            val stored = prefs.getStringSet("flutter.scheduled_alarms", emptySet()) ?: emptySet()
                            for (alarmStr in stored) {
                                try {
                                    val obj = org.json.JSONObject(alarmStr)
                                    val id = obj.optInt("id", 0).takeIf { it != 0 }
                                             ?: (obj.optLong("triggerAt", 0L) and 0x7FFFFFFF).toInt()
                                    if (id != 0) {
                                        val pi = PendingIntent.getBroadcast(
                                            this, id,
                                            Intent(this, AlarmReceiver::class.java),
                                            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE
                                        )
                                        if (pi != null) alarmManager.cancel(pi)
                                    }
                                } catch (_: Exception) {}
                            }
                            // Stop fall/SOS monitoring right now, and clear the
                            // flag BootReceiver checks — otherwise a future
                            // reboot would restart monitoring for this deleted
                            // account from local storage alone.
                            stopService(Intent(this, FallMonitorService::class.java))
                            prefs.edit().putBoolean("flutter.fall_monitor_enabled", false).apply()
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    "requestFullScreenIntentPermission" -> {
                        requestFullScreenIntentPermission()
                        result.success(true)
                    }
                    "startVoiceRecording" -> {
                        result.success(startVoiceRecording())
                    }
                    "stopVoiceRecording" -> {
                        result.success(stopVoiceRecording())
                    }
                    "playTonePreview" -> {
                        playTonePreview(call.argument<String>("path") ?: "")
                        result.success(true)
                    }
                    "stopTonePreview" -> {
                        stopTonePreview()
                        result.success(true)
                    }
                    // ── Native fall detection (survives app kill) ────────
                    "startFallMonitoring" -> {
                        val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
                        prefs.edit().putBoolean("flutter.fall_monitor_enabled", true).apply()
                        val i = Intent(this, FallMonitorService::class.java)
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(i)
                        } else {
                            startService(i)
                        }
                        result.success(true)
                    }
                    "stopFallMonitoring" -> {
                        val prefs = getSharedPreferences("${packageName}_preferences", Context.MODE_PRIVATE)
                        prefs.edit().putBoolean("flutter.fall_monitor_enabled", false).apply()
                        stopService(Intent(this, FallMonitorService::class.java))
                        result.success(true)
                    }
                    "isFallMonitoringRunning" -> result.success(FallMonitorService.isServiceRunning)
                    "testFallAlert" -> {
                        val testIntent = Intent(this, FallMonitorService::class.java).apply {
                            action = FallMonitorService.ACTION_TEST_ALERT
                        }
                        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            startForegroundService(testIntent)
                        } else {
                            startService(testIntent)
                        }
                        result.success(true)
                    }
                    "openBatterySettings" -> {
                        try {
                            startActivity(Intent(
                                Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                Uri.parse("package:$packageName")
                            ))
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    // "Alarms & reminders" — required on Android 12+ (API 31+)
                    // for setExactAndAllowWhileIdle() to actually fire on
                    // time. Without it, MainActivity.scheduleAlarm() silently
                    // falls back to setAndAllowWhileIdle() (inexact — the OS
                    // can defer it by many minutes, or drop it under Doze on
                    // some OEMs). canScheduleExactAlarms() was already being
                    // checked at schedule time, but nothing ever asked the
                    // user to grant the permission in the first place — the
                    // Dart side (AlarmScheduler.requestExactAlarmPermission)
                    // called a method name with no case here, so every call
                    // hit result.notImplemented() and was silently swallowed.
                    "canScheduleExactAlarms" -> {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        val allowed = Build.VERSION.SDK_INT < Build.VERSION_CODES.S ||
                                alarmManager.canScheduleExactAlarms()
                        result.success(allowed)
                    }
                    "requestExactAlarmPermission" -> {
                        try {
                            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                                startActivity(Intent(
                                    Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                    Uri.parse("package:$packageName")
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            }
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    // Battery optimization can pause the app's process
                    // entirely on some OEMs (Xiaomi/Vivo/Oppo/OnePlus/
                    // Samsung), which can prevent AlarmReceiver's own
                    // work (sound + notification) from completing even
                    // when AlarmManager itself fires correctly. This was
                    // also dead — only openBatterySettings (a generic
                    // app-info screen) existed, never the direct
                    // "ignore battery optimizations" system dialog.
                    "isIgnoringBatteryOptimizations" -> {
                        val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                        result.success(pm.isIgnoringBatteryOptimizations(packageName))
                    }
                    "requestBatteryOptimization" -> {
                        try {
                            val pm = getSystemService(Context.POWER_SERVICE) as android.os.PowerManager
                            if (!pm.isIgnoringBatteryOptimizations(packageName)) {
                                startActivity(Intent(
                                    Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS,
                                    Uri.parse("package:$packageName")
                                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
                            }
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    // These two functions already existed fully
                    // implemented below, but were never actually wired
                    // into this handler — meaning every Flutter call to
                    // them threw MissingPluginException, silently
                    // swallowed by a try/catch on the Dart side. This
                    // is why SOS/fall alerts were falling back to a
                    // regular tap-to-open notification on Android 14+
                    // instead of appearing full-screen immediately —
                    // the permission was never actually being checked
                    // or requested at all.
                    "canUseFullScreenIntent" -> {
                        result.success(canUseFullScreenIntent())
                    }
                    "requestFullScreenIntentPermission" -> {
                        try {
                            requestFullScreenIntentPermission()
                        } catch (_: Exception) {}
                        result.success(true)
                    }
                    // Dart's shared_preferences plugin (2.3.0+) writes to
                    // Android DataStore, not classic SharedPreferences —
                    // native code cannot read it directly anymore. Flutter
                    // explicitly hands the token over here instead, into a
                    // dedicated native-only file, so FallSOSActivity (and
                    // any other native code) can read it reliably.
                    "cacheAuthTokenNative" -> {
                        val token = call.argument<String>("token")
                        val nativePrefs = getSharedPreferences("elderzha_native_cache", Context.MODE_PRIVATE)
                        if (token.isNullOrBlank()) {
                            nativePrefs.edit().remove("auth_token").apply()
                        } else {
                            nativePrefs.edit().putString("auth_token", token).apply()
                        }
                        result.success(true)
                    }
                    // Reads the phone's own hardware step-counter sensor
                    // directly, instead of going through the `pedometer`
                    // plugin's stream — that stream can stay silent for a
                    // while after the app is killed and reopened (Android
                    // batches TYPE_STEP_COUNTER delivery and, on some
                    // OEMs, only flushes it on the next physical step),
                    // which made the Home screen's step count look frozen
                    // right after a kill. Registering our own listener
                    // here gets the sensor's current cumulative reading
                    // (steps since last reboot) as soon as it's available,
                    // so Dart can compute today's steps immediately on
                    // every app launch rather than waiting on the stream.
                    "getStepCounterReading" -> {
                        readStepCounterOnce(result)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun scheduleAlarm(
        id: Int,
        triggerAt: Long,
        title: String,
        type: String,
        notes: String,
        soundUrl: String,
        imageUrl: String,
    ) {
        if (id == 0 || triggerAt <= 0L) return
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = AlarmReceiver.intent(this, id, triggerAt, title, type, notes, soundUrl, imageUrl)
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && !alarmManager.canScheduleExactAlarms()) {
            alarmManager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
            return
        }
        alarmManager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, triggerAt, pendingIntent)
    }

    private fun cancelAlarm(id: Int) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            id,
            Intent(this, AlarmReceiver::class.java),
            PendingIntent.FLAG_NO_CREATE or PendingIntent.FLAG_IMMUTABLE,
        )
        if (pendingIntent != null) alarmManager.cancel(pendingIntent)
    }

    private fun canUseFullScreenIntent(): Boolean {
        if (Build.VERSION.SDK_INT < 34) return true
        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.canUseFullScreenIntent()
    }

    private fun requestFullScreenIntentPermission() {
        if (Build.VERSION.SDK_INT < 34) return
        val intent = Intent(Settings.ACTION_MANAGE_APP_USE_FULL_SCREEN_INTENT).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }

    private fun startVoiceRecording(): String {
        stopVoiceRecording()
        // Gap 14 Fix: store in getExternalFilesDir (persists across cache clears)
        val dir = getExternalFilesDir(null) ?: filesDir
        val file = java.io.File(dir, "elderzha_alarm_voice_${System.currentTimeMillis()}.m4a")
        recordingPath = file.absolutePath
        recorder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            MediaRecorder(this)
        } else {
            @Suppress("DEPRECATION")
            MediaRecorder()
        }.apply {
            setAudioSource(MediaRecorder.AudioSource.MIC)
            setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            setAudioEncodingBitRate(128000)
            setAudioSamplingRate(44100)
            setOutputFile(file.absolutePath)
            prepare()
            start()
        }
        return file.absolutePath
    }

    private fun stopVoiceRecording(): String {
        val path = recordingPath ?: ""
        try {
            recorder?.stop()
        } catch (_: Exception) {
        }
        try {
            recorder?.release()
        } catch (_: Exception) {
        }
        recorder = null
        recordingPath = null
        return path
    }

    private fun playTonePreview(path: String) {
        stopTonePreview()
        if (path.isBlank()) return
        previewPlayer = MediaPlayer().apply {
            setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_MUSIC)
                    .build()
            )
            if (path.startsWith("http://") || path.startsWith("https://") || path.startsWith("file://")) {
                setDataSource(this@MainActivity, Uri.parse(path))
            } else {
                setDataSource(path)
            }
            isLooping = false
            prepare()
            start()
            setOnCompletionListener { stopTonePreview() }
        }
    }

    private fun stopTonePreview() {
        try {
            previewPlayer?.stop()
        } catch (_: Exception) {
        }
        try {
            previewPlayer?.release()
        } catch (_: Exception) {
        }
        previewPlayer = null
    }

    // Registers a short-lived listener on Sensor.TYPE_STEP_COUNTER — the
    // hardware sensor that keeps counting steps since the device last
    // rebooted, regardless of whether this app's process is alive.
    //
    // TYPE_STEP_COUNTER is an on-change sensor: Android only delivers a
    // SensorEvent when the step count actually changes, not on-demand.
    // So this callback fires immediately on some devices (an event
    // waiting to be delivered), but on others has to wait for the
    // user's *next* physical step before it gets anything — there's no
    // OS API to synchronously ask "what's the count right now". A
    // shorter timeout here (was 5s) means a call that isn't going to
    // get an immediate answer gives up sooner, so the Dart side's more
    // frequent re-polling (see step_service.dart) can catch the real
    // number faster instead of one long wait blocking everything else.
    private fun readStepCounterOnce(result: MethodChannel.Result) {
        val sensorManager = getSystemService(Context.SENSOR_SERVICE) as? SensorManager
        val stepSensor = sensorManager?.getDefaultSensor(Sensor.TYPE_STEP_COUNTER)
        if (sensorManager == null || stepSensor == null) {
            result.success(-1)
            return
        }

        var responded = false
        val handler = Handler(Looper.getMainLooper())
        lateinit var listener: SensorEventListener
        val finish: (Int) -> Unit = { value ->
            if (!responded) {
                responded = true
                try { sensorManager.unregisterListener(listener) } catch (_: Exception) {}
                result.success(value)
            }
        }
        listener = object : SensorEventListener {
            override fun onSensorChanged(event: SensorEvent) {
                finish(event.values[0].toInt())
            }
            override fun onAccuracyChanged(sensor: Sensor?, accuracy: Int) {}
        }
        sensorManager.registerListener(listener, stepSensor, SensorManager.SENSOR_DELAY_NORMAL)
        handler.postDelayed({ finish(-1) }, 1500)
    }
}
