package com.patelrmart.app

import android.content.Context
import android.os.Bundle
import android.util.Log
import com.facebook.FacebookSdk
import com.facebook.appevents.AppEventsLogger
import com.facebook.appevents.AppEventsConstants
import com.facebook.LoggingBehavior
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import org.json.JSONObject

class FacebookPixelPlugin: FlutterPlugin, MethodCallHandler {
    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private lateinit var logger: AppEventsLogger
    private var isInitialized = false

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "facebook_pixel")
        channel.setMethodCallHandler(this)
        context = binding.applicationContext
    }

    override fun onMethodCall(call: MethodCall, result: Result) {
        when (call.method) {
            "initialize" -> {
                initializeFacebookSDK(call, result)
            }
            "logEvent" -> {
                logEvent(call, result)
            }
            "setAutoLogAppEventsEnabled" -> {
                setAutoLogAppEventsEnabled(call, result)
            }
            "setAdvertiserIDCollectionEnabled" -> {
                setAdvertiserIDCollectionEnabled(call, result)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    private fun initializeFacebookSDK(call: MethodCall, result: Result) {
        try {
            val appId = call.argument<String>("appId")
            val clientToken = call.argument<String>("clientToken")
            val pixelId = call.argument<String>("pixelId")
            val displayName = call.argument<String>("displayName")
            val enableAutoLogAppEvents = call.argument<Boolean>("enableAutoLogAppEvents") ?: true
            val enableAdvertiserIdCollection = call.argument<Boolean>("enableAdvertiserIdCollection") ?: true
            val enableCodelessEvents = call.argument<Boolean>("enableCodelessEvents") ?: true
            val enableDebugLogs = call.argument<Boolean>("enableDebugLogs") ?: false

            if (appId != null && clientToken != null) {
                // Configure Facebook SDK settings
                FacebookSdk.setApplicationId(appId)
                FacebookSdk.setClientToken(clientToken)
                FacebookSdk.setAutoLogAppEventsEnabled(enableAutoLogAppEvents)
                FacebookSdk.setAdvertiserIDCollectionEnabled(enableAdvertiserIdCollection)
                
                // Enable debug logs if requested
                if (enableDebugLogs) {
                    FacebookSdk.setIsDebugEnabled(true)
                    FacebookSdk.addLoggingBehavior(LoggingBehavior.APP_EVENTS)
                }
                
                // Initialize Facebook SDK
                FacebookSdk.sdkInitialize(context) {
                    // SDK initialized successfully
                    logger = AppEventsLogger.newLogger(context)
                    isInitialized = true
                    
                    Log.d("FacebookPixel", "✅ Facebook SDK initialized successfully")
                    Log.d("FacebookPixel", "📊 Auto Log App Events: $enableAutoLogAppEvents")
                    Log.d("FacebookPixel", "📊 Advertiser ID Collection: $enableAdvertiserIdCollection")
                    Log.d("FacebookPixel", "📊 Codeless Events: $enableCodelessEvents")
                    Log.d("FacebookPixel", "📊 Debug Logs: $enableDebugLogs")
                    
                    result.success(true)
                }
            } else {
                result.error("INVALID_PARAMETERS", "App ID and Client Token are required", null)
            }
        } catch (e: Exception) {
            Log.e("FacebookPixel", "❌ Facebook SDK initialization failed: ${e.message}")
            result.error("INITIALIZATION_ERROR", e.message, null)
        }
    }

    private fun logEvent(call: MethodCall, result: Result) {
        if (!isInitialized) {
            result.error("NOT_INITIALIZED", "Facebook SDK not initialized", null)
            return
        }

        try {
            val eventName = call.argument<String>("eventName")
            val parameters = call.argument<Map<String, Any>>("parameters")
            val value = call.argument<Double>("value")
            val currency = call.argument<String>("currency")

            if (eventName != null) {
                // Create Bundle for parameters (following Facebook SDK best practices)
                val bundle = Bundle()
                
                // Convert parameters to Bundle
                if (parameters != null) {
                    for ((key, value) in parameters) {
                        when (value) {
                            is String -> bundle.putString(key, value)
                            is Int -> bundle.putInt(key, value)
                            is Long -> bundle.putLong(key, value)
                            is Float -> bundle.putFloat(key, value)
                            is Double -> bundle.putDouble(key, value)
                            is Boolean -> bundle.putBoolean(key, value)
                            is List<*> -> {
                                // Convert list to JSON string for content parameter
                                val jsonArray = org.json.JSONArray(value)
                                bundle.putString(key, jsonArray.toString())
                            }
                            else -> bundle.putString(key, value.toString())
                        }
                    }
                }

                // Add standard parameters if not already present
                if (value != null && !bundle.containsKey("value")) {
                    bundle.putDouble("value", value)
                }
                if (currency != null && !bundle.containsKey("currency")) {
                    bundle.putString("currency", currency)
                }

                // Log the event using Facebook SDK standard method
                logger.logEvent(eventName, value ?: 0.0, bundle)
                
                Log.d("FacebookPixel", "📊 Event logged: $eventName")
                Log.d("FacebookPixel", "📊 Value: $value")
                Log.d("FacebookPixel", "📊 Currency: $currency")
                Log.d("FacebookPixel", "📊 Parameters: $bundle")
                
                result.success(true)
            } else {
                result.error("INVALID_EVENT_NAME", "Event name is required", null)
            }
        } catch (e: Exception) {
            Log.e("FacebookPixel", "❌ Event logging failed: ${e.message}")
            result.error("LOGGING_ERROR", e.message, null)
        }
    }

    private fun setAutoLogAppEventsEnabled(call: MethodCall, result: Result) {
        try {
            val enabled = call.argument<Boolean>("enabled") ?: true
            FacebookSdk.setAutoLogAppEventsEnabled(enabled)
            Log.d("FacebookPixel", "📊 Auto Log App Events set to: $enabled")
            result.success(true)
        } catch (e: Exception) {
            Log.e("FacebookPixel", "❌ Failed to set Auto Log App Events: ${e.message}")
            result.error("SETTING_ERROR", e.message, null)
        }
    }

    private fun setAdvertiserIDCollectionEnabled(call: MethodCall, result: Result) {
        try {
            val enabled = call.argument<Boolean>("enabled") ?: true
            FacebookSdk.setAdvertiserIDCollectionEnabled(enabled)
            Log.d("FacebookPixel", "📊 Advertiser ID Collection set to: $enabled")
            result.success(true)
        } catch (e: Exception) {
            Log.e("FacebookPixel", "❌ Failed to set Advertiser ID Collection: ${e.message}")
            result.error("SETTING_ERROR", e.message, null)
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }
} 