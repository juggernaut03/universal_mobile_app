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
  static const String fallbackImageUrl = 'https://media.istockphoto.com/id/1396814518/vector/image-coming-soon-no-photo-no-thumbnail-image-available-vector-illustration.jpg?s=612x612&w=0&k=20&c=hnh2OZgQGhf0b46-J2z7aHbIWwq8HNlSDaNp2wn_iko=';
  // Fallback image (multiple options for reliability)
  
  // Backup fallback images if the primary one fails
  static const List<String> backupFallbackImageUrls = [
    'https://cdn.pixabay.com/photo/2017/01/25/17/35/picture-2008484_960_720.png',
    'https://cdn.pixabay.com/photo/2016/01/20/13/05/icon-1151577_960_720.png',
    'https://placehold.co/400x400/png'
  ];
  // razorpay
  static const int apiTimeoutSeconds = 15;
  static const String razorpayKeyId = 'rzp_test_5yy0US6kMQYbpU'; // Replace with your actual test key
  static const String razorpayKeySecret = '7ZwGbFIgsktyJlZOEbFNj6aN'; 
}