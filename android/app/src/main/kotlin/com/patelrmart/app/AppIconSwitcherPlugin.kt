package com.patelrmart.app

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.util.Log
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/**
 * Switches the launcher icon between the variants baked into this build at
 * compile time (see AndroidManifest.xml's activity-alias entries) — no new
 * APK, no Play Store update. Every variant already ships inside the binary;
 * this just flips which alias is enabled, matching how apps like Zomato swap
 * icons for a festival/campaign without a release.
 *
 * Every variant is a <activity-alias> pointing at the same MainActivity, each
 * with its own android:icon. Exactly one may be enabled at a time — the real
 * MainActivity itself carries no LAUNCHER intent-filter of its own, so the
 * currently-enabled alias is the only thing showing up as "the" app icon.
 */
class AppIconSwitcherPlugin : FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "app_icon_switcher")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "setIcon" -> setIcon(call, result)
            else -> result.notImplemented()
        }
    }

    private fun setIcon(call: MethodCall, result: Result) {
        val variant = call.argument<String>("variant") ?: "default"
        val alias = ALIASES[variant]
        if (alias == null) {
            result.error("UNKNOWN_VARIANT", "No icon alias registered for '$variant'", null)
            return
        }

        try {
            val pm = context.packageManager
            for ((otherVariant, otherAlias) in ALIASES) {
                val state = if (otherVariant == variant) {
                    PackageManager.COMPONENT_ENABLED_STATE_ENABLED
                } else {
                    PackageManager.COMPONENT_ENABLED_STATE_DISABLED
                }
                pm.setComponentEnabledSetting(
                    ComponentName(context.packageName, "$PACKAGE.$otherAlias"),
                    state,
                    PackageManager.DONT_KILL_APP
                )
            }
            Log.d("AppIconSwitcher", "Switched launcher icon to '$variant'")
            result.success(true)
        } catch (e: Exception) {
            Log.e("AppIconSwitcher", "Failed to switch icon to '$variant': ${e.message}")
            result.error("SWITCH_FAILED", e.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    companion object {
        private const val PACKAGE = "com.patelrmart.app.icons"

        // Must match the activity-alias android:name entries in AndroidManifest.xml.
        private val ALIASES = mapOf(
            "default" to "DefaultIcon",
            "festival" to "FestivalIcon",
            "premium" to "PremiumIcon"
        )
    }
}
