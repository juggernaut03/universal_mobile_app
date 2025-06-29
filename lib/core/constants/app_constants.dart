// lib/core/constants/api_constants.dart

class ApiConstants {
  static const String baseUrl = 'https://newtech.shalviadvision.com/api';
  
  // Project code to be sent with every API request
  static const String projectCode = "RET5890";
  
  // Google Maps API Configuration
  static const String googleApiKey = 'AIzaSyAnFzm0egXHx7P7zBsOjC3NV01Wj3ZHgyo'; // Replace with your actual API key
  static const int locationTimeout = 15; // Seconds to wait for location
  
  // API endpoints
  static const String checkPincode = '$baseUrl/check_if_pincode_exists';
  static const String getPincodeList = '$baseUrl/get_pincode_list';
  static const String getPincodewiseOutlet = '$baseUrl/get_pincodewise_outlet';
  static const String getOfferScreen = '$baseUrl/get_offerscreen';
  static const String getActiveDepartmentList = '$baseUrl/get_active_department_list';
  static const String getActiveCategoriesList = '$baseUrl/get_active_categories_list';
  // Storage keys
  static const String keyPincode = 'selected_pincode';
  static const String keyOutlet = 'selected_outlet';
  static const String keyLocation = 'user_location';
  static const String keyApiInitialized = 'google_api_initialized';

  
  // Fallback image
  static const String fallbackImageUrl = 'https://patelrmart.com/mgmt_panel/product_images/patel_webp/default_img.webp';
  // Fallback image (multiple options for reliability)
  
  // Backup fallback images if the primary one fails
  static const List<String> backupFallbackImageUrls = [
    'https://patelrmart.com/mgmt_panel/product_images/patel_webp/default_img.webp',
    'https://patelrmart.com/mgmt_panel/product_images/patel_webp/default_img.webp',
    'https://patelrmart.com/mgmt_panel/product_images/patel_webp/default_img.webp'
  ];
  // razorpay
  static const int apiTimeoutSeconds = 15;
  static const String razorpayKeyId = 'rzp_live_Qq9CQRIX2I2qej'; // Replace with your actual test key
  static const String razorpayKeySecret = 'RoKRhP1fc6sqnvwcqnLBU6cr';

  static const String timeout = '390';
  static const String version = '1.0';
  
  // API Endpoints
  static const String confirmOrderEndpoint = '/confirm_order';
  static const String paymentProcessingEndpoint = '/order_payment_processing';
  static const String deliverySlotsEndpoint = '/get_delivery_slots';
  static const String paymentMethodsEndpoint = '/get_payment_methods';
  static const Map<String, String> defaultHeaders = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

}
