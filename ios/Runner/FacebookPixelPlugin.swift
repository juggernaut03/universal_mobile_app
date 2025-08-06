import Foundation
import Flutter
import FacebookCore
import FacebookLogin

@objc class FacebookPixelPlugin: NSObject, FlutterPlugin {
    private var isInitialized = false
    
    @objc static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "facebook_pixel", binaryMessenger: registrar.messenger())
        let instance = FacebookPixelPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "initialize":
            initializeFacebookSDK(call: call, result: result)
        case "logEvent":
            logEvent(call: call, result: result)
        case "setAutoLogAppEventsEnabled":
            setAutoLogAppEventsEnabled(call: call, result: result)
        case "setAdvertiserIDCollectionEnabled":
            setAdvertiserIDCollectionEnabled(call: call, result: result)
        case "setAdvertiserTrackingEnabled":
            setAdvertiserTrackingEnabled(call: call, result: result)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
    
    private func initializeFacebookSDK(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let appId = args["appId"] as? String,
              let clientToken = args["clientToken"] as? String else {
            result(FlutterError(code: "INVALID_PARAMETERS", message: "App ID and Client Token are required", details: nil))
            return
        }
        
        let displayName = args["displayName"] as? String ?? "Patel's R Mart"
        let enableAutoLogAppEvents = args["enableAutoLogAppEvents"] as? Bool ?? true
        let enableAdvertiserIdCollection = args["enableAdvertiserIdCollection"] as? Bool ?? true
        let enableCodelessEvents = args["enableCodelessEvents"] as? Bool ?? true
        let enableDebugLogs = args["enableDebugLogs"] as? Bool ?? false
        
        // Configure Facebook SDK settings
        Settings.shared.appID = appId
        Settings.shared.clientToken = clientToken
        Settings.shared.displayName = displayName
        Settings.shared.isAdvertiserIDCollectionEnabled = enableAdvertiserIdCollection
        Settings.shared.isAutoLogAppEventsEnabled = enableAutoLogAppEvents
        Settings.shared.isCodelessEventsEnabled = enableCodelessEvents
        
        // Enable debug logs if requested
        if enableDebugLogs {
            Settings.shared.isDebugEnabled = true
        }
        
        // Initialize Facebook SDK
        ApplicationDelegate.shared.application(
            UIApplication.shared,
            didFinishLaunchingWithOptions: nil
        )
        
        isInitialized = true
        
        print("✅ Facebook SDK initialized successfully")
        print("📊 Auto Log App Events: \(enableAutoLogAppEvents)")
        print("📊 Advertiser ID Collection: \(enableAdvertiserIdCollection)")
        print("📊 Codeless Events: \(enableCodelessEvents)")
        print("📊 Debug Logs: \(enableDebugLogs)")
        
        result(true)
    }
    
    private func logEvent(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard isInitialized else {
            result(FlutterError(code: "NOT_INITIALIZED", message: "Facebook SDK not initialized", details: nil))
            return
        }
        
        guard let args = call.arguments as? [String: Any],
              let eventName = args["eventName"] as? String else {
            result(FlutterError(code: "INVALID_EVENT_NAME", message: "Event name is required", details: nil))
            return
        }
        
        let parameters = args["parameters"] as? [String: Any] ?? [:]
        let value = args["value"] as? Double
        let currency = args["currency"] as? String
        
        // Convert parameters to proper format using AppEvents.ParameterName
        var eventParameters: [AppEvents.ParameterName: Any] = [:]
        
        for (key, value) in parameters {
            if let stringValue = value as? String {
                eventParameters[AppEvents.ParameterName(key)] = stringValue
            } else if let numberValue = value as? NSNumber {
                eventParameters[AppEvents.ParameterName(key)] = numberValue
            } else if let boolValue = value as? Bool {
                eventParameters[AppEvents.ParameterName(key)] = boolValue
            } else if let arrayValue = value as? [Any] {
                // Convert array to JSON string for content parameter
                if let jsonData = try? JSONSerialization.data(withJSONObject: arrayValue),
                   let jsonString = String(data: jsonData, encoding: .utf8) {
                    eventParameters[AppEvents.ParameterName(key)] = jsonString
                }
            } else {
                eventParameters[AppEvents.ParameterName(key)] = "\(value)"
            }
        }
        
        // Add standard parameters if not already present
        if let value = value, !eventParameters.keys.contains(.value) {
            eventParameters[.value] = value
        }
        if let currency = currency, !eventParameters.keys.contains(.currency) {
            eventParameters[.currency] = currency
        }
        
        // Log the event using the new AppEvents.shared API
        AppEvents.shared.logEvent(AppEvents.Name(eventName), valueToSum: value, parameters: eventParameters)
        
        print("📊 Event logged: \(eventName)")
        print("📊 Value: \(value ?? 0)")
        print("📊 Currency: \(currency ?? "N/A")")
        print("📊 Parameters: \(eventParameters)")
        
        result(true)
    }
    
    private func setAutoLogAppEventsEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_PARAMETERS", message: "Enabled parameter is required", details: nil))
            return
        }
        
        Settings.shared.isAutoLogAppEventsEnabled = enabled
        print("📊 Auto Log App Events set to: \(enabled)")
        result(true)
    }
    
    private func setAdvertiserIDCollectionEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_PARAMETERS", message: "Enabled parameter is required", details: nil))
            return
        }
        
        Settings.shared.isAdvertiserIDCollectionEnabled = enabled
        print("📊 Advertiser ID Collection set to: \(enabled)")
        result(true)
    }
    
    private func setAdvertiserTrackingEnabled(call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard let args = call.arguments as? [String: Any],
              let enabled = args["enabled"] as? Bool else {
            result(FlutterError(code: "INVALID_PARAMETERS", message: "Enabled parameter is required", details: nil))
            return
        }
        
        Settings.shared.isAdvertiserTrackingEnabled = enabled
        print("📊 Advertiser Tracking set to: \(enabled)")
        result(true)
    }
} 