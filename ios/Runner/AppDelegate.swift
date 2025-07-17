import Flutter
import UIKit
import Firebase
import FirebaseMessaging

@main
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        print("🚀 AppDelegate: didFinishLaunchingWithOptions started")
        
        // STEP 1: Configure Firebase first
        FirebaseApp.configure()
        print("🔥 Firebase configured successfully")
        
        // STEP 2: Set up push notifications
        setupPushNotifications(application)
        
        // STEP 3: Set messaging delegate
        Messaging.messaging().delegate = self
        print("📱 Messaging delegate set")
        
        // STEP 4: Register Flutter plugins
        GeneratedPluginRegistrant.register(with: self)
        print("📦 Flutter plugins registered")
        
        let result = super.application(application, didFinishLaunchingWithOptions: launchOptions)
        print("✅ AppDelegate initialization completed")
        
        return result
    }
    
    private func setupPushNotifications(_ application: UIApplication) {
        print("📱 Setting up push notifications...")
        
        // Request notification permissions
        if #available(iOS 10.0, *) {
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: { granted, error in
                    print("📱 Notification permission granted: \(granted)")
                    if let error = error {
                        print("❌ Notification permission error: \(error)")
                    } else {
                        print("✅ Notification permissions successfully requested")
                    }
                    
                    // Register for remote notifications on main thread
                    DispatchQueue.main.async {
                        print("📱 Registering for remote notifications...")
                        application.registerForRemoteNotifications()
                    }
                }
            )
        } else {
            // iOS 9 and below
            print("📱 Using iOS 9 notification registration")
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
            application.registerForRemoteNotifications()
        }
        
        print("📱 Push notification setup completed")
    }
    
    // CRITICAL: Handle APNS token registration success
    override func application(_ application: UIApplication, 
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        let tokenParts = deviceToken.map { data in String(format: "%02.2hhx", data) }
        let token = tokenParts.joined()
        print("✅ APNS Token registered successfully")
        print("🔑 APNS Token: \(token)")
        
        // CRITICAL: Set the APNS token to Firebase Messaging
        print("🔥 Setting APNS token to Firebase Messaging...")
        Messaging.messaging().apnsToken = deviceToken
        print("✅ APNS token successfully set to Firebase Messaging")
        
        // Call super to ensure Flutter gets the token too
        super.application(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        print("📦 Super method called for Flutter integration")
    }
    
    // Handle APNS token registration failure
    override func application(_ application: UIApplication, 
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("❌ Failed to register for APNS")
        print("❌ Error: \(error.localizedDescription)")
        print("❌ Full error: \(error)")
        
        // Common causes of APNS registration failure:
        print("💡 Troubleshooting tips:")
        print("   - Ensure you're testing on a physical device, not simulator")
        print("   - Check that Push Notifications capability is enabled in Xcode")
        print("   - Verify your provisioning profile includes push notifications")
        print("   - Make sure you have a valid Apple Developer account")
        
        // Call super
        super.application(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }
    
    // Handle notification received while app is in foreground (iOS 10+)
    @available(iOS 10.0, *)
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       willPresent notification: UNNotification,
                                       withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        
        print("📱 Notification received in foreground:")
        print("   Title: \(notification.request.content.title)")
        print("   Body: \(notification.request.content.body)")
        print("   UserInfo: \(userInfo)")
        
        // Check if this is a Firebase notification
        if let messageID = userInfo["gcm.message_id"] {
            print("🔥 Firebase message ID: \(messageID)")
        }
        
        // Show notification even when app is in foreground
        if #available(iOS 14.0, *) {
            print("📱 Showing notification with banner (iOS 14+)")
            completionHandler([[.banner, .sound, .badge]])
        } else {
            print("📱 Showing notification with alert (iOS 13 and below)")
            completionHandler([[.alert, .sound, .badge]])
        }
        
        // Call super to ensure Flutter handles it
        super.userNotificationCenter(center, willPresent: notification, withCompletionHandler: completionHandler)
    }
    
    // Handle notification tap (iOS 10+)
    @available(iOS 10.0, *)
    override func userNotificationCenter(_ center: UNUserNotificationCenter,
                                       didReceive response: UNNotificationResponse,
                                       withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        
        print("🔔 Notification tapped:")
        print("   Action ID: \(response.actionIdentifier)")
        print("   UserInfo: \(userInfo)")
        
        // Handle FCM data
        if let fcmData = userInfo["gcm.message_id"] {
            print("🔥 FCM Message ID: \(fcmData)")
        }
        
        // Extract custom data for navigation
        if let customData = userInfo["data"] as? [String: Any] {
            print("📊 Custom data: \(customData)")
        }
        
        // Call super to ensure Flutter handles it
        super.userNotificationCenter(center, didReceive: response, withCompletionHandler: completionHandler)
        
        completionHandler()
    }
    
    // Handle notification received while app is in background (iOS 9 and below)
    override func application(_ application: UIApplication, 
                            didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        print("📨 Background notification received (iOS 9 style):")
        print("   UserInfo: \(userInfo)")
        
        // Handle FCM data
        if let messageID = userInfo["gcm.message_id"] {
            print("🔥 Firebase message ID: \(messageID)")
        }
        
        // Call super to ensure Flutter handles it
        super.application(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
        
        completionHandler(.newData)
    }
    
    // Handle app opened from terminated state by notification
    override func application(_ application: UIApplication, 
                            didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
        print("📬 App opened from terminated state by notification:")
        print("   UserInfo: \(userInfo)")
        
        // Call super
        super.application(application, didReceiveRemoteNotification: userInfo)
    }
}

// MARK: - MessagingDelegate
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("🔥 Firebase registration token received:")
        
        if let token = fcmToken {
            print("✅ FCM Token successfully obtained")
            print("🔑 FCM Token: \(token.prefix(20))...") // Only show first 20 chars for security
            
            // Store token for debugging
            UserDefaults.standard.set(token, forKey: "FCMToken")
            UserDefaults.standard.synchronize()
            
            // Send token change notification to Flutter
            let dataDict: [String: String] = ["token": token]
            NotificationCenter.default.post(
                name: Notification.Name("FCMToken"),
                object: nil,
                userInfo: dataDict
            )
            
            print("📡 FCM token saved and notification sent")
        } else {
            print("❌ FCM Token is nil - this indicates an issue with APNS or Firebase setup")
            print("💡 Possible causes:")
            print("   - APNS token not available yet")
            print("   - Firebase configuration mismatch")
            print("   - Network connectivity issues")
            print("   - Invalid bundle ID or project configuration")
        }
    }
    
    // REMOVED: The problematic method that used MessagingRemoteMessage
    // The MessagingDelegate protocol in modern Firebase SDK doesn't include
    // didReceive remoteMessage method with MessagingRemoteMessage parameter
    
    // If you need to handle incoming FCM messages, use the notification
    // delegate methods above (userNotificationCenter methods) which are
    // the proper way to handle notifications in modern iOS
}
