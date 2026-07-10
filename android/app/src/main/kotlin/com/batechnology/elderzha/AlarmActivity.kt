package com.batechnology.elderzha

import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.Button
import android.widget.FrameLayout
import android.widget.ImageView
import android.widget.LinearLayout
import android.widget.ScrollView
import android.widget.TextView
import java.io.File
import java.net.URL
import kotlin.concurrent.thread

class AlarmActivity : Activity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

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

        val title = intent.getStringExtra(EXTRA_TITLE) ?: "ElderZha reminder"
        val notes = intent.getStringExtra(EXTRA_NOTES) ?: ""
        val imageUrl = intent.getStringExtra(EXTRA_IMAGE_URL) ?: ""
        val soundUrl = intent.getStringExtra(EXTRA_SOUND_URL) ?: ""
        val playSound = intent.getBooleanExtra(EXTRA_PLAY_SOUND, true)
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)

        setContentView(buildView(title, notes, imageUrl, notificationId))
        if (playSound) AlarmSoundService.start(this, notificationId, soundUrl, title, notes)
    }

    private fun buildView(title: String, notes: String, imageUrl: String, notificationId: Int): ViewGroup {
        val root = FrameLayout(this).apply {
            setBackgroundColor(0xAA000000.toInt())
        }
        val scroll = ScrollView(this)
        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(42, 42, 42, 34)
            background = roundedWhite()
        }

        val icon = TextView(this).apply {
            text = "🔔"
            textSize = 34f
            gravity = Gravity.CENTER
        }
        card.addView(icon)

        val image = ImageView(this).apply {
            scaleType = ImageView.ScaleType.CENTER_CROP
            setBackgroundColor(0xFFF5F3F0.toInt())
        }
        val imageParams = LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(158)
        ).apply {
            topMargin = dp(12)
            bottomMargin = dp(16)
        }
        card.addView(image, imageParams)
        loadImage(imageUrl, image)

        card.addView(TextView(this).apply {
            text = title
            textSize = 18f
            setTextColor(0xFF191725.toInt())
            gravity = Gravity.CENTER
            typeface = android.graphics.Typeface.DEFAULT_BOLD
        })

        if (notes.isNotBlank()) {
            card.addView(TextView(this).apply {
                text = notes
                textSize = 13f
                setTextColor(0xFF5F5B6B.toInt())
                gravity = Gravity.CENTER
                setPadding(0, dp(10), 0, 0)
            })
        }

        val ok = Button(this).apply {
            text = "Ok"
            textSize = 14f
            setTextColor(0xFF191725.toInt())
            background = roundedYellow()
            setOnClickListener {
                cancelNotification(notificationId)
                AlarmSoundService.stop(this)
                finish()
            }
        }
        card.addView(ok, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            dp(46)
        ).apply {
            topMargin = dp(22)
        })

        scroll.addView(card, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply {
            leftMargin = dp(28)
            rightMargin = dp(28)
        })
        root.addView(scroll, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT,
            Gravity.CENTER
        ))
        return root
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

    private fun roundedWhite() = android.graphics.drawable.GradientDrawable().apply {
        setColor(0xFFFFFFFF.toInt())
        cornerRadius = dp(18).toFloat()
    }

    private fun roundedYellow() = android.graphics.drawable.GradientDrawable().apply {
        setColor(0xFFFFCC01.toInt())
        cornerRadius = dp(24).toFloat()
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
