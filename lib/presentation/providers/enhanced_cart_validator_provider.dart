// lib/presentation/providers/enhanced_cart_validator_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/core/utils/logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../data/services/cart_session_manager.dart';
import '../../di/service_providers.dart';
import '../../di/infrastructure_providers.dart';

// Provider for cart session manager
// cartSessionManagerProvider moved to lib/di/service_providers.dart

// Enhanced cart validator service provider
final enhancedCartValidatorProvider = Provider<EnhancedCartValidatorService>((ref) {
  final logger = ref.watch(loggerProvider);
  final sessionManager = ref.watch(cartSessionManagerProvider);
  return EnhancedCartValidatorService(
    sessionManager: sessionManager,
    logger: logger,
  );
});

// Enhanced cart validator service class
class EnhancedCartValidatorService {
  final CartSessionManager _sessionManager;
  final Logger _logger;
  
  EnhancedCartValidatorService({
    required CartSessionManager sessionManager,
    required Logger logger,
  }) : _sessionManager = sessionManager,
       _logger = logger;

  /// FIXED: Get current cart identifiers with proper session validation and creation
  Future<Map<String, String?>> getCurrentCartIdentifiers() async {
    try {
      _logger.log('=== GETTING CART IDENTIFIERS WITH SESSION VALIDATION ===');
      
      // Check if current session is valid
      final isSessionValid = await _sessionManager.isCartSessionValid();
      
      if (!isSessionValid) {
        _logger.log('Current cart session is invalid - creating new session');
        await _sessionManager.createNewOrderSession(); // FIXED: Use createNewOrderSession
      }
      
      // Check if cart was modified after processing started
      final wasModifiedAfterProcessing = await _sessionManager.hasCartBeenModifiedAfterProcessing();
      
      if (wasModifiedAfterProcessing) {
        _logger.log('Cart was modified after order processing started - resetting session');
        await _sessionManager.createNewOrderSession(); // FIXED: Use createNewOrderSession
      }
      
      // Get current identifiers (now guaranteed to be valid and fresh)
      final prefs = await SharedPreferences.getInstance();
      final tempOrderId = prefs.getString('temp_order_id');
      final cartKey = prefs.getString('cart_key');
      final deviceId = prefs.getString('device_id');
      
      _logger.log('Retrieved cart identifiers:');
      _logger.log('- Temp Order ID: $tempOrderId');
      _logger.log('- Cart Key: $cartKey');
      _logger.log('- Device ID: $deviceId');
      
      // Double check - if still missing, force create new session
      if (tempOrderId == null || cartKey == null || deviceId == null) {
        _logger.warning('Identifiers still missing after session validation - force creating new session');
        await _sessionManager.forceCleanupAndCreateNew();
        
        // Re-fetch after force creation
        final newTempOrderId = prefs.getString('temp_order_id');
        final newCartKey = prefs.getString('cart_key');
        final newDeviceId = prefs.getString('device_id');
        
        return {
          'temp_order_id': newTempOrderId,
          'cart_key': newCartKey,
          'device_id': newDeviceId,
        };
      }
      
      return {
        'temp_order_id': tempOrderId,
        'cart_key': cartKey,
        'device_id': deviceId,
      };
      
    } catch (e) {
      _logger.error('Error getting cart identifiers: $e');
      
      // Fallback: Force create new session
      try {
        await _sessionManager.forceCleanupAndCreateNew();
        final prefs = await SharedPreferences.getInstance();
        return {
          'temp_order_id': prefs.getString('temp_order_id'),
          'cart_key': prefs.getString('cart_key'),
          'device_id': prefs.getString('device_id'),
        };
      } catch (fallbackError) {
        _logger.error('Fallback session creation also failed: $fallbackError');
        return {
          'temp_order_id': null,
          'cart_key': null,
          'device_id': null,
        };
      }
    }
  }
  
  /// FIXED: Prepare for new order - ensure fresh identifiers
   Future<Map<String, String?>> prepareForNewOrder() async {
    try {
      _logger.log('=== PREPARING FOR NEW ORDER ===');
      
      // Always create a completely new session for new orders
      await _sessionManager.createNewOrderSession();
      
      // Small delay to ensure session is created
      await Future.delayed(Duration(milliseconds: 100));
      
      // Get the fresh identifiers
      final identifiers = await getCurrentCartIdentifiers();
      
      _logger.log('New order preparation complete:');
      _logger.log('- Fresh Temp Order ID: ${identifiers['temp_order_id']}');
      _logger.log('- Fresh Cart Key: ${identifiers['cart_key']}');
      _logger.log('- Device ID: ${identifiers['device_id']}');
      
      return identifiers;
    } catch (e) {
      _logger.error('Error preparing for new order: $e');
      
      // Force fallback session creation
      try {
        await _sessionManager.resetCartSession();
        await Future.delayed(Duration(milliseconds: 100));
        final fallbackIdentifiers = await getCurrentCartIdentifiers();
        return fallbackIdentifiers;
      } catch (fallbackError) {
        _logger.error('Fallback session creation failed: $fallbackError');
        return {
          'temp_order_id': null,
          'cart_key': null,
          'device_id': null,
        };
      }
    }
  }
  
  /// Mark that cart has been modified (user added/removed items)
  Future<void> markCartAsModified() async {
    try {
      await _sessionManager.updateCartModification();
      _logger.log('Marked cart as modified');
    } catch (e) {
      _logger.error('Error marking cart as modified: $e');
    }
  }
  
  /// Mark order as processing (when user clicks "Place Order")
  Future<void> markOrderAsProcessing(String tempOrderId) async {
    try {
      await _sessionManager.markOrderAsProcessing(tempOrderId);
      _logger.log('Marked order as processing: $tempOrderId');
    } catch (e) {
      _logger.error('Error marking order as processing: $e');
    }
  }
  
