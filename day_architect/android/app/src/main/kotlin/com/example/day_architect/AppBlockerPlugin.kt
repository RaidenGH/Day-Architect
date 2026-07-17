package com.example.day_architect

import android.app.AppOpsManager
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.drawable.GradientDrawable
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.TextView
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.Calendar

/** Android-only plugin for detecting and monitoring foreground apps via UsageStatsManager. */
class AppBlockerPlugin : FlutterPlugin, MethodCallHandler {
    companion object {
        private const val LOG_TAG = "AppBlockerPlugin"
    }
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var monitoring = false

    // Default blocked app packages
    private val defaultBlockedPackages = setOf(
        "com.instagram.android",
        "com.zhiliaoapp.musically",       // TikTok
        "com.ss.android.ugc.trill",        // TikTok alternative
        "com.facebook.katana",             // Facebook
        "com.facebook.orca",               // Facebook Messenger
        "com.twitter.android",             // Twitter / X
        "com.snapchat.android",
        "com.spotify.music",
        "com.netflix.mediaclient",
        "com.google.android.youtube",
    )

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "day_architect/app_blocker")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        dismissBlockOverlay()
        channel.setMethodCallHandler(null)
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "isUsageStatsGranted" -> {
                result.success(isUsageStatsGranted())
            }
            "openUsageStatsSettings" -> {
                openUsageStatsSettings()
                result.success(true)
            }
            "getCurrentForegroundPackage" -> {
                val pkg = getCurrentForegroundPackage()
                result.success(pkg)
            }
            "startMonitoring" -> {
                monitoring = true
                result.success(true)
            }
            "stopMonitoring" -> {
                monitoring = false
                result.success(true)
            }
            "getDefaultBlockedPackages" -> {
                result.success(defaultBlockedPackages.toList())
            }
            "isBlockable" -> {
                val blocked = call.argument<List<String>>("blocked") ?: emptyList()
                val currentPkg = getCurrentForegroundPackage()
                result.success(currentPkg != null && currentPkg in blocked)
            }
            "getInstalledApps" -> {
                try {
                    val apps = getInstalledApps()
                    android.util.Log.d(LOG_TAG, "getInstalledApps: returning ${apps.size} apps")
                    result.success(apps)
                } catch (e: Exception) {
                    android.util.Log.e(LOG_TAG, "getInstalledApps: FAILED", e)
                    result.success(emptyList<Map<String, Any>>())
                }
            }
            // ======================== Overlay Freeze ========================
            "canDrawOverlays" -> {
                result.success(canDrawOverlays())
            }
            "openOverlaySettings" -> {
                openOverlaySettings()
                result.success(true)
            }
            "showBlockOverlay" -> {
                val appName = call.argument<String>("appName") ?: "Blocked app"
                showBlockOverlay(appName)
                result.success(true)
            }
            "dismissBlockOverlay" -> {
                dismissBlockOverlay()
                result.success(true)
            }
            else -> result.notImplemented()
        }
    }

    // ======================== UsageStats Detection ========================

    private fun isUsageStatsGranted(): Boolean {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return false
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            android.os.Process.myUid(),
            context.packageName
        )
        return mode == AppOpsManager.MODE_ALLOWED
    }

    private fun openUsageStatsSettings() {
        val intent = Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).apply {
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        }
        context.startActivity(intent)
    }

    private fun getCurrentForegroundPackage(): String? {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.LOLLIPOP) return null
        if (!isUsageStatsGranted()) return null

        val usm = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val calendar = Calendar.getInstance()
        val endTime = calendar.timeInMillis
        calendar.add(Calendar.MINUTE, -1)
        val startTime = calendar.timeInMillis

        val stats = usm.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, startTime, endTime)
        if (stats.isNullOrEmpty()) return null

        // Sort by last time used descending — most recent is current foreground
        val sorted = stats
            .filter { it.lastTimeUsed > 0 }
            .sortedByDescending { it.lastTimeUsed }

        return sorted.firstOrNull()?.packageName
    }

    // ======================== Installed Apps ========================

    /**
     * Returns all installed launcher apps (including system apps).
     * Each entry is a map: { packageName, displayName, iconBase64, isSystem }
     * The icon is a base64-encoded PNG loaded from the app's icon drawable.
     *
     * Uses a fixed 48dp icon size to avoid crashes on AdaptiveIconDrawable
     * (which has intrinsicWidth = -1 and can't be drawn on a tiny canvas).
     */
    private fun getInstalledApps(): List<Map<String, Any>> {
        val pm = context.packageManager
        val apps = mutableListOf<Map<String, Any>>()

        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_LAUNCHER)
        }
        val activities = pm.queryIntentActivities(intent, 0)
        android.util.Log.d(LOG_TAG, "getInstalledApps: found ${activities.size} launcher activities")

        val seen = mutableSetOf<String>()

        // Fixed icon size (48dp) — large enough for adaptive icons to render properly
        val iconSizePx: Int
        try {
            iconSizePx = (48 * context.resources.displayMetrics.density).toInt()
        } catch (e: Exception) {
            android.util.Log.e(LOG_TAG, "getInstalledApps: density lookup failed, using 48px fallback", e)
            return emptyList()
        }

        for (resolveInfo in activities) {
            val pkg = resolveInfo.activityInfo.packageName ?: continue
            if (pkg in seen) continue
            seen.add(pkg)

            val appInfo = try {
                pm.getApplicationInfo(pkg, 0)
            } catch (e: Exception) {
                null
            }
            if (appInfo == null) continue

            val isSystem = (appInfo.flags and android.content.pm.ApplicationInfo.FLAG_SYSTEM) != 0
            val displayName = pm.getApplicationLabel(appInfo).toString()

            // Load icon as base64-encoded PNG using a fixed canvas size.
            // Using drawable.intrinsicWidth/Height is unsafe because
            // AdaptiveIconDrawable returns -1 for both.
            val iconBase64 = try {
                val drawable = pm.getApplicationIcon(pkg)
                val bitmap = android.graphics.Bitmap.createBitmap(
                    iconSizePx,
                    iconSizePx,
                    android.graphics.Bitmap.Config.ARGB_8888
                )
                val canvas = android.graphics.Canvas(bitmap)
                drawable.setBounds(0, 0, iconSizePx, iconSizePx)
                drawable.draw(canvas)
                val stream = java.io.ByteArrayOutputStream()
                bitmap.compress(android.graphics.Bitmap.CompressFormat.PNG, 100, stream)
                android.util.Base64.encodeToString(stream.toByteArray(), android.util.Base64.NO_WRAP)
            } catch (e: Exception) {
                null
            }

            apps.add(mapOf(
                "packageName" to pkg,
                "displayName" to displayName,
                "iconBase64" to (iconBase64 ?: ""),
                "isSystem" to isSystem
            ))
            android.util.Log.v(LOG_TAG, "getInstalledApps: added app '$displayName' ($pkg), icon=${if (iconBase64 != null) iconBase64.length else 0} chars")
        }

        // Sort alphabetically by display name
        android.util.Log.d(LOG_TAG, "getInstalledApps: processed ${apps.size} unique apps out of ${seen.size} seen")
        apps.sortBy { it["displayName"] as String }
        return apps
    }

    // ======================== System Overlay Freeze ========================

    private var overlayView: View? = null
    private var overlayWindowManager: WindowManager? = null

    /**
     * Check whether the SYSTEM_ALERT_WINDOW overlay permission is granted.
     * On API < 23 the permission is granted at install time.
     */
    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(context)
        } else true
    }

    /** Open system settings so the user can grant overlay permission. */
    private fun openOverlaySettings() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            val intent = Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                data = android.net.Uri.parse("package:${context.packageName}")
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            context.startActivity(intent)
        }
    }

    /**
     * Show a full-screen system overlay on top of the blocked app, effectively
     * "freezing" it by covering the entire screen. The user cannot interact
     * with the blocked app while this overlay is visible.
     *
     * Requires SYSTEM_ALERT_WINDOW permission. If not granted, this is a no-op
     * (the existing notification + Flutter dialog will still work as fallback).
     */
    private fun showBlockOverlay(appName: String) {
        dismissBlockOverlay()
        if (!canDrawOverlays()) return

        try {
            val wm = context.getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val density = context.resources.displayMetrics.density

            val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                layoutFlag,
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            )

            // ======================== Build overlay view ========================

            val rootLayout = LinearLayout(context).apply {
                orientation = LinearLayout.VERTICAL
                // Dark navy at 75% opacity — covers the blocked app
                setBackgroundColor(Color.argb(191, 21, 21, 43))
                gravity = Gravity.CENTER
                isClickable = true
                isFocusable = true
                isFocusableInTouchMode = true

                // Tap anywhere to dismiss overlay + bring Day Architect to foreground
                setOnClickListener {
                    dismissBlockOverlay()
                    bringAppToForeground()
                }

                // Back press does the same
                setOnKeyListener { _, keyCode, _ ->
                    if (keyCode == KeyEvent.KEYCODE_BACK) {
                        dismissBlockOverlay()
                        bringAppToForeground()
                        true
                    } else false
                }

                // --- Content card ---
                val card = LinearLayout(context).apply {
                    orientation = LinearLayout.VERTICAL
                    gravity = Gravity.CENTER
                    setPadding(
                        (28 * density).toInt(),
                        (36 * density).toInt(),
                        (28 * density).toInt(),
                        (36 * density).toInt()
                    )

                    // Card background: rounded dark surface
                    background = GradientDrawable().apply {
                        setColor(Color.parseColor("#1F2142"))
                        cornerRadius = 24 * density
                    }

                    // Block emoji
                    addView(TextView(context).apply {
                        text = "⛔"
                        textSize = 56f
                        gravity = Gravity.CENTER
                    })

                    addView(spacer(context, 16, density))

                    // "Facebook" title
                    addView(TextView(context).apply {
                        text = appName
                        textSize = 22f
                        setTextColor(Color.WHITE)
                        gravity = Gravity.CENTER
                        typeface = android.graphics.Typeface.create(
                            "sans-serif", android.graphics.Typeface.BOLD
                        )
                    })

                    addView(spacer(context, 8, density))

                    // Subtitle
                    addView(TextView(context).apply {
                        text = "This app was blocked during\nyour focus session"
                        textSize = 14f
                        setTextColor(Color.parseColor("#8A87B0"))
                        gravity = Gravity.CENTER
                    })

                    addView(spacer(context, 28, density))

                    // "Return to Focus" button
                    val button = TextView(context).apply {
                        text = "TAP TO RETURN TO FOCUS"
                        textSize = 14f
                        setTextColor(Color.parseColor("#1F2142"))
                        gravity = Gravity.CENTER
                        typeface = android.graphics.Typeface.create(
                            "sans-serif", android.graphics.Typeface.BOLD
                        )
                        setPadding(
                            (44 * density).toInt(),
                            (16 * density).toInt(),
                            (44 * density).toInt(),
                            (16 * density).toInt()
                        )
                    }

                    // Button background: amber accent gradient
                    button.background = GradientDrawable().apply {
                        setColor(Color.parseColor("#E8935B"))
                        cornerRadius = 14 * density
                    }

                    addView(button)

                    addView(spacer(context, 14, density))

                    // Hint
                    addView(TextView(context).apply {
                        text = "or press Back to return"
                        textSize = 12f
                        setTextColor(Color.parseColor("#5A5880"))
                        gravity = Gravity.CENTER
                    })
                }

                addView(card)
            }

            wm.addView(rootLayout, params)
            overlayView = rootLayout
            overlayWindowManager = wm
        } catch (e: Exception) {
            // Overlay failed — fall back to notification + dialog (already handled
            // by FocusProvider on the Flutter side)
            e.printStackTrace()
        }
    }

    /** Remove the block overlay (if showing). Safe to call multiple times. */
    private fun dismissBlockOverlay() {
        overlayView?.let { view ->
            try {
                overlayWindowManager?.removeView(view)
            } catch (_: Exception) {
                // View may already have been removed by the system
            }
            overlayView = null
            overlayWindowManager = null
        }
    }

    /** Bring Day Architect to the foreground (above the blocked app). */
    private fun bringAppToForeground() {
        try {
            val intent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            intent?.addFlags(
                Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_SINGLE_TOP or
                Intent.FLAG_ACTIVITY_CLEAR_TOP
            )
            context.startActivity(intent)
        } catch (_: Exception) {
            // Failed to launch — the user can manually open the app
        }
    }

    /** Create a vertical spacing view. */
    private fun spacer(context: Context, dp: Int, density: Float): View {
        return View(context).apply {
            layoutParams = ViewGroup.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                (dp * density).toInt()
            )
        }
    }
}
