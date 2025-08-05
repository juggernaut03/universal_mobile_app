# Facebook Pixel Integration for Patel's R Mart

This module provides Facebook Pixel integration for tracking user interactions and conversions in the Patel's R Mart Flutter app.

## 📋 Prerequisites

1. **Facebook Developer Account**: Create an account at [developers.facebook.com](https://developers.facebook.com)
2. **Facebook App**: Create a new app in Facebook Developer Console
3. **Facebook Pixel**: Create a pixel in Facebook Events Manager
4. **Configuration Values**:
   - Facebook App ID
   - Facebook Client Token
   - Facebook Pixel ID

## 🔧 Setup Instructions

### 1. Update Configuration

Edit `lib/facebook_pixel/facebook_pixel_config.dart` and replace the placeholder values:

```dart
class FacebookPixelConfig {
  static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';
  static const String pixelId = 'YOUR_FACEBOOK_PIXEL_ID';
  static const String clientToken = 'YOUR_FACEBOOK_CLIENT_TOKEN';
  
  // Facebook SDK Configuration
  static const bool enableAutoLogAppEvents = true;        // Automatic app events
  static const bool enableAdvertiserIdCollection = true;  // Advertiser ID collection
  static const bool enableCodelessEvents = true;          // Codeless events
  static const bool debugMode = false;                    // Debug logging
}
```

### 2. Update Platform Configuration

#### Android (`android/app/src/main/res/values/strings.xml`):
```xml
<string name="facebook_app_id">YOUR_FACEBOOK_APP_ID</string>
<string name="facebook_client_token">YOUR_FACEBOOK_CLIENT_TOKEN</string>
```

#### iOS (`ios/Runner/Info.plist`):
```xml
<key>FacebookAppID</key>
<string>YOUR_FACEBOOK_APP_ID</string>
<key>FacebookClientToken</key>
<string>YOUR_FACEBOOK_CLIENT_TOKEN</string>
```

### 3. Initialize in Main App

Add Facebook Pixel initialization to your `main.dart`:

```dart
import 'package:patelmart/facebook_pixel/facebook_pixel_integration.dart';

void main() async {
  // ... existing initialization code ...
  
  runApp(
    ProviderScope(
      child: Consumer(
        builder: (context, ref, child) {
          // Initialize Facebook Pixel
          FacebookPixelIntegration.initialize(ref);
          
          return MyApp();
        },
      ),
    ),
  );
}
```

## 📊 Usage Examples

### Track User Authentication

```dart
// Track user login
await FacebookPixelIntegration.trackUserAuth(
  ref,
  eventType: 'login',
  userId: 'user123',
  method: 'phone',
);

// Track user signup
await FacebookPixelIntegration.trackUserAuth(
  ref,
  eventType: 'signup',
  userId: 'user123',
  method: 'email',
);
```

### Track Product Events

```dart
// Track product view
await FacebookPixelIntegration.trackProductEvent(
  ref,
  eventType: 'view',
  productId: 'prod_123',
  productName: 'Organic Bananas',
  price: 2.99,
  category: 'Fruits',
);

// Track add to cart
await FacebookPixelIntegration.trackProductEvent(
  ref,
  eventType: 'add_to_cart',
  productId: 'prod_123',
  productName: 'Organic Bananas',
  price: 2.99,
  category: 'Fruits',
  quantity: 2,
);

// Track add to wishlist
await FacebookPixelIntegration.trackProductEvent(
  ref,
  eventType: 'add_to_wishlist',
  productId: 'prod_123',
  productName: 'Organic Bananas',
  price: 2.99,
  category: 'Fruits',
);
```

### Track Checkout Events

```dart
// Track initiate checkout
await FacebookPixelIntegration.trackCheckoutEvent(
  ref,
  eventType: 'initiate',
  productIds: ['prod_123', 'prod_456'],
  totalValue: 15.99,
  numItems: 3,
);

// Track purchase
await FacebookPixelIntegration.trackCheckoutEvent(
  ref,
  eventType: 'purchase',
  productIds: ['prod_123', 'prod_456'],
  totalValue: 15.99,
  numItems: 3,
  orderId: 'order_789',
  currency: 'INR',
);
```

### Track Discovery Events

```dart
// Track category view
await FacebookPixelIntegration.trackDiscoveryEvent(
  ref,
  eventType: 'category_view',
  name: 'Fruits & Vegetables',
  id: 'cat_fruits',
);

// Track search
await FacebookPixelIntegration.trackDiscoveryEvent(
  ref,
  eventType: 'search',
  name: 'organic bananas',
  category: 'Fruits',
);
```

### Track Custom Events

```dart
// Track custom event
await FacebookPixelIntegration.trackCustomEvent(
  ref,
  eventName: 'StoreLocator',
  parameters: {
    'store_id': 'store_123',
    'store_name': 'Patel\'s R Mart - Downtown',
    'location': 'Mumbai, Maharashtra',
  },
  value: 0.0,
  currency: 'INR',
);
```

## 🏗️ Architecture

The Facebook Pixel module is designed with a modular architecture:

```
lib/facebook_pixel/
├── facebook_pixel_config.dart      # Configuration constants
├── facebook_pixel_service.dart     # Core service with platform channels
├── facebook_pixel_events.dart      # Event constants and types
├── facebook_pixel_provider.dart    # Riverpod providers
├── facebook_pixel_integration.dart # Easy-to-use integration methods
└── README.md                      # This documentation
```

### Key Components:

1. **FacebookPixelConfig**: Centralized configuration
2. **FacebookPixelService**: Core service using platform channels
3. **FacebookPixelProvider**: Riverpod integration
4. **FacebookPixelIntegration**: High-level API for easy usage

## 🔍 Debugging

Enable debug mode in `facebook_pixel_config.dart`:

```dart
static const bool debugMode = true;
```

This will log all events to the console for debugging purposes.

## 📊 Automatic Events

The Facebook SDK automatically logs these events:

- **App Install**: First time app is activated on a device
- **App Launch**: When app is launched (with 60-second deduplication)
- **In-App Purchase**: Google Play purchases (if enabled)
- **In-App Subscriptions**: Google Play subscriptions (if enabled)

## 🎛️ Manual Control

You can control Facebook SDK behavior:

```dart
// Enable/disable automatic app events
await facebookPixel.setAutoLogAppEventsEnabled(true);

// Enable/disable advertiser ID collection
await facebookPixel.setAdvertiserIDCollectionEnabled(true);

// Enable/disable advertiser tracking (iOS 14.5+)
await facebookPixel.setAdvertiserTrackingEnabled(true);
```

## 📱 iOS-Specific Features

### App Tracking Transparency (iOS 14.5+)
For iOS 14.5 and later, you must handle App Tracking Transparency:

```dart
// Request tracking permission
import 'package:app_tracking_transparency/app_tracking_transparency.dart';

// Request permission
TrackingStatus status = await AppTrackingTransparency.requestTrackingAuthorization();

// Set Facebook tracking based on permission
if (status == TrackingStatus.authorized) {
  await facebookPixel.setAdvertiserTrackingEnabled(true);
} else {
  await facebookPixel.setAdvertiserTrackingEnabled(false);
}
```

### StoreKit Integration
The Facebook SDK automatically tracks in-app purchases:
- **StoreKit 1**: All purchase types automatically logged
- **StoreKit 2**: Non-consumables, auto-renewable, and non-renewing subscriptions
- **Consumables**: Add `SKIncludeConsumableInAppPurchaseHistory` to Info.plist for automatic logging

## 📱 Platform-Specific Implementation

### Android
- Uses Facebook SDK for Android (v4.18+)
- Implemented via Kotlin plugin
- Configured in `MainActivity.kt`
- Supports automatic app events logging
- Supports advertiser ID collection
- Supports debug logging

### iOS
- Uses Facebook SDK for iOS (latest version)
- Implemented via Swift plugin
- Configured in `AppDelegate.swift`
- Supports iOS 14.5+ App Tracking Transparency
- Supports automatic app events logging
- Supports advertiser ID collection
- Supports debug logging

## 🚨 Important Notes

1. **Privacy Compliance**: Ensure compliance with privacy laws (GDPR, CCPA)
2. **User Consent**: Implement proper user consent mechanisms
3. **Data Minimization**: Only track necessary data
4. **Testing**: Test thoroughly in development before production
5. **Automatic Events**: App installs, launches, and in-app purchases are automatically logged
6. **Manual Control**: You can enable/disable automatic logging and advertiser ID collection
7. **Debug Mode**: Enable debug logs for testing, disable for production
8. **iOS 14.5+**: Supports App Tracking Transparency and device consent
9. **StoreKit Integration**: Automatic in-app purchase tracking for iOS

## 🔧 Troubleshooting

### Common Issues:

1. **SDK not initialized**: Check configuration values
2. **Events not tracking**: Verify network connectivity
3. **Platform-specific errors**: Check platform configuration files

### Debug Steps:

1. Enable debug mode
2. Check console logs
3. Verify Facebook App configuration
4. Test on physical devices (not simulators)

## 📚 Additional Resources

- [Facebook Pixel Documentation](https://developers.facebook.com/docs/facebook-pixel/)
- [Facebook SDK for Android](https://developers.facebook.com/docs/android/)
- [Facebook SDK for iOS](https://developers.facebook.com/docs/ios/)
- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels) 