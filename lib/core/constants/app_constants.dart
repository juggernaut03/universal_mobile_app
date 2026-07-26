// lib/core/constants/app_constants.dart

import '../config/env_config.dart';

class ApiConstants {
  // Universal multi-tenant backend. Base URL and project code come from
  // --dart-define (see EnvConfig) so one codebase builds for every client.
  static const String baseUrl = EnvConfig.baseUrl;

  // Project code identifying this client's tenant; sent as the
  // X-Project-Code header (and body/query fallback) with every request.
  static const String projectCode = EnvConfig.projectCode;

  // Google Maps API Configuration
  static const String googleApiKey = 'AIzaSyBAu4cNOm7_OJfwL8oX0PtL3BI8ma7MoOo';
  static const int locationTimeout = 15; // Seconds to wait for location

  // ---- Auth ----
  static const String authSendOtp = '$baseUrl/auth/send-otp';
  static const String authVerifyOtp = '$baseUrl/auth/verify-otp';
  static const String authProfile = '$baseUrl/auth/profile';
  static const String authLogout = '$baseUrl/auth/logout';
  static const String authSaveFcmToken = '$baseUrl/auth/save-fcm-token';

  // ---- Location & stores ----
  static const String checkPincode = '$baseUrl/pincodes/check-availability';
  static const String getPincodeList = '$baseUrl/pincodes/enabled/list';
  static const String getPincodewiseOutlet = '$baseUrl/stores/by-pincode';

  // ---- Catalog ----
  static const String getActiveDepartmentList = '$baseUrl/departments/by-store';
  static const String getActiveCategoriesList = '$baseUrl/categories/get-categories';
  static const String getSubcategoriesList = '$baseUrl/subcategories/get-subcategories';
  static const String getProducts = '$baseUrl/products/get-products';
  static const String productDetails = '$baseUrl/products/productdetails';
  static const String searchProducts = '$baseUrl/products/search-products';

  // ---- Onboarding ----
  static const String onboardingList = '$baseUrl/onboarding/list';

  // ---- Home content ----
  static const String banners = '$baseUrl/banners';
  static const String popularCategoriesList = '$baseUrl/popular-categories/list';
  static const String seasonalCategoriesList = '$baseUrl/seasonal-categories/list';
  static const String bestSellersList = '$baseUrl/best-sellers/list';
  static const String topSellersList = '$baseUrl/top-sellers/list';
  static const String advertisementsActive = '$baseUrl/advertisements/active';

  // ---- Cart ----
  static const String cartSave = '$baseUrl/cart/save-cart';
  static const String cartValidate = '$baseUrl/cart/validate-cart';
  static const String cartGet = '$baseUrl/cart/get-cart';
  static const String cartClear = '$baseUrl/cart/clear-cart';

  // ---- Checkout ----
  static const String deliverySlotsGet = '$baseUrl/delivery-slots/get-delivery-slots';
  static const String deliveryChargesCalculate = '$baseUrl/delivery-charges/calculate';
  static const String paymentModesGet = '$baseUrl/payment-modes/get-payment-modes';
  static const String offersForCart = '$baseUrl/offers/for-cart';

  // ---- Orders ----
  static const String ordersPlace = '$baseUrl/orders/place-order';
  static const String ordersMy = '$baseUrl/orders/my-orders';
  static String orderByNumber(String orderNumber) => '$baseUrl/orders/$orderNumber';
  static String orderCancel(String orderNumber) => '$baseUrl/orders/$orderNumber/cancel';

  // ---- Payments (Razorpay handled server-side) ----
  static const String razorpayOrder = '$baseUrl/razorpay/order';
  static const String razorpayVerify = '$baseUrl/razorpay/verify';

  // ---- Addresses ----
  static const String addressAdd = '$baseUrl/address-crud/add-address';
  static const String addressGet = '$baseUrl/address-crud/get-addresses';
  static String addressUpdate(String id) => '$baseUrl/address-crud/update-address/$id';
  static String addressDelete(String id) => '$baseUrl/address-crud/delete-address/$id';

  // ---- Favorites ----
  static const String favoritesAdd = '$baseUrl/favorites/add-to-favorites';
  static const String favoritesRemove = '$baseUrl/favorites/remove-from-favorites';
  static const String favoritesGetByStore = '$baseUrl/favorites/get-favorites-by-store';
  static const String favoritesIsFavorited = '$baseUrl/favorites/is-favorited';

  // ---- Notifications ----
  static const String notifications = '$baseUrl/notifications';
  static const String notificationsUnreadCount = '$baseUrl/notifications/unread-count';
  static String notificationRead(String id) => '$baseUrl/notifications/$id/read';
  static const String notificationsReadAll = '$baseUrl/notifications/read-all';

  // ---- Tenant config & content ----
  static const String projectConfig = '$baseUrl/project-config';
  static String contentPage(String slug) => '$baseUrl/content/$slug';

  // Storage keys
  static const String keyPincode = 'selected_pincode';
  static const String keyOutlet = 'selected_outlet';
  static const String keyLocation = 'user_location';
  static const String keyApiInitialized = 'google_api_initialized';

  // Fallback image
  static const String fallbackImageUrl =
      'https://patelrmart.com/mgmt_panel/product_images/patel_webp/default_img.webp';

  // Backup fallback images if the primary one fails
  static const List<String> backupFallbackImageUrls = [
    'https://patelrmart.com/mgmt_panel/product_images/patel_webp/default_img.webp',
  ];

  // razorpay — key id only; the secret lives on the server, which creates
  // and verifies all Razorpay orders.
  static const int apiTimeoutSeconds = 15;
  static const String razorpayKeyId = EnvConfig.razorpayKeyId;

  static const String timeout = '390';
  static const String version = '1.0';

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
