// lib/data/services/cart_session_manager.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../../core/utils/logger.dart';
import 'package:flutter/foundation.dart';

class CartSessionManager {
  final Logger _logger;
  
  CartSessionManager({Logger? logger}) : _logger = logger ?? Logger();
  
  // Keys for storing session state
  static const String _orderProcessingStateKey = 'order_processing_state';
  static const String _tempOrderIdKey = 'temp_order_id';
  static const String _cartKeyKey = 'cart_key';
  static const String _deviceIdKey = 'device_id';
  static const String _lastCartModificationKey = 'last_cart_modification';
  static const String _processedOrderIdsKey = 'processed_order_ids';
  static const String _sessionCreatedKey = 'session_created_timestamp';
  
  // Order processing states
  static const String stateIdle = 'idle';
  static const String stateProcessing = 'processing';
  static const String statePaymentProcessing = 'payment_processing';
  static const String stateCompleted = 'completed';
  static const String stateFailed = 'failed';
  
  /// Check if current cart session is valid for processing
Future<bool> isCartSessionValid() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Get current session data with null safety
    final currentTempOrderId = prefs.getString(_tempOrderIdKey);
    final orderProcessingState = prefs.getString(_orderProcessingStateKey) ?? stateIdle;
    final processedOrderIds = prefs.getStringList(_processedOrderIdsKey) ?? <String>[];
    final lastCartModification = prefs.getInt(_lastCartModificationKey) ?? 0;
    final sessionCreated = prefs.getInt(_sessionCreatedKey) ?? 0;
    
    _logger.log('=== CART SESSION VALIDATION ===');
    _logger.log('Current Temp Order ID: $currentTempOrderId');
    _logger.log('Order Processing State: $orderProcessingState');
    _logger.log('Processed Order IDs: $processedOrderIds');
    _logger.log('Last Cart Modification: $lastCartModification');
    _logger.log('Session Created: $sessionCreated');
    
    // If no temp order ID exists, session is invalid (need to create new)
    if (currentTempOrderId == null || currentTempOrderId.isEmpty) {
      _logger.log('No temp order ID found - session invalid');
      return false;
    }
    
    // If the current temp order ID has been processed before, session is invalid
    if (processedOrderIds.contains(currentTempOrderId)) {
      _logger.log('Temp order ID $currentTempOrderId has been processed before - session invalid');
      return false;
    }
    
    // If order is in payment processing or completed state, session is invalid for new changes
    if (orderProcessingState == statePaymentProcessing || 
        orderProcessingState == stateCompleted) {
      _logger.log('Order is in $orderProcessingState state - session invalid for modifications');
      return false;
    }
    
    // Check if session is too old (older than 24 hours)
    if (sessionCreated > 0) {
      final sessionAge = DateTime.now().millisecondsSinceEpoch - sessionCreated;
      final twentyFourHours = 24 * 60 * 60 * 1000;
      if (sessionAge > twentyFourHours) {
        _logger.log('Session is older than 24 hours - session invalid');
        return false;
      }
    }
    
