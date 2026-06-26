package com.batechnology.elderzha

import android.app.AlarmManager
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.net.Uri
import android.os.Build
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
                        AlarmReceiver.cancelAll(this)
                        result.success(true)
                    }
                    "canUseFullScreenIntent" -> result.success(canUseFullScreenIntent())
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
        val file = java.io.File(filesDir, "elderzha_alarm_voice_${System.currentTimeMillis()}.m4a")
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
}
