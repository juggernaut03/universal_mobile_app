// lib/presentation/providers/cart_validator_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import '../../data/services/cart_validator.dart';
import '../../core/utils/logger.dart';
import 'launch_flow_provider.dart';

// Provider for the CartValidator
final cartValidatorProvider = Provider((ref) {
  final logger = ref.watch(loggerProvider);
  return CartValidator(logger: logger);
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
  final CartValidator _cartValidator;
  final Logger _logger;
  CartValidationResult? _lastResult;
  String? _errorMessage;
  
  // Maximum number of retries before forcing a different approach
  static const int _maxRetries = 2;

  CartValidationStateNotifier({
    required CartValidator cartValidator,
    required Logger logger,
  }) : 
    _cartValidator = cartValidator,
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
      final result = await _cartValidator.processCartValidation(cartItems, storeCode);
      
      if (result != null) {
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

// Provider for cart validation state
final cartValidationStateProvider = StateNotifierProvider<CartValidationStateNotifier, CartValidationState>((ref) {
  final cartValidator = ref.watch(cartValidatorProvider);
  final logger = ref.watch(loggerProvider);
  return CartValidationStateNotifier(
    cartValidator: cartValidator,
    logger: logger,
  );
});