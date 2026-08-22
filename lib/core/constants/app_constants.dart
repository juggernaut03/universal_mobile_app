// lib/core/constants/app_constants.dart

import '../branding/app_branding.dart';
import '../config/env_config.dart';

class ApiConstants {
  // Universal multi-tenant backend. Base URL and project code come from
  // --dart-define (see EnvConfig) so one codebase builds for every client.
  static const String baseUrl = EnvConfig.baseUrl;

  // Project code identifying this client's tenant; sent as the
  // X-Project-Code header (and body/query fallback) with every request.
  static const String projectCode = EnvConfig.projectCode;

  // Google Maps API Configuration.
  //
  // The tenant's key from project-config wins; this build-time value is the
  // fallback for projects that have not set one under Mobile App >
  // Integrations. Read through the getter, not the constant.
  static const String _defaultGoogleApiKey = 'AIzaSyBAu4cNOm7_OJfwL8oX0PtL3BI8ma7MoOo';

  static String get googleApiKey {
    final configured = AppBranding.instance.googleMapsApiKey;
    return configured.isNotEmpty ? configured : _defaultGoogleApiKey;
  }

  static const int locationTimeout = 15; // Seconds to wait for location

  // ---- Auth ----
  static const String authSendOtp = '$baseUrl/auth/send-otp';
  static const String authVerifyOtp = '$baseUrl/auth/verify-otp';
  static const String authProfile = '$baseUrl/auth/profile';
  static const String authLogout = '$baseUrl/auth/logout';
  static const String authRefreshToken = '$baseUrl/auth/refresh-token';
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

  // ---- Home ----
  /// Server-defined home layout: ordered, typed sections.
  static const String homeFeed = '$baseUrl/home/feed';

  /// Batched section impressions/taps. Fire-and-forget.
  static const String homeEvents = '$baseUrl/home/events';

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

  // ---- Loyalty & Rewards ----
  static const String loyaltyDashboard = '$baseUrl/loyalty';
  static const String loyaltyBalance = '$baseUrl/loyalty/balance';
  static const String loyaltyTransactions = '$baseUrl/loyalty/transactions';
  static const String loyaltyRewards = '$baseUrl/loyalty/rewards';
  static String loyaltyRedeem(String rewardId) => '$baseUrl/loyalty/rewards/$rewardId/redeem';
  static const String loyaltyActiveRedemptions = '$baseUrl/loyalty/redemptions/active';
  static String loyaltyRedemptionPreview(String redemptionId) => '$baseUrl/loyalty/redemptions/$redemptionId/preview';
  static const String loyaltyTiers = '$baseUrl/loyalty/tiers';
  static const String loyaltyChallenges = '$baseUrl/loyalty/challenges';
  static String loyaltyClaimChallenge(String challengeId) => '$baseUrl/loyalty/challenges/$challengeId/claim';
  static const String loyaltyReferral = '$baseUrl/loyalty/referral';
  static const String loyaltyReferralApply = '$baseUrl/loyalty/referral/apply';

  // ---- Tenant config & content ----
  static const String projectConfig = '$baseUrl/project-config';
  static String contentPage(String slug) => '$baseUrl/content/$slug';
  static const String faqs = '$baseUrl/faqs';

  // Storage keys
  static const String keyPincode = 'selected_pincode';
  static const String keyOutlet = 'selected_outlet';
  static const String keyLocation = 'user_location';
  static const String keyApiInitialized = 'google_api_initialized';

  // Fallback image shown wherever a product/order photo is missing or fails
  // to load (see CachedNetworkImageWidget). This used to be hardcoded to
  // Patel Mart's own CDN — patelrmart.com/.../default_img.webp — so every
  // other tenant (My Need Mart, Grahak Peth, Sansar Pariwar...) showed
  // Patel's placeholder image whenever their own was missing.
  //
  // Now sourced from this tenant's own logo, set in the admin panel under
  // Mobile App > Branding (GET /api/project-config -> config.logo_url,
  // applied to AppBranding.instance at startup). Empty when the tenant
  // hasn't set one — CachedNetworkImageWidget falls back to a plain local
  // icon in that case, not another hardcoded remote image.
  static String get fallbackImageUrl => AppBranding.instance.logoUrl;

  // razorpay — key id only; the secret lives on the server, which creates
  // and verifies all Razorpay orders. The tenant's configured key id wins
  // over the build-time one, same as the maps key above.
  static const int apiTimeoutSeconds = 15;

  static String get razorpayKeyId {
    final configured = AppBranding.instance.razorpayKeyId;
    return configured.isNotEmpty ? configured : EnvConfig.razorpayKeyId;
  }

  static const String timeout = '390';
  static const String version = '1.0';

  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };
}
