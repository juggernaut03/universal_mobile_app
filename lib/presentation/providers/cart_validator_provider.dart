// lib/presentation/providers/cart_validator_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import '../../data/services/cart_validator.dart';
import '../../data/services/cart_session_manager.dart';
import '../../core/utils/logger.dart';
import 'launch_flow_provider.dart';

// Provider for cart session manager
final cartSessionManagerProvider = Provider<CartSessionManager>((ref) {
  final logger = ref.watch(loggerProvider);
  return CartSessionManager(logger: logger);
});

// Enhanced cart validator that includes session management
class EnhancedCartValidator {
  final CartValidator _cartValidator;
  final CartSessionManager _sessionManager;
  final Logger _logger;
  
  EnhancedCartValidator({
    required CartValidator cartValidator,
    required CartSessionManager sessionManager,
    required Logger logger,
  }) : _cartValidator = cartValidator,
       _sessionManager = sessionManager,
       _logger = logger;

  /// FIXED: Get current cart identifiers with proper session validation and creation
  Future<Map<String, String?>> getCurrentCartIdentifiers() async {
    try {
      _logger.log('=== GETTING CART IDENTIFIERS WITH SESSION VALIDATION ===');
      
      // Check if current session is valid
      final isSessionValid = await _sessionManager.isCartSessionValid();
      
      if (!isSessionValid) {
        _logger.log('Current cart session is invalid - creating new session');
        await _sessionManager.createNewOrderSession(); // Use createNewOrderSession instead of resetCartSession
      }
      
      // Check if cart was modified after processing started
      final wasModifiedAfterProcessing = await _sessionManager.hasCartBeenModifiedAfterProcessing();
      
      if (wasModifiedAfterProcessing) {
        _logger.log('Cart was modified after order processing started - resetting session');
        await _sessionManager.createNewOrderSession(); // Use createNewOrderSession instead of resetCartSession
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

  /// FIXED: Ensure session is ready for order placement with null safety
  // Future<bool> ensureSessionReadyForOrder() async {
  //   try {
  //     _logger.log('=== ENSURING SESSION READY FOR ORDER ===');
      
  //     // Get current session state with null safety
  //     final prefs = await SharedPreferences.getInstance();
  //     final currentState = prefs.getString('order_processing_state') ?? 'idle';
  //     final sessionCreated = prefs.getInt('session_created_timestamp') ?? 0;
      
  //     _logger.log('Current session state: $currentState');
  //     _logger.log('Session created timestamp: $sessionCreated');
      
  //     // If session is in completed or failed state, create new one
  //     if (currentState == 'completed' || currentState == 'failed') {
  //       _logger.log('Session is in terminal state, creating new session');
  //       await _sessionManager.createNewOrderSession();
  //       await Future.delayed(Duration(milliseconds: 100));
  //       return true;
  //     }
      
  //     // If session is in processing or payment processing, it might be stale
  //     if (currentState == 'processing' || currentState == 'payment_processing') {
        
  //       // Check if session is old (more than 10 minutes in processing state)
  //       final now = DateTime.now().millisecondsSinceEpoch;
  //       final sessionAge = now - sessionCreated;
  //       final tenMinutes = 10 * 60 * 1000;
        
  //       if (sessionAge > tenMinutes) {
  //         _logger.log('Session is stale (${sessionAge}ms old), creating new session');
  //         await _sessionManager.createNewOrderSession();
  //         await Future.delayed(Duration(milliseconds: 100));
  //         return true;
  //       }
  //     }
      
  //     // Validate session with null safety
  //     bool isValid = false;
  //     try {
  //       final validationResult = await _sessionManager.isCartSessionValid();
  //       isValid = validationResult ?? false; // Handle null case
  //     } catch (validationError) {
  //       _logger.error('Session validation error: $validationError');
  //       isValid = false;
  //     }
      
  //     if (!isValid) {
  //       _logger.log('Session validation failed, creating new session');
  //       await _sessionManager.createNewOrderSession();
  //       await Future.delayed(Duration(milliseconds: 100));
  //     }
      
  //     _logger.log('Session ready for order: true');
  //     return true;
  //   } catch (e) {
  //     _logger.error('Error ensuring session ready: $e');
      
  //     // Force create new session as fallback
  //     try {
  //       _logger.log('Attempting fallback session creation');
  //       await _sessionManager.resetCartSession();
  //       await Future.delayed(Duration(milliseconds: 200));
  //       return true;
  //     } catch (fallbackError) {
  //       _logger.error('Fallback session creation failed: $fallbackError');
  //       return false;
  //     }
  //   }
  // }
  
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
  
  /// Process cart validation using existing cart validator
  Future<CartValidationResult?> processCartValidation(
    List<CartItem> cartItems,
    String storeCode,
  ) async {
    return await _cartValidator.processCartValidation(cartItems, storeCode);
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
  
  /// FIXED: Ensure session is ready for order placement
  Future<bool> ensureSessionReadyForOrder() async {
    try {
      _logger.log('=== ENSURING SESSION READY FOR ORDER ===');
      
      // Get current session state
      final sessionInfo = await _sessionManager.getSessionInfo();
      final currentState = sessionInfo['processing_state'] as String?;
      
      _logger.log('Current session state: $currentState');
      
      // If session is in completed or failed state, create new one
      if (currentState == CartSessionManager.stateCompleted || 
          currentState == CartSessionManager.stateFailed) {
        _logger.log('Session is in terminal state, creating new session');
        await _sessionManager.createNewOrderSession();
        return true;
      }
      
      // If session is in processing or payment processing, it might be stale
      if (currentState == CartSessionManager.stateProcessing ||
          currentState == CartSessionManager.statePaymentProcessing) {
        
        // Check if session is old (more than 10 minutes in processing state)
        final sessionCreated = sessionInfo['session_created'] as int? ?? 0;
        final now = DateTime.now().millisecondsSinceEpoch;
        final sessionAge = now - sessionCreated;
        final tenMinutes = 10 * 60 * 1000;
        
        if (sessionAge > tenMinutes) {
          _logger.log('Session is stale (${sessionAge}ms old), creating new session');
          await _sessionManager.createNewOrderSession();
          return true;
        }
      }
      
      // Validate session normally
      final isValid = await _sessionManager.isCartSessionValid();
      if (!isValid) {
        _logger.log('Session validation failed, creating new session');
        await _sessionManager.createNewOrderSession();
      }
      
      return true;
    } catch (e) {
      _logger.error('Error ensuring session ready: $e');
      return false;
    }
  }

  /// FIXED: Safe session validation wrapper
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

  /// Check if cart has been modified after processing
  Future<bool> hasCartBeenModifiedAfterProcessing() async {
    try {
      return await _sessionManager.hasCartBeenModifiedAfterProcessing();
    } catch (e) {
      _logger.error('Error checking cart modification: $e');
      return false;
    }
  }

  /// Update cart modification timestamp
  Future<void> updateCartModification() async {
    try {
      await _sessionManager.updateCartModification();
      _logger.log('Updated cart modification timestamp');
    } catch (e) {
      _logger.error('Error updating cart modification: $e');
    }
  }

  /// Force cleanup and create new session
  Future<void> forceCleanupAndCreateNew() async {
    try {
      await _sessionManager.forceCleanupAndCreateNew();
      _logger.log('Force cleanup and new session created');
    } catch (e) {
      _logger.error('Error in force cleanup: $e');
    }
  }

  /// Clear processed order IDs
  Future<void> clearProcessedOrderIds() async {
    try {
      await _sessionManager.clearProcessedOrderIds();
      _logger.log('Cleared processed order IDs');
    } catch (e) {
      _logger.error('Error clearing processed order IDs: $e');
    }
  }
}

// Provider for the original CartValidator
final cartValidatorProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return CartValidator(logger: logger);
});

// Provider for enhanced cart validator with session management
final enhancedCartValidatorProvider = Provider<EnhancedCartValidator>((ref) {
  final cartValidator = ref.watch(cartValidatorProvider);
  final sessionManager = ref.watch(cartSessionManagerProvider);
  final logger = ref.watch(loggerProvider);
  
  return EnhancedCartValidator(
    cartValidator: cartValidator,
    sessionManager: sessionManager,
    logger: logger,
  );
});

// Cart validation state (used to show loading, error, or validation results)
enum CartValidationState {
  initial,
  loading,
  success,
  error,
}

// Maintain a counter for retry attempts to prevent infinite loops
final validationRetryCountProvider = StateProvider<int>((ref) => 0);

// Define a state class for cart validation
class CartValidationStateNotifier extends StateNotifier<CartValidationState> {
  final Ref _ref;
  final EnhancedCartValidator _enhancedCartValidator;
  final Logger _logger;
  CartValidationResult? _lastResult;
  String? _errorMessage;
  
  // Maximum number of retries before forcing a different approach
  static const int _maxRetries = 2;

  CartValidationStateNotifier({
    required Ref ref,
    required EnhancedCartValidator enhancedCartValidator,
    required Logger logger,
  }) : 
    _ref = ref,
    _enhancedCartValidator = enhancedCartValidator,
    _logger = logger,
    super(CartValidationState.initial);

  CartValidationState get currentState => state;
  CartValidationResult? get lastResult => _lastResult;
  String? get errorMessage => _errorMessage;

  Future<CartValidationResult?> validateCart(
    List<CartItem> cartItems, 
    String storeCode,
    int retryCount,
  ) async {
    if (cartItems.isEmpty) {
      _errorMessage = "Your cart is empty. Add items to proceed.";
      state = CartValidationState.error;
      return null;
    }
    
    // Check if we've exceeded max retries
    if (retryCount >= _maxRetries) {
      _logger.warning('Maximum validation retries ($retryCount) reached for cart validation');
      // Create a forced error result to break the loop
      return CartValidationResult(
        isValid: false,
        validationMessage: 'Maximum validation attempts reached. Please try a different approach.',
        maxRetriesReached: true,
      );
    }

    try {
      state = CartValidationState.loading;
      _lastResult = null;
      _errorMessage = null;

      _logger.log('Starting cart validation process (attempt ${retryCount + 1}/${_maxRetries + 1})');
      
      // Use enhanced cart validator for session-aware validation
      final result = await _enhancedCartValidator.processCartValidation(cartItems, storeCode);
      
      if (result != null) {
        // Auto-update cart if needed
        if (result.hasChanges) {
           _logger.log('Auto-updating cart based on validation result');
           _ref.read(cartProvider.notifier).applyValidationResult(result);
        }

        _lastResult = result;
        state = CartValidationState.success;
        _logger.log('Cart validation successful: ${result.validationMessage}');
        _logger.log('Removed items: ${result.removedItems.length}, Price changes: ${result.priceChangedItems.length}, Issues: ${result.itemsWithIssues.length}');
        _logger.log('Has changes: ${result.hasChanges}, Is valid: ${result.isValid}');
      } else {
        _errorMessage = "Failed to validate cart with server.";
        state = CartValidationState.error;
        _logger.error('Cart validation failed: $_errorMessage');
      }
      
      return result;
    } catch (e) {
      _logger.error('Error during cart validation: $e');
      _errorMessage = e.toString();
      state = CartValidationState.error;
      return null;
    }
  }

  void reset() {
    _lastResult = null;
    _errorMessage = null;
    state = CartValidationState.initial;
  }
}

// Provider for cart validation state with enhanced validator
final cartValidationStateProvider = StateNotifierProvider<CartValidationStateNotifier, CartValidationState>((ref) {
  final enhancedCartValidator = ref.watch(enhancedCartValidatorProvider);
  final logger = ref.watch(loggerProvider);
  return CartValidationStateNotifier(
    ref: ref,
    enhancedCartValidator: enhancedCartValidator,
    logger: logger,
  );
});

// Additional helper providers for enhanced functionality
final cartIdentifiersProvider = FutureProvider<Map<String, String?>>((ref) async {
  final enhancedValidator = ref.watch(enhancedCartValidatorProvider);
  return await enhancedValidator.getCurrentCartIdentifiers();
});

final sessionValidityProvider = FutureProvider<bool>((ref) async {
  final enhancedValidator = ref.watch(enhancedCartValidatorProvider);
  return await enhancedValidator.isSessionValid();
});

final sessionStateProvider = FutureProvider<String>((ref) async {
  final enhancedValidator = ref.watch(enhancedCartValidatorProvider);
  return await enhancedValidator.getSessionState();
});

final sessionDebugInfoProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final enhancedValidator = ref.watch(enhancedCartValidatorProvider);
  return await enhancedValidator.getSessionDebugInfo();
});