package com.batechnology.elderzha

import android.animation.AnimatorSet
import android.animation.ObjectAnimator
import android.animation.ValueAnimator
import android.app.Activity
import android.app.NotificationManager
import android.content.Context
import android.graphics.BitmapFactory
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.view.Gravity
import android.view.GestureDetector
import android.view.MotionEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.view.animation.DecelerateInterpolator
import android.widget.*
import java.io.File
import java.net.URL
import java.text.SimpleDateFormat
import java.util.*
import kotlin.concurrent.thread
import kotlin.math.abs

class AlarmActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private lateinit var gestureDetector: GestureDetector
    private var pulseAnimator: AnimatorSet? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        // ── True full screen ──────────────────────────────────────────────
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
            WindowManager.LayoutParams.FLAG_FULLSCREEN or
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS or
            WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED
        )
        // Hide system bars — immersive full screen
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
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

        val title          = intent.getStringExtra(EXTRA_TITLE)           ?: "ElderZha Reminder"
        val notes          = intent.getStringExtra(EXTRA_NOTES)           ?: ""
        val imageUrl       = intent.getStringExtra(EXTRA_IMAGE_URL)       ?: ""
        val soundUrl       = intent.getStringExtra(EXTRA_SOUND_URL)       ?: ""
        val playSound      = intent.getBooleanExtra(EXTRA_PLAY_SOUND, true)
        val notificationId = intent.getIntExtra(EXTRA_NOTIFICATION_ID, 0)

        val theme = resolveTheme(title)

        val root = buildFullScreen(title, notes, imageUrl, notificationId, theme)
        setContentView(root)

        // Cancel notification from tray when AlarmActivity opens
        // So tray clears immediately — user sees full screen only
        try {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            mgr.cancel(AlarmSoundService.FOREGROUND_ID)
            if (notificationId != 0) mgr.cancel(notificationId)
        } catch (_: Exception) {}

        if (playSound) {
            AlarmSoundService.start(this, notificationId, soundUrl, title, notes, imageUrl)
        }

        // Swipe up to dismiss
        gestureDetector = GestureDetector(this, object : GestureDetector.SimpleOnGestureListener() {
            override fun onFling(e1: MotionEvent?, e2: MotionEvent, vX: Float, vY: Float): Boolean {
                if (e1 != null && (e1.y - e2.y) > 150 && abs(vY) > 300) {
                    dismiss(notificationId)
                    return true
                }
                return false
            }
        })
    }

    override fun onTouchEvent(event: MotionEvent): Boolean {
        gestureDetector.onTouchEvent(event)
        return super.onTouchEvent(event)
    }

    override fun onDestroy() {
        super.onDestroy()
        pulseAnimator?.cancel()
        handler.removeCallbacksAndMessages(null)
    }

    // ── Theme resolution ────────────────────────────────────────────────────
    data class AlarmTheme(
        val bgStart: Int, val bgEnd: Int,
        val accentStart: Int, val accentEnd: Int,
        val emoji: String, val buttonText: String,
        val typeLabel: String, val freqLabel: String,
        val isFamily: Boolean = false
    )

    private fun resolveTheme(title: String): AlarmTheme {
        val t = title.lowercase()
        return when {
            t.contains("food") || t.contains("breakfast") ||
            t.contains("lunch") || t.contains("dinner") ||
            t.contains("meal") -> AlarmTheme(
                bgStart = 0xFF071A0D.toInt(), bgEnd = 0xFF1B5E20.toInt(),
                accentStart = 0xFFFFCC01.toInt(), accentEnd = 0xFF4CAF50.toInt(),
                emoji = "🍽️",
                buttonText = when {
                    t.contains("breakfast") -> "✓  I've had my breakfast"
                    t.contains("lunch")     -> "✓  I've had my lunch"
                    t.contains("dinner")    -> "✓  I've had my dinner"
                    else                    -> "✓  I've had my meal"
                },
                typeLabel = "🍽️ Food", freqLabel = "🕐 Daily"
            )
            t.contains("birthday") -> AlarmTheme(
                bgStart = 0xFF160E00.toInt(), bgEnd = 0xFF4E2A00.toInt(),
                accentStart = 0xFFFFCC01.toInt(), accentEnd = 0xFFFF5722.toInt(),
                emoji = "🎂",
                buttonText = "🎉  Got it, will wish them!",
                typeLabel = "🎂 Birthday", freqLabel = "🔁 Yearly",
                isFamily = true
            )
            t.contains("anniversary") -> AlarmTheme(
                bgStart = 0xFF160E00.toInt(), bgEnd = 0xFF4E2A00.toInt(),
                accentStart = 0xFFFFCC01.toInt(), accentEnd = 0xFFE91E63.toInt(),
                emoji = "💍",
                buttonText = "💕  Got it, happy anniversary!",
                typeLabel = "💍 Anniversary", freqLabel = "🔁 Yearly",
                isFamily = true
            )
            else -> AlarmTheme(
                bgStart = 0xFF130A2E.toInt(), bgEnd = 0xFF2D1B69.toInt(),
                accentStart = 0xFFFFCC01.toInt(), accentEnd = 0xFFFF9500.toInt(),
                emoji = "💊",
                buttonText = "✓  I've taken my medicine",
                typeLabel = "💊 Medical", freqLabel = "🕐 Daily"
            )
        }
    }

    // ── Full screen layout ──────────────────────────────────────────────────
    private fun buildFullScreen(
        title: String, notes: String, imageUrl: String,
        notificationId: Int, theme: AlarmTheme
    ): ViewGroup {

        // Root — gradient background fills entire screen
        val root = FrameLayout(this).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
            )
            background = gradientBg(theme.bgStart, theme.bgEnd)
        }

        // Top shimmer line
        root.addView(View(this).apply {
            background = shimmerLine(theme.accentStart, theme.accentEnd)
        }, FrameLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, dp(3)))

        // ── Confetti dots for family events ──────────────────────────────
        if (theme.isFamily) {
            addConfettiDots(root, theme.accentStart, theme.accentEnd)
        }

        // ── Content column ────────────────────────────────────────────────
        val col = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
            setPadding(dp(24), dp(60), dp(24), dp(40))
        }

        // Date label
        col.addView(TextView(this).apply {
            text = SimpleDateFormat("EEEE · d MMMM yyyy", Locale.ENGLISH)
                .format(Date()).uppercase()
            textSize = 10f
            setTextColor(0x66FFFFFF)
            gravity = Gravity.CENTER
            letterSpacing = 0.15f
        })

        // Live clock
        val clockView = TextView(this).apply {
            textSize = 60f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            letterSpacing = -0.05f
        }
        updateClock(clockView)
        col.addView(clockView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(2); bottomMargin = dp(4) })

        // Tick every second
        val clockRunnable = object : Runnable {
            override fun run() {
                updateClock(clockView)
                handler.postDelayed(this, 1000)
            }
        }
        handler.postDelayed(clockRunnable, 1000)

        // ── Pulse glow ring ───────────────────────────────────────────────
        val glowRing = View(this).apply {
            background = glowCircle(theme.accentStart)
            alpha = 0.18f
        }
        val glowSize = dp(190)
        col.addView(glowRing, LinearLayout.LayoutParams(glowSize, glowSize).apply {
            topMargin = dp(8)
        })
        startPulseAnimation(glowRing)

        // ── Icon box (overlaps glow) ──────────────────────────────────────
        val iconBox = FrameLayout(this)
        val iconBg = View(this).apply {
            background = roundedGradient(theme.accentStart, theme.accentEnd, dp(26).toFloat())
            elevation = dp(12).toFloat()
        }
        val iconText = TextView(this).apply {
            text = theme.emoji
            textSize = 44f
            gravity = Gravity.CENTER
        }
        iconBox.addView(iconBg, FrameLayout.LayoutParams(dp(88), dp(88)))
        iconBox.addView(iconText, FrameLayout.LayoutParams(dp(88), dp(88)))

        col.addView(iconBox, LinearLayout.LayoutParams(dp(88), dp(88)).apply {
            topMargin = -dp(140) // pull up to overlap glow ring
            gravity = Gravity.CENTER_HORIZONTAL
        })

        // Optional alarm image (user's custom image)
        if (imageUrl.isNotBlank()) {
            val imgView = ImageView(this).apply {
                scaleType = ImageView.ScaleType.CENTER_CROP
                background = roundedRect(0x22FFFFFF, dp(16).toFloat())
            }
            col.addView(imgView, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, dp(100)
            ).apply {
                topMargin = dp(14)
                bottomMargin = dp(4)
            })
            loadImage(imageUrl, imgView)
        }

        // ── Alarm title ───────────────────────────────────────────────────
        col.addView(TextView(this).apply {
            text = title
            textSize = 22f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(20) })

        // Notes
        if (notes.isNotBlank()) {
            col.addView(TextView(this).apply {
                text = notes
                textSize = 13f
                setTextColor(Color.argb(0x99, 0xFF, 0xFF, 0xFF))
                gravity = Gravity.CENTER
                setLineSpacing(0f, 1.35f)
            }, LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT
            ).apply { topMargin = dp(8) })
        }

        // Divider
        col.addView(View(this).apply {
            setBackgroundColor(0x22FFFFFF)
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(1)
        ).apply { topMargin = dp(18); bottomMargin = dp(12) })

        // ── Info pills ────────────────────────────────────────────────────
        val pillsRow = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        pillsRow.addView(pill(theme.freqLabel, theme.accentStart))
        pillsRow.addView(View(this), LinearLayout.LayoutParams(dp(8), 0))
        pillsRow.addView(pill(theme.typeLabel, theme.accentStart))
        col.addView(pillsRow)

        // Spacer
        col.addView(View(this), LinearLayout.LayoutParams(0, 0, 1f))

        // ── Swipe hint ────────────────────────────────────────────────────
        val swipeCol = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER_HORIZONTAL
        }
        swipeCol.addView(TextView(this).apply {
            text = "SWIPE UP TO DISMISS"
            textSize = 9f
            setTextColor(0x44FFFFFF)
            gravity = Gravity.CENTER
            letterSpacing = 0.2f
        })
        swipeCol.addView(View(this).apply {
            background = roundedRect(0x44FFFFFF, dp(2).toFloat())
        }, LinearLayout.LayoutParams(dp(36), dp(3)).apply { topMargin = dp(5) })
        col.addView(swipeCol, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { bottomMargin = dp(16) })

        // ── OK Button ─────────────────────────────────────────────────────
        val btn = TextView(this).apply {
            text = theme.buttonText
            textSize = 15f
            setTextColor(0xFF1A1726.toInt())
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            background = roundedGradient(theme.accentStart, theme.accentEnd, dp(18).toFloat())
            elevation = dp(10).toFloat()
            setOnClickListener { dismiss(notificationId) }
        }
        col.addView(btn, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(58)
        ))

        // Scroll wrapper
        val scroll = ScrollView(this)
        scroll.addView(col, ViewGroup.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))
        root.addView(scroll, FrameLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT,
            ViewGroup.LayoutParams.MATCH_PARENT
        ))

        return root
    }

    // ── Helpers ─────────────────────────────────────────────────────────────

    private fun updateClock(tv: TextView) {
        tv.text = SimpleDateFormat("HH:mm", Locale.ENGLISH).format(Date())
    }

    private fun startPulseAnimation(view: View) {
        val scaleX = ObjectAnimator.ofFloat(view, "scaleX", 1f, 1.18f, 1f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = DecelerateInterpolator()
        }
        val scaleY = ObjectAnimator.ofFloat(view, "scaleY", 1f, 1.18f, 1f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = DecelerateInterpolator()
        }
        val alpha = ObjectAnimator.ofFloat(view, "alpha", 0.18f, 0.28f, 0.18f).apply {
            duration = 2000
            repeatCount = ValueAnimator.INFINITE
            repeatMode = ValueAnimator.RESTART
            interpolator = DecelerateInterpolator()
        }
        pulseAnimator = AnimatorSet().apply {
            playTogether(scaleX, scaleY, alpha)
            start()
        }
    }

    private fun addConfettiDots(root: FrameLayout, c1: Int, c2: Int) {
        val positions = listOf(
            Triple(32, 28, c1), Triple(60, 50, c2), Triple(80, 80, c1),
            Triple(210, 40, c2), Triple(190, 70, c1), Triple(230, 90, c2),
            Triple(50, 120, c2), Triple(220, 120, c1)
        )
        positions.forEachIndexed { i, (x, y, color) ->
            val size = dp(5 + (i % 3) * 2)
            root.addView(View(this).apply {
                background = circleDrawable(color)
                alpha = 0.5f + (i % 3) * 0.15f
                animate().translationY(-dp(10).toFloat())
                    .setDuration(1500)
                    .setStartDelay(i * 200L)
                    .setInterpolator(DecelerateInterpolator())
                    .withEndAction {
                        animate().translationY(0f).setDuration(1500)
                            .setInterpolator(DecelerateInterpolator())
                            .start()
                    }.start()
            }, FrameLayout.LayoutParams(size, size).apply {
                leftMargin = dp(x); topMargin = dp(y)
            })
        }
    }

    private fun dismiss(notificationId: Int) {
        try {
            val mgr = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            // Cancel both the alarm notification ID and fixed foreground ID
            if (notificationId != 0) mgr.cancel(notificationId)
            mgr.cancel(AlarmSoundService.FOREGROUND_ID) // fixed foreground notification
        } catch (_: Exception) {}
        // Stop service (this stops sound + removes foreground notification)
        AlarmSoundService.stop(this)
        finish()
    }

    private fun loadImage(url: String, target: ImageView) {
        if (url.isBlank()) return
        thread {
            val bmp = try {
                when {
                    url.startsWith("http://") || url.startsWith("https://") ->
                        URL(url).openStream().use { BitmapFactory.decodeStream(it) }
                    url.startsWith("file://") ->
                        BitmapFactory.decodeFile(url.removePrefix("file://"))
                    File(url).exists() -> BitmapFactory.decodeFile(url)
                    else -> null
                }
            } catch (_: Exception) { null }
            if (bmp != null) runOnUiThread { target.setImageBitmap(bmp) }
        }
    }

    // ── Drawables ────────────────────────────────────────────────────────────
    private fun gradientBg(start: Int, end: Int) =
        GradientDrawable(GradientDrawable.Orientation.TOP_BOTTOM, intArrayOf(start, end, start))
            .apply { gradientType = GradientDrawable.LINEAR_GRADIENT }

    private fun shimmerLine(c1: Int, c2: Int) =
        GradientDrawable(GradientDrawable.Orientation.LEFT_RIGHT,
            intArrayOf(Color.TRANSPARENT, c1, c2, Color.TRANSPARENT))

    private fun glowCircle(color: Int) = GradientDrawable().apply {
        shape = GradientDrawable.OVAL
        val c = Color.argb(80,
            Color.red(color), Color.green(color), Color.blue(color))
        colors = intArrayOf(c, Color.TRANSPARENT)
        gradientType = GradientDrawable.RADIAL_GRADIENT
    }

    private fun roundedGradient(c1: Int, c2: Int, radius: Float) =
        GradientDrawable(GradientDrawable.Orientation.TL_BR, intArrayOf(c1, c2)).apply {
            cornerRadius = radius
        }

    private fun roundedRect(color: Int, radius: Float) =
        GradientDrawable().apply { setColor(color); cornerRadius = radius }

    private fun circleDrawable(color: Int) =
        GradientDrawable().apply { shape = GradientDrawable.OVAL; setColor(color) }

    private fun pill(label: String, accentColor: Int): TextView = TextView(this).apply {
        text = label
        textSize = 10f
        val c = Color.argb(50,
            Color.red(accentColor), Color.green(accentColor), Color.blue(accentColor))
        background = roundedRect(c, dp(20).toFloat())
        setTextColor(0xCCFFFFFF.toInt())
        setPadding(dp(12), dp(5), dp(12), dp(5))
        typeface = Typeface.DEFAULT_BOLD
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    companion object {
        const val EXTRA_TITLE           = "title"
        const val EXTRA_NOTES           = "notes"
        const val EXTRA_SOUND_URL       = "soundUrl"
        const val EXTRA_IMAGE_URL       = "imageUrl"
        const val EXTRA_PLAY_SOUND      = "playSound"
        const val EXTRA_NOTIFICATION_ID = "notificationId"
    }
}