    _logger.log('Cart session is valid');
    return true;
    
  } catch (e) {
    _logger.error('Error checking cart session validity: $e');
    return false; // Return false on any error to be safe
  }
}
  
  /// FIXED: Generate a truly unique temp order ID for each order placement
  String _generateUniqueOrderId() {
    final random = DateTime.now().microsecond; // More unique than modulo
    final dateTime = DateTime.now();
    final dateStr = '${dateTime.year}${dateTime.month.toString().padLeft(2, '0')}${dateTime.day.toString().padLeft(2, '0')}';
    final timeStr = '${dateTime.hour.toString().padLeft(2, '0')}${dateTime.minute.toString().padLeft(2, '0')}${dateTime.second.toString().padLeft(2, '0')}';
    
    return 'ORD_${dateStr}_${timeStr}_${random.toString().padLeft(6, '0')}';
  }
  
  /// FIXED: Generate a unique cart key
  String _generateUniqueCartKey() {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    return 'CART_${timestamp}_$random';
  }
  
  /// FIXED: Always generate new session when starting order process
 Future<void> createNewOrderSession() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    // Generate completely new identifiers
    final newTempOrderId = _generateUniqueOrderId();
    final newCartKey = _generateUniqueCartKey();
    final deviceId = await _getOrCreateDeviceId(); // Keep device ID consistent
    final sessionTimestamp = DateTime.now().millisecondsSinceEpoch;
    
    // Set new session state with error handling
    await prefs.setString(_orderProcessingStateKey, stateIdle);
    await prefs.setString(_tempOrderIdKey, newTempOrderId);
    await prefs.setString(_cartKeyKey, newCartKey);
    await prefs.setString(_deviceIdKey, deviceId);
    await prefs.setInt(_lastCartModificationKey, sessionTimestamp);
    await prefs.setInt(_sessionCreatedKey, sessionTimestamp);
    
    _logger.log('=== NEW ORDER SESSION CREATED ===');
    _logger.log('New Temp Order ID: $newTempOrderId');
    _logger.log('New Cart Key: $newCartKey');
    _logger.log('Device ID: $deviceId');
    _logger.log('Session Created: $sessionTimestamp');
    _logger.log('Session State: $stateIdle');
    
  } catch (e) {
    _logger.error('Error creating new order session: $e');
    throw Exception('Failed to create new order session: $e');
  }
}
  
  /// Mark the current order as being processed
  Future<void> markOrderAsProcessing(String tempOrderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_orderProcessingStateKey, stateProcessing);
      // Don't update temp order ID here - use the one provided
      
      _logger.log('Marked order $tempOrderId as processing');
    } catch (e) {
      _logger.error('Error marking order as processing: $e');
    }
  }
  
  /// Mark the current order as payment processing
  Future<void> markOrderAsPaymentProcessing(String tempOrderId) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    
    if (kDebugMode) print('\n🔄 === MARKING ORDER AS PAYMENT PROCESSING === 🔄');
    if (kDebugMode) print('Temp Order ID: $tempOrderId');
    if (kDebugMode) print('Current Status Before: ${prefs.getString(_orderProcessingStateKey) ?? "null"}');
    
    // Set the status
    await prefs.setString(_orderProcessingStateKey, statePaymentProcessing);
    
    // Verify it was set
    final newStatus = prefs.getString(_orderProcessingStateKey);
    if (kDebugMode) print('Status After Setting: $newStatus');
    if (kDebugMode) print('🔄 === PAYMENT PROCESSING STATUS SET === 🔄\n');
    
    _logger.log('Marked order $tempOrderId as payment processing');
  } catch (e) {
    if (kDebugMode) print('❌ ERROR marking order as payment processing: $e');
    _logger.error('Error marking order as payment processing: $e');
  }
}
  
  /// Mark the current order as completed and prepare for next order
  Future<void> markOrderAsCompleted(String tempOrderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_orderProcessingStateKey, stateCompleted);
      
      // Add to processed order IDs list
      final processedOrderIds = prefs.getStringList(_processedOrderIdsKey) ?? [];
      if (!processedOrderIds.contains(tempOrderId)) {
        processedOrderIds.add(tempOrderId);
        await prefs.setStringList(_processedOrderIdsKey, processedOrderIds);
      }
      
      _logger.log('Marked order $tempOrderId as completed');
      
      // FIXED: Automatically create new session for next order
      await Future.delayed(Duration(milliseconds: 100)); // Small delay to ensure state is saved
      await createNewOrderSession();
      
    } catch (e) {
      _logger.error('Error marking order as completed: $e');
    }
  }
  
  /// Mark the current order as failed
  Future<void> markOrderAsFailed(String tempOrderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      await prefs.setString(_orderProcessingStateKey, stateFailed);
      
      _logger.log('Marked order $tempOrderId as failed');
      
      // FIXED: Create new session after failure to allow retry with new identifiers
      await Future.delayed(Duration(milliseconds: 100));
      await createNewOrderSession();
      
    } catch (e) {
      _logger.error('Error marking order as failed: $e');
    }
  }
  
  /// Reset cart session to idle state (create new session)
  Future<void> resetCartSession() async {
    try {
      await createNewOrderSession();
      _logger.log('Cart session reset with new identifiers');
    } catch (e) {
      _logger.error('Error resetting cart session: $e');
    }
  }
  
  /// Update last cart modification timestamp
  Future<void> updateCartModification() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_lastCartModificationKey, DateTime.now().millisecondsSinceEpoch);
      
      _logger.log('Updated cart modification timestamp');
    } catch (e) {
      _logger.error('Error updating cart modification: $e');
    }
  }
  
  /// Get current order processing state
  Future<String> getOrderProcessingState() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final state = prefs.getString(_orderProcessingStateKey);
    return state ?? stateIdle; // Handle null case
  } catch (e) {
    _logger.error('Error getting order processing state: $e');
    return stateIdle; // Return default state on error
  }
}
  
  /// Check if cart has been modified after order processing started
  Future<bool> hasCartBeenModifiedAfterProcessing() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      final orderProcessingState = prefs.getString(_orderProcessingStateKey) ?? stateIdle;
      final lastCartModification = prefs.getInt(_lastCartModificationKey) ?? 0;
      
      // If order is being processed and cart was modified recently, it indicates user went back and changed cart
      if ((orderProcessingState == stateProcessing || 
           orderProcessingState == statePaymentProcessing) && 
          lastCartModification > 0) {
        
        // Check if modification happened in last 5 minutes (indicating recent user action)
        final timeDiff = DateTime.now().millisecondsSinceEpoch - lastCartModification;
        final fiveMinutesInMs = 5 * 60 * 1000;
        
        if (timeDiff < fiveMinutesInMs) {
          _logger.log('Cart was modified recently while order is processing - user likely went back');
          return true;
        }
      }
      
      return false;
    } catch (e) {
      _logger.error('Error checking cart modification: $e');
      return false;
    }
  }
  
  /// Get or create device ID (keep this consistent across sessions)
  Future<String> _getOrCreateDeviceId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      String? deviceId = prefs.getString(_deviceIdKey);
      
      if (deviceId == null || deviceId.isEmpty) {
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final random = DateTime.now().microsecond;
        deviceId = 'DEVICE_${timestamp}_$random';
        await prefs.setString(_deviceIdKey, deviceId);
      }
      
      return deviceId;
    } catch (e) {
      _logger.error('Error getting/creating device ID: $e');
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      return 'DEVICE_$timestamp';
    }
  }
  
  /// Get current session info for debugging
 Future<Map<String, dynamic>> getSessionInfo() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return {
      'temp_order_id': prefs.getString(_tempOrderIdKey),
      'cart_key': prefs.getString(_cartKeyKey),
      'device_id': prefs.getString(_deviceIdKey),
      'processing_state': prefs.getString(_orderProcessingStateKey) ?? stateIdle,
      'last_modification': prefs.getInt(_lastCartModificationKey) ?? 0,
      'session_created': prefs.getInt(_sessionCreatedKey) ?? 0,
      'processed_orders': prefs.getStringList(_processedOrderIdsKey) ?? <String>[],
    };
  } catch (e) {
    _logger.error('Error getting session info: $e');
    return {
      'error': e.toString(),
      'processing_state': stateIdle,
      'last_modification': 0,
      'session_created': 0,
      'processed_orders': <String>[],
    };
  }
}
  
  /// Clear all processed order IDs (for testing or cleanup)
  Future<void> clearProcessedOrderIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_processedOrderIdsKey);
      _logger.log('Cleared processed order IDs');
    } catch (e) {
      _logger.error('Error clearing processed order IDs: $e');
    }
  }
  
  /// Force cleanup old sessions and create fresh one
  Future<void> forceCleanupAndCreateNew() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Clear all session data
      await prefs.remove(_orderProcessingStateKey);
      await prefs.remove(_tempOrderIdKey);
      await prefs.remove(_cartKeyKey);
      await prefs.remove(_lastCartModificationKey);
      await prefs.remove(_sessionCreatedKey);
      // Keep device ID and processed orders for continuity
      
      // Create completely new session
      await createNewOrderSession();
      
      _logger.log('Force cleanup completed and new session created');
    } catch (e) {
      _logger.error('Error in force cleanup: $e');
    }
  }
}