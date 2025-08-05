/// Facebook Pixel Events
/// Defines event constants and types for Facebook Pixel tracking
class FacebookPixelEvents {
  // Standard Facebook Pixel Events
  static const String appLaunch = 'AppLaunch';
  static const String userLogin = 'UserLogin';
  static const String userSignUp = 'UserSignUp';
  static const String viewContent = 'ViewContent';
  static const String addToCart = 'AddToCart';
  static const String initiateCheckout = 'InitiateCheckout';
  static const String purchase = 'Purchase';
  static const String search = 'Search';
  static const String addToWishlist = 'AddToWishlist';
  static const String viewCategory = 'ViewCategory';
  static const String contact = 'Contact';
  static const String customizeProduct = 'CustomizeProduct';
  static const String donate = 'Donate';
  static const String findLocation = 'FindLocation';
  static const String schedule = 'Schedule';
  static const String startOrder = 'StartOrder';
  static const String subscribe = 'Subscribe';
  static const String adClick = 'AdClick';
  static const String adImpression = 'AdImpression';
  
  // Custom Events for Patel's R Mart
  static const String productView = 'ProductView';
  static const String categoryView = 'CategoryView';
  static const String cartUpdate = 'CartUpdate';
  static const String orderPlaced = 'OrderPlaced';
  static const String orderCancelled = 'OrderCancelled';
  static const String deliveryTracking = 'DeliveryTracking';
  static const String storeLocator = 'StoreLocator';
  static const String customerSupport = 'CustomerSupport';
  static const String appRating = 'AppRating';
  static const String shareApp = 'ShareApp';
}

/// Event parameters types
class FacebookPixelParameters {
  // Standard parameters
  static const String contentIds = 'content_ids';
  static const String contentName = 'content_name';
  static const String contentCategory = 'content_category';
  static const String contentType = 'content_type';
  static const String value = 'value';
  static const String currency = 'currency';
  static const String numItems = 'num_items';
  static const String orderId = 'order_id';
  static const String searchString = 'search_string';
  
  // Custom parameters for Patel's R Mart
  static const String productId = 'product_id';
  static const String productName = 'product_name';
  static const String productPrice = 'product_price';
  static const String categoryId = 'category_id';
  static const String categoryName = 'category_name';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userPhone = 'user_phone';
  static const String orderTotal = 'order_total';
  static const String orderStatus = 'order_status';
  static const String deliveryAddress = 'delivery_address';
  static const String paymentMethod = 'payment_method';
  static const String storeId = 'store_id';
  static const String storeName = 'store_name';
  static const String appVersion = 'app_version';
  static const String platform = 'platform';
} 