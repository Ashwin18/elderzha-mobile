package com.batechnology.elderzha

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.File
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread

class AlarmActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // Same stable window flags as the working build — just adds
        // status/nav bar hiding for a true edge-to-edge look.
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON
            )
        }
        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_ALLOW_LOCK_WHILE_SCREEN_ON
        )

        // Hide status + nav bars for edge-to-edge full screen (visual only)
        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                window.setDecorFitsSystemWindows(false)
                window.insetsController?.hide(
                    android.view.WindowInsets.Type.statusBars() or
                        android.view.WindowInsets.Type.navigationBars()
                )
            } else {
                @Suppress("DEPRECATION")
                window.decorView.systemUiVisibility = (
                    View.SYSTEM_UI_FLAG_FULLSCREEN or
                        View.SYSTEM_UI_FLAG_HIDE_NAVIGATION or
                        View.SYSTEM_UI_FLAG_IMMERSIVE_STICKY or
                        View.SYSTEM_UI_FLAG_LAYOUT_FULLSCREEN or
                        View.SYSTEM_UI_FLAG_LAYOUT_HIDE_NAVIGATION
                    )
            }
        } catch (_: Exception) {
            // If anything goes wrong, fall back silently — alarm still shows
        }

        val title = intent.getStringExtra(EXTRA_TITLE) ?: "ElderZha reminder"
        val notes = intent.getStringExtra(EXTRA_NOTES) ?: ""
        val imageUrl = intent.getStringExtra(EXTRA_IMAGE_URL) ?: ""
        val soundUrl = intent.getStringExtra(EXTRA_SOUND_URL) ?: ""
        val playSound = intent.getBooleanExtra(EXTRA_PLAY_SOUND, true)
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)

        try {
            setContentView(buildView(title, notes, imageUrl, soundUrl, notificationId))
        } catch (_: Exception) {
            // Safety net — if the themed layout ever throws, fall back to a
            // minimal screen so the alarm still shows and can be dismissed.
            setContentView(buildFallbackView(title, notificationId))
        }

        if (playSound) {
            AlarmSoundService.start(this, notificationId, soundUrl, title, notes, imageUrl)
        }
    }

    // ── Theme resolution ──────────────────────────────────────────────────
    private data class Theme(
        val bgTop: Int,
        val bgBottom: Int,
        val accentA: Int,
        val accentB: Int,
        val emoji: String,
        val okLabel: String,
    )

    private fun resolveTheme(title: String): Theme {
        val t = title.lowercase()
        return when {
            t.contains("food") || t.contains("breakfast") ||
                t.contains("lunch") || t.contains("dinner") || t.contains("meal") -> Theme(
                bgTop = 0xFF0B2A15.toInt(), bgBottom = 0xFF1B5E20.toInt(),
                accentA = 0xFFFFCC01.toInt(), accentB = 0xFF4CAF50.toInt(),
                emoji = "🍽️",
                okLabel = when {
                    t.contains("breakfast") -> "I've had my breakfast"
                    t.contains("lunch") -> "I've had my lunch"
                    t.contains("dinner") -> "I've had my dinner"
                    else -> "I've had my meal"
                },
            )
            t.contains("birthday") -> Theme(
                bgTop = 0xFF241300.toInt(), bgBottom = 0xFF4E2A00.toInt(),
                accentA = 0xFFFFCC01.toInt(), accentB = 0xFFFF5722.toInt(),
                emoji = "🎂", okLabel = "Got it, will wish them!",
            )
            t.contains("anniversary") -> Theme(
                bgTop = 0xFF241300.toInt(), bgBottom = 0xFF4E2A00.toInt(),
                accentA = 0xFFFFCC01.toInt(), accentB = 0xFFE91E63.toInt(),
                emoji = "💍", okLabel = "Got it, happy anniversary!",
            )
            else -> Theme(
                bgTop = 0xFF160A33.toInt(), bgBottom = 0xFF2D1B69.toInt(),
                accentA = 0xFFFFCC01.toInt(), accentB = 0xFFFF9500.toInt(),
                emoji = "💊", okLabel = "I've taken my medicine",
            )
        }
    }

    // ── Themed full-bleed layout ────────────────────────────────────────────
    private fun buildView(title: String, notes: String, imageUrl: String, soundUrl: String, notificationId: Int): ViewGroup {
        val theme = resolveTheme(title)

        val root = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT,
            )
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(theme.bgTop, theme.bgBottom),
            )
        }

        val scroll = ScrollView(this).apply { isFillViewport = true }

        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(28), dp(56), dp(28), dp(36))
        }

        // Date
        col.addView(TextView(this).apply {
            text = SimpleDateFormat("EEEE, d MMMM", Locale.ENGLISH)
                .format(Date()).uppercase()
            textSize = 11f
            setTextColor(Color.argb(140, 255, 255, 255))
            gravity = Gravity.CENTER
        })

        // Live time
        col.addView(TextView(this).apply {
            text = SimpleDateFormat("HH:mm", Locale.ENGLISH).format(Date())
            textSize = 54f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(4); bottomMargin = dp(18) })

        // Icon badge
        col.addView(TextView(this).apply {
            text = theme.emoji
            textSize = 44f
            gravity = Gravity.CENTER
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(theme.accentA, theme.accentB),
            ).apply { cornerRadius = dp(24).toFloat() }
            setPadding(dp(18), dp(18), dp(18), dp(18))
        }, LinearLayout.LayoutParams(dp(92), dp(92)).apply {
            gravity = Gravity.CENTER_HORIZONTAL
        })

        // Optional custom alarm image
        if (imageUrl.isNotBlank()) {
            val image = ImageView(this).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                background = GradientDrawable().apply {
                    setColor(Color.argb(30, 255, 255, 255))
                    cornerRadius = dp(16).toFloat()
                }
                clipToOutline = true
            }
            col.addView(image, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(110),
            ).apply { topMargin = dp(18) })
            loadImage(imageUrl, image)
        }

        // Title
        col.addView(TextView(this).apply {
            text = title
            textSize = 22f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(20) })

        // Notes
        if (notes.isNotBlank()) {
            col.addView(TextView(this).apply {
                text = notes
                textSize = 13f
                setTextColor(Color.argb(170, 255, 255, 255))
                gravity = Gravity.CENTER
                setLineSpacing(0f, 1.3f)
            }, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = dp(8) })
        }

        // Spacer pushes OK button toward the bottom
        col.addView(View(this), LinearLayout.LayoutParams(0, dp(40)))

        // OK button
        col.addView(TextView(this).apply {
            text = "✓  ${theme.okLabel}"
            textSize = 15f
            setTextColor(0xFF1A1726.toInt())
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable(
                GradientDrawable.Orientation.TL_BR,
                intArrayOf(theme.accentA, theme.accentB),
            ).apply { cornerRadius = dp(16).toFloat() }
            setOnClickListener {
                cancelNotification(notificationId)
                AlarmSoundService.stop(this@AlarmActivity)
                finish()
            }
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(56),
        ).apply { topMargin = dp(18) })

        // Snooze button
        col.addView(TextView(this).apply {
            text = "⏰  Snooze 5 minutes"
            textSize = 14f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                setColor(Color.argb(30, 255, 255, 255))
                cornerRadius = dp(14).toFloat()
                setStroke(dp(1), Color.argb(90, 255, 255, 255))
            }
            setOnClickListener {
                snooze(notificationId, title, notes, soundUrl, imageUrl)
            }
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(48),
        ).apply { topMargin = dp(10) })

        scroll.addView(col, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
        ))
        root.addView(scroll, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.MATCH_PARENT,
        ))
        return root
    }

    // ── Minimal fallback (only used if the themed layout throws) ───────────
    private fun buildFallbackView(title: String, notificationId: Int): ViewGroup {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(0xFF2D1B69.toInt())
            setPadding(dp(32), dp(32), dp(32), dp(32))
        }
        root.addView(TextView(this).apply {
            text = "⏰ $title"
            textSize = 20f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
        })
        root.addView(android.widget.Button(this).apply {
            text = "OK"
            setOnClickListener {
                cancelNotification(notificationId)
                AlarmSoundService.stop(this@AlarmActivity)
                finish()
            }
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT,
        ).apply { topMargin = dp(20) })
        return root
    }

    private fun snooze(notificationId: Int, title: String, notes: String, soundUrl: String, imageUrl: String) {
        cancelNotification(notificationId)
        AlarmSoundService.stop(this)
        // Distinct id from the real scheduled alarm, and from any other
        // snooze — reuses the same one-shot ('once') scheduling path
        // AlarmReceiver already supports, so it fires exactly once and
        // does not interfere with the alarm's normal recurring schedule.
        val snoozeId = ((notificationId.toLong() + 600_000L) % Int.MAX_VALUE).toInt()
        val triggerAt = System.currentTimeMillis() + 5 * 60 * 1000L
        AlarmReceiver.schedule(this, snoozeId, triggerAt, title, "once", notes, soundUrl, imageUrl)
        finish()
    }

    private fun cancelNotification(notificationId: Int) {
        if (notificationId == 0) return
        try {
            val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            manager.cancel(notificationId)
        } catch (_: Exception) {
        }
    }

    private fun loadImage(imageUrl: String, target: ImageView) {
        if (imageUrl.isBlank()) return
        thread {
            val bmp = try {
                when {
                    imageUrl.startsWith("http://") || imageUrl.startsWith("https://") ->
                        URL(imageUrl).openStream().use { android.graphics.BitmapFactory.decodeStream(it) }
                    imageUrl.startsWith("file://") ->
                        android.graphics.BitmapFactory.decodeFile(imageUrl.removePrefix("file://"))
                    File(imageUrl).exists() ->
                        android.graphics.BitmapFactory.decodeFile(imageUrl)
                    else -> null
                }
            } catch (_: Exception) {
                null
            }
            if (bmp != null) runOnUiThread { target.setImageBitmap(bmp) }
        }
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_TITLE = "title"
        const val EXTRA_NOTES = "notes"
        const val EXTRA_SOUND_URL = "soundUrl"
        const val EXTRA_IMAGE_URL = "imageUrl"
        const val EXTRA_PLAY_SOUND = "playSound"
        const val EXTRA_NOTIFICATION_ID = "notificationId"
    }
}
