// lib/data/models/best_seller_models.dart

// Banner model for the best seller sections
class BestSellerBanner {
  final String id;
  final String imageUrl;
  final String actionType; // Could be "product", "category", etc.
  final String actionUrl; // Could be product ID, category ID, etc.
  final int sequenceId;
  final String backgroundColor; // Added background color

  BestSellerBanner({
    required this.id,
    required this.imageUrl,
    required this.actionType,
    required this.actionUrl,
    required this.sequenceId,
    this.backgroundColor = "#FFFFFF", // Default white
  });

  factory BestSellerBanner.fromJson(Map<String, dynamic> json) {
    // Extract the image URL, checking multiple possible field names
    String imageUrl = '';
    if (json.containsKey('banner_img')) {
      imageUrl = json['banner_img'] ?? '';
    } else if (json.containsKey('img_path')) {
      imageUrl = json['img_path'] ?? '';
    } else if (json.containsKey('image_link')) {
      imageUrl = json['image_link'] ?? '';
    }
    
    // Extract action URL based on different possible field names
    String actionUrl = '';
    if (json.containsKey('redirect_link')) {
      actionUrl = json['redirect_link'] ?? '';
    } else if (json.containsKey('banner_action_url')) {
      actionUrl = json['banner_action_url'] ?? '';
    }
    
    // Extract background color if available
    String backgroundColor = '#FFFFFF'; // Default white
    if (json.containsKey('banner_bg_color')) {
      backgroundColor = json['banner_bg_color'] ?? '#FFFFFF';
    }
    
    return BestSellerBanner(
      id: json['_id'] ?? json['banner_id'] ?? '',
      imageUrl: imageUrl,
      actionType: json['banner_action_type'] ?? 'default',
      actionUrl: actionUrl,
      sequenceId: _parseSequenceId(json['sequence_id']),
      backgroundColor: backgroundColor,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'img_path': imageUrl,
      'banner_action_type': actionType,
      'banner_action_url': actionUrl,
      'sequence_id': sequenceId,
      'banner_bg_color': backgroundColor,
    };
  }
  
  // Helper method to parse sequence_id which might be a string, number, or null
  static int _parseSequenceId(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) {
      try {
        return int.parse(value);
      } catch (_) {
        return 0;
      }
    }
    return 0;
  }
}

// New model for Best Seller Products Response with title
class BestSellerProductsResponse {
  final String title;
  final List<dynamic> products; // Keep as dynamic for now since ProductModel is created later

  BestSellerProductsResponse({
    required this.title,
    required this.products,
  });

  factory BestSellerProductsResponse.fromJson(Map<String, dynamic> json) {
    return BestSellerProductsResponse(
      title: json['title'] ?? 'Best Seller',
      products: json['bestseller_details'] ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'bestseller_details': products,
    };
  }
}

// Helper to map best seller ID to appropriate banner type ID and API endpoint
class BestSellerConfig {
  static int getBannerTypeId(int bestSellerId) {
    switch (bestSellerId) {
      case 1:
        return 3; // Banner type ID for best seller 1
      case 2:
        return 4; // Banner type ID for best seller 2
      case 3:
        return 11; // Banner type ID for best seller 3
      case 4:
        return 12; // Banner type ID for best seller 4
      default:
        return 3; // Default to best seller 1
    }
  }

  static String getProductEndpoint(int bestSellerId) {
    switch (bestSellerId) {
      case 1:
        return 'get_active_best_seller_1';
      case 2:
        return 'get_active_best_seller_2';
      case 3:
        return 'get_active_best_seller_3';
      case 4:
        return 'get_active_best_seller_4';
      default:
        return 'get_active_best_seller_1';
    }
  }
  
  // Default titles as fallback (can be used if API doesn't return title)
  static String getDefaultTitle(int bestSellerId) {
    switch (bestSellerId) {
      case 1:
        return 'Best Deals';
      case 2:
        return 'Best Offers';
      case 3:
        return 'Chai Time';
      case 4:
        return 'Top Picks For You';
      default:
        return 'Featured Products';
    }
  }
}