package com.batechnology.elderzha

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Build
import android.os.Bundle
import android.os.CountDownTimer
import android.os.Looper
import android.view.Gravity
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import java.util.TimeZone
import kotlin.concurrent.thread

/**
 * Native, Flutter-independent full-screen SOS alert.
 * Launched directly by FallMonitorService (also native) so it works
 * even if the Flutter app process was killed — the whole point of
 * moving fall detection to a native foreground service.
 *
 * On timeout / "Send SOS Now": calls the exact same backend endpoint
 * the Flutter app uses (POST /user/fall-alert), reading the cached
 * auth token from SharedPreferences the same way BootReceiver reads
 * scheduled_alarms.
 */
class FallSOSActivity : Activity() {

    private var timer: CountDownTimer? = null
    private var sosSent = false
    private lateinit var countdownView: TextView
    private lateinit var statusView: TextView

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
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)

        setContentView(buildView())

        timer = object : CountDownTimer(30_000, 1000) {
            override fun onTick(msUntilFinished: Long) {
                countdownView.text = (msUntilFinished / 1000).toString()
            }
            override fun onFinish() {
                countdownView.text = "0"
                sendSOS()
            }
        }.start()
    }

    override fun onDestroy() {
        timer?.cancel()
        super.onDestroy()
    }

    private fun imFine() {
        timer?.cancel()
        thread {
            try {
                postJson(
                    "/user/fall-alert/false-alarm",
                    JSONObject().apply {
                        put("responded_at", isoNow())
                    }
                )
            } catch (_: Exception) {}
        }
        finish()
    }

    private fun sendSOS() {
        if (sosSent) return
        sosSent = true
        runOnUiThread { statusView.text = "Sending SOS…" }

        fetchLocation { lat, lon ->
            thread {
                val locationUrl = if (lat != null && lon != null)
                    "https://maps.google.com/?q=$lat,$lon" else null
                val body = JSONObject().apply {
                    put("latitude", lat?.toString() ?: "")
                    put("longitude", lon?.toString() ?: "")
                    put("location_url", locationUrl ?: "")
                    put("detected_at", isoNow())
                }
                var errorMsg: String? = null
                val ok = try {
                    postJson("/user/fall-alert", body)
                    true
                } catch (e: Exception) {
                    errorMsg = e.message
                    false
                }
                runOnUiThread {
                    statusView.text = if (ok)
                        "SOS sent — family and admin notified"
                    else
                        "SOS failed: ${errorMsg ?: "unknown error"}"
                }
            }
        }
    }

    // ── Native location (no Google Play Services dependency needed) ────────
    private fun fetchLocation(callback: (Double?, Double?) -> Unit) {
        try {
            val lm = getSystemService(Context.LOCATION_SERVICE) as LocationManager
            val hasFine = checkSelfPermission(android.Manifest.permission.ACCESS_FINE_LOCATION) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
            if (!hasFine) { callback(null, null); return }

            val last = try {
                lm.getLastKnownLocation(LocationManager.GPS_PROVIDER)
                    ?: lm.getLastKnownLocation(LocationManager.NETWORK_PROVIDER)
            } catch (_: Exception) { null }

            if (last != null) { callback(last.latitude, last.longitude); return }

            var delivered = false
            val listener = object : LocationListener {
                override fun onLocationChanged(location: Location) {
                    if (delivered) return
                    delivered = true
                    callback(location.latitude, location.longitude)
                    try { lm.removeUpdates(this) } catch (_: Exception) {}
                }
            }
            val provider = if (lm.isProviderEnabled(LocationManager.GPS_PROVIDER))
                LocationManager.GPS_PROVIDER else LocationManager.NETWORK_PROVIDER
            lm.requestLocationUpdates(provider, 0L, 0f, listener, Looper.getMainLooper())

            // Give it up to 8s, then give up gracefully
            android.os.Handler(Looper.getMainLooper()).postDelayed({
                if (!delivered) {
                    delivered = true
                    try { lm.removeUpdates(listener) } catch (_: Exception) {}
                    callback(null, null)
                }
            }, 8000)
        } catch (_: Exception) {
            callback(null, null)
        }
    }

    // ── Native HTTP (no extra dependency — plain HttpURLConnection) ────────
    private fun postJson(path: String, body: JSONObject) {
        val token = readAuthToken()
            ?: throw IllegalStateException("No auth token found — user may need to log in again")
        val url = URL("https://elderzhacopy.elderzha.online/api$path")
        val conn = url.openConnection() as HttpURLConnection
        conn.requestMethod = "POST"
        conn.setRequestProperty("Content-Type", "application/json")
        conn.setRequestProperty("Accept", "application/json")
        conn.setRequestProperty("Authorization", "Bearer $token")
        conn.doOutput = true
        conn.connectTimeout = 10_000
        conn.readTimeout = 10_000
        conn.outputStream.use { it.write(body.toString().toByteArray()) }
        val code = conn.responseCode
        if (code !in 200..299) {
            val errBody = try {
                conn.errorStream?.bufferedReader()?.readText() ?: ""
            } catch (_: Exception) { "" }
            conn.disconnect()
            throw IllegalStateException("Server returned $code: $errBody")
        }
        conn.disconnect()
    }

    private fun readAuthToken(): String? {
        // Written explicitly by Flutter via 'cacheAuthTokenNative' — see
        // MainActivity.kt. Flutter's own shared_preferences plugin (2.3.0+)
        // stores in Android DataStore, which native code cannot read
        // directly, so we don't rely on that here at all.
        val nativePrefs = getSharedPreferences("elderzha_native_cache", Context.MODE_PRIVATE)
        val token = nativePrefs.getString("auth_token", null)
        if (!token.isNullOrBlank()) return token

        // Legacy fallback, in case an older Flutter plugin version on this
        // device still used classic SharedPreferences directly.
        val legacyPrefs: SharedPreferences = getSharedPreferences(
            "${packageName}_preferences", Context.MODE_PRIVATE
        )
        legacyPrefs.getString("flutter.auth_token", null)?.let { if (it.isNotBlank()) return it }
        legacyPrefs.getString("auth_token", null)?.let { if (it.isNotBlank()) return it }
        return null
    }

    private fun isoNow(): String {
        val fmt = SimpleDateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS'Z'", Locale.US)
        fmt.timeZone = TimeZone.getTimeZone("UTC")
        return fmt.format(Date())
    }

    // ── UI ───────────────────────────────────────────────────────────────
    private fun buildView(): ViewGroup {
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(0xFFB71C1C.toInt(), 0xFF7F0000.toInt())
            )
            setPadding(dp(32), dp(48), dp(32), dp(40))
        }

        root.addView(TextView(this).apply {
            text = "⚠️"
            textSize = 52f
            gravity = Gravity.CENTER
        })

        root.addView(TextView(this).apply {
            text = "Fall Detected"
            textSize = 26f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(12) })

        root.addView(TextView(this).apply {
            text = "Are you okay?"
            textSize = 16f
            setTextColor(Color.argb(200, 255, 255, 255))
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(6) })

        root.addView(TextView(this).apply {
            text = "Sending SOS in"
            textSize = 12f
            setTextColor(Color.argb(160, 255, 255, 255))
            gravity = Gravity.CENTER
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(28) })

        countdownView = TextView(this).apply {
            text = "30"
            textSize = 56f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
        }
        root.addView(countdownView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(4) })

        statusView = TextView(this).apply {
            text = ""
            textSize = 12f
            setTextColor(Color.argb(200, 255, 255, 255))
            gravity = Gravity.CENTER
        }
        root.addView(statusView, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT
        ).apply { topMargin = dp(10) })

        // spacer
        root.addView(View(this), LinearLayout.LayoutParams(0, dp(30)))

        root.addView(TextView(this).apply {
            text = "✓  I'm Fine"
            textSize = 17f
            setTextColor(0xFF2E7D32.toInt())
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                setColor(Color.WHITE)
                cornerRadius = dp(16).toFloat()
            }
            setOnClickListener { imFine() }
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(58)
        ))

        root.addView(TextView(this).apply {
            text = "Send SOS Now"
            textSize = 15f
            setTextColor(Color.WHITE)
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            background = GradientDrawable().apply {
                setColor(Color.argb(40, 255, 255, 255))
                cornerRadius = dp(14).toFloat()
                setStroke(dp(1), Color.argb(140, 255, 255, 255))
            }
            setOnClickListener { timer?.cancel(); sendSOS() }
        }, LinearLayout.LayoutParams(
            ViewGroup.LayoutParams.MATCH_PARENT, dp(50)
        ).apply { topMargin = dp(12) })

        return root
    }

    private fun dp(value: Int): Int = (value * resources.displayMetrics.density).toInt()
}