  /// Mark order as payment processing (when payment processing API is called)
  Future<void> markOrderAsPaymentProcessing(String tempOrderId) async {
    try {
      await _sessionManager.markOrderAsPaymentProcessing(tempOrderId);
      _logger.log('Marked order as payment processing: $tempOrderId');
    } catch (e) {
      _logger.error('Error marking order as payment processing: $e');
    }
  }
  
  /// Mark order as completed (when order is successfully placed)
  Future<void> markOrderAsCompleted(String tempOrderId) async {
    try {
      await _sessionManager.markOrderAsCompleted(tempOrderId);
      _logger.log('Marked order as completed: $tempOrderId');
      _logger.log('New session automatically created for next order');
    } catch (e) {
      _logger.error('Error marking order as completed: $e');
    }
  }
  
  /// Mark order as failed (when order processing fails)
  Future<void> markOrderAsFailed(String tempOrderId) async {
    try {
      await _sessionManager.markOrderAsFailed(tempOrderId);
      _logger.log('Marked order as failed: $tempOrderId');
      _logger.log('New session automatically created for retry');
    } catch (e) {
      _logger.error('Error marking order as failed: $e');
    }
  }
  
  /// Force reset cart session (for manual reset)
  Future<void> resetCartSession() async {
    try {
      await _sessionManager.resetCartSession();
      _logger.log('Force reset cart session');
    } catch (e) {
      _logger.error('Error force resetting cart session: $e');
    }
  }
  
  /// Get current cart key (with session validation)
  Future<String?> getCurrentCartKey() async {
    final identifiers = await getCurrentCartIdentifiers();
    return identifiers['cart_key'];
  }
  
  /// Get current device ID (with session validation)
  Future<String?> getCurrentDeviceId() async {
    final identifiers = await getCurrentCartIdentifiers();
    return identifiers['device_id'];
  }
  
  /// Get current temp order ID (with session validation)
  Future<String?> getCurrentTempOrderId() async {
    final identifiers = await getCurrentCartIdentifiers();
    return identifiers['temp_order_id'];
  }
  
  /// Get session debug information
  Future<Map<String, dynamic>> getSessionDebugInfo() async {
    try {
      return await _sessionManager.getSessionInfo();
    } catch (e) {
      _logger.error('Error getting session debug info: $e');
      return {'error': e.toString()};
    }
  }
  // Add these methods to your existing EnhancedCartValidator class
// in lib/presentation/providers/cart_validator_provider.dart

// Add these methods to your existing EnhancedCartValidator class:

/// FIXED: Prepare for new order - ensure fresh identifiers


/// FIXED: Ensure session is ready for order placement
Future<bool> ensureSessionReadyForOrder() async {
  try {
    _logger.log('=== ENSURING SESSION READY FOR ORDER ===');
    
    // Get current session state with null safety
    final prefs = await SharedPreferences.getInstance();
    final currentState = prefs.getString('order_processing_state') ?? 'idle';
    final sessionCreated = prefs.getInt('session_created_timestamp') ?? 0;
    
    _logger.log('Current session state: $currentState');
    _logger.log('Session created timestamp: $sessionCreated');
    
    // If session is in completed or failed state, create new one
    if (currentState == 'completed' || currentState == 'failed') {
      _logger.log('Session is in terminal state, creating new session');
      await _sessionManager.createNewOrderSession();
      await Future.delayed(Duration(milliseconds: 100));
      return true;
    }
    
    // If session is in processing or payment processing, it might be stale
    if (currentState == 'processing' || currentState == 'payment_processing') {
      
      // Check if session is old (more than 10 minutes in processing state)
      final now = DateTime.now().millisecondsSinceEpoch;
      final sessionAge = now - sessionCreated;
      final tenMinutes = 10 * 60 * 1000;
      
      if (sessionAge > tenMinutes) {
        _logger.log('Session is stale (${sessionAge}ms old), creating new session');
        await _sessionManager.createNewOrderSession();
        await Future.delayed(Duration(milliseconds: 100));
        return true;
      }
    }
    
    // Validate session with null safety
    bool isValid = false;
    try {
      final validationResult = await _sessionManager.isCartSessionValid();
      isValid = validationResult ?? false; // Handle null case
    } catch (validationError) {
      _logger.error('Session validation error: $validationError');
      isValid = false;
    }
    
    if (!isValid) {
      _logger.log('Session validation failed, creating new session');
      await _sessionManager.createNewOrderSession();
      await Future.delayed(Duration(milliseconds: 100));
    }
    
    _logger.log('Session ready for order: true');
    return true;
  } catch (e) {
    _logger.error('Error ensuring session ready: $e');
    
    // Force create new session as fallback
    try {
      _logger.log('Attempting fallback session creation');
      await _sessionManager.resetCartSession();
      await Future.delayed(Duration(milliseconds: 200));
      return true;
    } catch (fallbackError) {
      _logger.error('Fallback session creation failed: $fallbackError');
      return false;
    }
  }
}
Future<bool> isSessionValid() async {
  try {
    final result = await _sessionManager.isCartSessionValid();
    return result ?? false; // Handle null case
  } catch (e) {
    _logger.error('Error checking session validity: $e');
    return false;
  }
}

/// FIXED: Safe session state getter
Future<String> getSessionState() async {
  try {
    final result = await _sessionManager.getOrderProcessingState();
    return result ?? 'idle'; // Handle null case
  } catch (e) {
    _logger.error('Error getting session state: $e');
    return 'idle';
  }
}
}