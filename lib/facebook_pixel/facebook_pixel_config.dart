/// Facebook Pixel Configuration
/// This file contains all the configuration constants for Facebook Pixel integration
class FacebookPixelConfig {
  // Facebook App ID - Replace with your actual Facebook App ID
  static const String facebookAppId = 'YOUR_FACEBOOK_APP_ID';
  
  // Facebook Pixel ID - Replace with your actual Pixel ID
  static const String pixelId = 'YOUR_FACEBOOK_PIXEL_ID';
  
  // Facebook Client Token - Replace with your actual Client Token
  static const String clientToken = 'YOUR_FACEBOOK_CLIENT_TOKEN';
  
  // Enable/Disable Facebook Pixel tracking
  static const bool enableTracking = true;
  
  // Enable/Disable debug mode
  static const bool debugMode = false;
  
  // Facebook SDK Configuration
  static const bool enableAutoLogAppEvents = true;
  static const bool enableAdvertiserIdCollection = true;
  static const bool enableCodelessEvents = true;
  
  // Custom events configuration
  static const Map<String, String> customEvents = {
    'app_launch': 'AppLaunch',
    'user_login': 'UserLogin',
    'user_signup': 'UserSignUp',
    'product_view': 'ViewContent',
    'add_to_cart': 'AddToCart',
    'initiate_checkout': 'InitiateCheckout',
    'purchase': 'Purchase',
    'search': 'Search',
    'add_to_wishlist': 'AddToWishlist',
    'view_category': 'ViewCategory',
    'contact': 'Contact',
    'customize_product': 'CustomizeProduct',
    'donate': 'Donate',
    'find_location': 'FindLocation',
    'schedule': 'Schedule',
    'start_order': 'StartOrder',
    'subscribe': 'Subscribe',
    'ad_click': 'AdClick',
    'ad_impression': 'AdImpression',
  };
  
  // Standard parameters for events
  static const Map<String, String> standardParameters = {
    'content_type': 'product',
    'currency': 'INR',
    'value': '0.00',
  };
} 