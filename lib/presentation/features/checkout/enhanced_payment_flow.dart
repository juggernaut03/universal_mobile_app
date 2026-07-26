// lib/presentation/features/checkout/enhanced_payment_flow.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/models/address_model.dart';
import 'package:patelmart/data/models/payment_method_model.dart';
import 'package:patelmart/data/services/payment_service.dart';
import 'package:patelmart/presentation/providers/cart_provider.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:patelmart/presentation/providers/order_providers.dart';
import 'package:patelmart/presentation/providers/cart_validator_provider.dart';
import 'package:patelmart/presentation/providers/delivery_charges_provider.dart';
import 'package:patelmart/presentation/providers/location_provider.dart';
import 'package:patelmart/utils/payment_data_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Import CheckoutData and DeliveryMethod from your existing file
// FACEBOOK PIXEL IMPORTS
import '../../../facebook_pixel/facebook_pixel_integration.dart';
import '../../../di/service_providers.dart';
import '../../../di/auth_providers.dart';
import '../../../di/infrastructure_providers.dart';
import 'package:flutter/foundation.dart';
import 'checkout_models.dart';

/// Enhanced Payment Processing Flow that follows the exact requirements:
/// 1. On "Place Order" click → Call payment processing API → Database entry with status "Payment Processing"
/// 2. Process payment → Get payment result
/// 3. Call order confirmation API → Update database with payment details and final status
class EnhancedPaymentFlow {
  
  /// STEP 1: Mark order as Payment Processing in database
  /// This creates the initial database entry with status "Payment Processing"
  static Future<bool> markOrderAsPaymentProcessing({
    required WidgetRef ref,
    required String tempOrderId,
    required String deviceId,
    required String storeCode,
    required List<CartItem> cartItems,
    required Address deliveryAddress,
    required String deliverySlot,
    required String deliveryDate,
    required String deliveryMode,
    required String paymentMode,
    required double finalAmount,
    required double cartTotal,
    required double cartSavings,
    required double deliveryCharge,
    String? accessKey,
    String? mobileNo,
    String? specialNotes,
  }) async {
    try {
      final logger = ref.read(loggerProvider);
      
      logger.log('=== STEP 1: CREATING DATABASE ENTRY WITH PAYMENT PROCESSING STATUS ===');
      logger.log('Temp Order ID: $tempOrderId');
      logger.log('Final Amount: ₹${finalAmount.toStringAsFixed(2)}');
      logger.log('Payment Mode: $paymentMode');
      logger.log('Customer: ${deliveryAddress.fullName}');
      
      // Set UI status to show payment processing is being marked
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.markingPaymentProcessing;
      
      // Mark in session manager
      final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
      await enhancedCartValidator.markOrderAsPaymentProcessing(tempOrderId);
      
      // Call the payment processing API to create database entry
      final paymentProcessingService = ref.read(orderPaymentProcessingServiceProvider);
      final paymentProcessingResult = await paymentProcessingService.markOrderAsPaymentProcessing(
        deviceId: deviceId,
        tempOrderId: tempOrderId,
        storeCode: storeCode,
        cartItems: cartItems,
        deliveryAddress: deliveryAddress,
        deliverySlot: deliverySlot,
        deliveryDate: deliveryDate,
        deliveryMode: deliveryMode,
        paymentMode: paymentMode,
        totalMrp: cartTotal + cartSavings,
        totalOurPrice: cartTotal,
        discount: cartSavings,
        deliveryCharges: deliveryCharge,
        discountedAmount: cartTotal,
        finalPayableAmount: finalAmount,
        accessKey: accessKey,
        mobileNo: mobileNo,
        specialNotes: specialNotes,
      );
      
      // Store the result
      ref.read(orderPaymentProcessingResultProvider.notifier).state = paymentProcessingResult;
      
      if (paymentProcessingResult.success) {
        logger.log('✅ DATABASE ENTRY CREATED WITH STATUS: Payment Processing');
        logger.log('Order ID: ${paymentProcessingResult.orderId ?? "Generated"}');
        logger.log('Database Record Status: Payment Processing');
        
        if (kDebugMode) print('\n✅ === DATABASE ENTRY SUCCESSFUL === ✅');
        if (kDebugMode) print('Order ID: ${paymentProcessingResult.orderId ?? "Generated"}');
        if (kDebugMode) print('Database Status: Payment Processing');
        if (kDebugMode) print('Customer: ${deliveryAddress.fullName}');
        if (kDebugMode) print('Amount: ₹${finalAmount.toStringAsFixed(2)}');
        if (kDebugMode) print('Payment Mode: $paymentMode');
        if (kDebugMode) print('✅ === READY FOR PAYMENT === ✅\n');
        
        return true;
      } else {
        logger.error('❌ FAILED TO CREATE DATABASE ENTRY');
        logger.error('Error: ${paymentProcessingResult.message}');
        
        // Mark order as failed
        await enhancedCartValidator.markOrderAsFailed(tempOrderId);
        
        // Set error state
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
        ref.read(orderErrorMessageProvider.notifier).state = 
          'Failed to create order entry: ${paymentProcessingResult.message}';
        
        return false;
      }
    } catch (e) {
      final logger = ref.read(loggerProvider);
      logger.error('❌ EXCEPTION IN PAYMENT PROCESSING MARKING: $e');
      
      // Mark order as failed
      final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
      await enhancedCartValidator.markOrderAsFailed(tempOrderId);
      
      // Set error state
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
      ref.read(orderErrorMessageProvider.notifier).state = 'Error creating order entry: $e';
      
      return false;
    }
  }
  
  /// STEP 2: Process Payment (for online payments)
  /// This handles the actual payment processing
  static Future<PaymentResult?> processPayment({
    required WidgetRef ref,
    required double amount,
    required Address deliveryAddress,
    required String paymentMode,
    String? customOrderId,
  }) async {
    if (paymentMode.toLowerCase() != "online payment") {
      // For COD, return a mock successful result
      return PaymentResult(
        success: true,
        paymentId: 'COD_${DateTime.now().millisecondsSinceEpoch}',
        message: 'Cash on Delivery selected',
        fullPaymentData: {
          'payment_method': 'Cash on Delivery',
          'amount': amount,
          'status': 'pending',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
      );
    }
    
    try {
      final logger = ref.read(loggerProvider);
      
      logger.log('=== STEP 2: PROCESSING ONLINE PAYMENT ===');
      logger.log('Amount: ₹${amount.toStringAsFixed(2)}');
      logger.log('Customer: ${deliveryAddress.fullName}');
      logger.log('Payment Method: Online Payment');
      
      // Set UI status to show payment is being processed
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.processingPayment;
      
      if (kDebugMode) print('\n💳 === INITIATING ONLINE PAYMENT === 💳');
      if (kDebugMode) print('Amount: ₹${amount.toStringAsFixed(2)}');
      if (kDebugMode) print('Customer: ${deliveryAddress.fullName}');
      if (kDebugMode) print('Phone: ${deliveryAddress.mobileNumber}');
      if (kDebugMode) print('Email: ${deliveryAddress.emailId}');
      if (kDebugMode) print('Environment: LIVE');
      if (kDebugMode) print('💳 === OPENING RAZORPAY === 💳\n');
      
      // Initialize payment service
      final paymentService = ref.read(paymentServiceProvider);
      
      // Start payment - UPDATED to match your PaymentService implementation
      final paymentResult = await paymentService.startPayment(
        amount: amount,
        description: 'Order Payment - PatelMart',
        customerName: deliveryAddress.fullName,
        customerEmail: deliveryAddress.emailId,
        customerPhone: deliveryAddress.mobileNumber,
        customOrderId: customOrderId,
      );
      
      // Store payment result
      ref.read(paymentResultProvider.notifier).state = paymentResult;
      
      if (paymentResult.success) {
        logger.log('✅ PAYMENT SUCCESSFUL');
        logger.log('Payment ID: ${paymentResult.paymentId}');
        logger.log('Transaction Status: ${paymentResult.status}');
        logger.log('Payment Method: ${paymentResult.method}');
        
        if (kDebugMode) print('\n💳 === PAYMENT SUCCESSFUL === 💳');
        if (kDebugMode) print('Payment ID: ${paymentResult.paymentId}');
        if (kDebugMode) print('Status: ${paymentResult.status}');
        if (kDebugMode) print('Method: ${paymentResult.method}');
        if (kDebugMode) print('Amount: ₹${paymentResult.amount?.toStringAsFixed(2)}');
        if (kDebugMode) print('💳 === READY FOR ORDER UPDATE === 💳\n');
        
        return paymentResult;
      } else {
        logger.error('❌ PAYMENT FAILED');
        logger.error('Error: ${paymentResult.message}');
        
        if (kDebugMode) print('\n❌ === PAYMENT FAILED === ❌');
        if (kDebugMode) print('Payment Error: ${paymentResult.message}');
        if (kDebugMode) print('Error Code: ${paymentResult.error}');
        if (kDebugMode) print('Still proceeding to update database with failure status');
        if (kDebugMode) print('❌ === CONTINUING TO ORDER UPDATE === ❌\n');
        
        // Return the failed payment result to update database with failure
        return paymentResult;
      }
    } catch (e) {
      final logger = ref.read(loggerProvider);
      logger.error('❌ PAYMENT PROCESSING EXCEPTION: $e');
      
      if (kDebugMode) print('\n💥 === PAYMENT PROCESSING ERROR === 💥');
      if (kDebugMode) print('Error: $e');
      if (kDebugMode) print('💥 === END ERROR === 💥\n');
      
      // Return a failed payment result
      return PaymentResult(
        success: false,
        message: 'Payment processing error: $e',
        error: e,
        fullPaymentData: {
          'error': e.toString(),
          'error_timestamp': DateTime.now().millisecondsSinceEpoch,
        },
      );
    }
  }
  
  /// STEP 3: Update Order with Payment Details and Final Status
  /// This updates the database record with payment details and changes status based on payment result
  static Future<bool> updateOrderWithPaymentDetails({
    required WidgetRef ref,
    required String tempOrderId,
    required String deviceId,
    required String cartKey,
    required String storeCode,
    required List<CartItem> cartItems,
    required Address deliveryAddress,
    required String deliverySlot,
    required String deliveryDate,
    required String deliveryMode,
    required String paymentMode,
    required double finalAmount,
    required double cartTotal,
    required double cartSavings,
    required double deliveryCharge,
    String? accessKey,
    String? specialNotes,
    PaymentResult? paymentResult,
    int? deliverySlotId,
    int? paymentModeId,
  }) async {
    try {
      final logger = ref.read(loggerProvider);
      
      // Determine what the final status should be based on payment result
      String expectedOrderStatus;
      String expectedPaymentStatus;
      
      if (paymentMode.toLowerCase() == "online payment") {
        if (paymentResult != null && paymentResult.success) {
          expectedOrderStatus = "Order Confirmed";
          expectedPaymentStatus = "Payment Confirmed";
        } else {
          expectedOrderStatus = "Payment Failed";
          expectedPaymentStatus = "Payment Failed";
        }
      } else {
        expectedOrderStatus = "Order Confirmed";
        expectedPaymentStatus = "Pending";
      }
      
      logger.log('=== STEP 3: UPDATING DATABASE WITH PAYMENT DETAILS ===');
      logger.log('Temp Order ID: $tempOrderId');
      logger.log('Payment Success: ${paymentResult?.success ?? false}');
      logger.log('Expected Order Status: $expectedOrderStatus');
      logger.log('Expected Payment Status: $expectedPaymentStatus');
      logger.log('Transaction ID: ${paymentResult?.paymentId ?? "None"}');
      
      // Set UI status to show order is being confirmed
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.confirmingOrder;
      
      if (kDebugMode) print('\n📋 === UPDATING ORDER WITH PAYMENT DETAILS === 📋');
      if (kDebugMode) print('Temp Order ID: $tempOrderId');
      if (kDebugMode) print('Payment Success: ${paymentResult?.success ?? false}');
      if (kDebugMode) print('Expected Order Status: $expectedOrderStatus');
      if (kDebugMode) print('Expected Payment Status: $expectedPaymentStatus');
      if (kDebugMode) print('Transaction ID: ${paymentResult?.paymentId ?? "None"}');
      if (kDebugMode) print('Status Update: Payment Processing → $expectedOrderStatus');
      if (kDebugMode) print('📋 === CALLING ORDER CONFIRMATION API === 📋\n');
      
      // Call order confirmation service to update the database
      // UPDATED to match your OrderService implementation
      final orderService = ref.read(orderServiceProvider);
      final orderResult = await orderService.confirmOrder(
        deviceId: deviceId,
        cartKey: cartKey,
        tempOrderId: tempOrderId, // Same temp order ID to update existing record
        storeCode: storeCode,
        cartItems: cartItems,
        deliveryAddress: deliveryAddress,
        deliverySlot: deliverySlot,
        deliveryDate: deliveryDate,
        deliveryMode: deliveryMode,
        paymentMode: paymentMode,
        totalMrp: cartTotal + cartSavings,
        totalOurPrice: cartTotal,
        discount: cartSavings,
        deliveryCharges: deliveryCharge,
        discountedAmount: cartTotal,
        finalPayableAmount: finalAmount,
        paidAmount: (paymentResult?.success == true) ? finalAmount.toString() : "0",
        accessKey: accessKey,
        transactionId: paymentResult?.paymentId,
        specialNotes: specialNotes,
        paymentResult: paymentResult, // Pass the actual payment result (success or failure)
        paymentFormat: PaymentDataFormat.both,
        deliverySlotId: deliverySlotId,
        paymentModeId: paymentModeId,
      );
      
      // Store order result
      ref.read(orderConfirmationResultProvider.notifier).state = orderResult;
      
      logger.log('=== STEP 3 COMPLETED: ORDER UPDATE RESULT ===');
      logger.log('Order API Success: ${orderResult.success}');
      logger.log('Order ID: ${orderResult.orderId ?? "None"}');
      logger.log('Expected Status: $expectedOrderStatus');
      logger.log('API Message: ${orderResult.message}');
      
      if (orderResult.success) {
        // API call successful - determine the outcome based on payment result
        final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
        
        if (paymentResult != null && paymentResult.success && paymentMode.toLowerCase() == "online payment") {
          // Successful online payment
          ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.completed;
          await enhancedCartValidator.markOrderAsCompleted(tempOrderId);
          
          logger.log('✅ ORDER SUCCESSFULLY PLACED AND CONFIRMED');
          logger.log('Order ID: ${orderResult.orderId}');
          logger.log('Database Status: Order Confirmed');
          logger.log('Payment Status: Payment Confirmed');
          
          // Track successful purchase with Facebook Pixel
          _trackSuccessfulPurchase(ref, orderResult.orderId ?? 'unknown', cartItems, finalAmount);
          
          if (kDebugMode) print('\n🎉 === ORDER SUCCESSFULLY COMPLETED === 🎉');
          if (kDebugMode) print('Order ID: ${orderResult.orderId}');
          if (kDebugMode) print('Database Status: Order Confirmed');
          if (kDebugMode) print('Payment Status: Payment Confirmed');
          if (kDebugMode) print('Transaction ID: ${paymentResult.paymentId}');
          if (kDebugMode) print('Payment Processing → Order Confirmed ✅');
          if (kDebugMode) print('🎉 === ORDER FLOW COMPLETED === 🎉\n');
          
          return true;
          
        } else if (paymentMode.toLowerCase() != "online payment") {
          // Cash on Delivery
          ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.completed;
          await enhancedCartValidator.markOrderAsCompleted(tempOrderId);
          
          logger.log('✅ COD ORDER SUCCESSFULLY PLACED');
          logger.log('Order ID: ${orderResult.orderId}');
          logger.log('Database Status: Order Confirmed');
          logger.log('Payment Status: Pending');
          
          if (kDebugMode) print('\n🎉 === COD ORDER SUCCESSFULLY COMPLETED === 🎉');
          if (kDebugMode) print('Order ID: ${orderResult.orderId}');
          if (kDebugMode) print('Database Status: Order Confirmed');
          if (kDebugMode) print('Payment Status: Pending');
          if (kDebugMode) print('Payment Processing → Order Confirmed ✅');
          if (kDebugMode) print('🎉 === ORDER FLOW COMPLETED === 🎉\n');
          
          return true;
          
        } else {
          // Payment failed but database was updated with failure status
          ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
          ref.read(orderErrorMessageProvider.notifier).state = 'Payment failed';
          await enhancedCartValidator.markOrderAsFailed(tempOrderId);
          
          logger.log('✅ DATABASE UPDATED WITH PAYMENT FAILURE STATUS');
          logger.log('Order ID: ${orderResult.orderId}');
          logger.log('Database Status: Payment Failed');
          logger.log('Payment Status: Payment Failed');
          
          if (kDebugMode) print('\n❌ === PAYMENT FAILED BUT DATABASE UPDATED === ❌');
          if (kDebugMode) print('Order ID: ${orderResult.orderId}');
          if (kDebugMode) print('Database Status: Payment Failed');
          if (kDebugMode) print('Payment Status: Payment Failed');
          if (kDebugMode) print('Payment Processing → Payment Failed ✅');
          if (kDebugMode) print('Database Updated: ✅');
          if (kDebugMode) print('❌ === ORDER MARKED AS FAILED === ❌\n');
          
          return false;
        }
      } else {
        // API call itself failed
        logger.error('❌ ORDER CONFIRMATION API CALL FAILED');
        logger.error('Error: ${orderResult.message}');
        
  // Track successful purchase with Facebook Pixel
  void trackSuccessfulPurchase(
    WidgetRef ref,
    String? orderId,
    List<CartItem> cartItems,
    double totalAmount,
  ) {
    try {
      final productIds = cartItems.map((item) => item.product.pCode).toList();
      
      FacebookPixelIntegration.trackCheckoutEvent(
        ref,
        eventType: 'purchase',
        productIds: productIds,
        totalValue: totalAmount,
        numItems: cartItems.length,
        orderId: orderId ?? 'unknown',
        currency: 'INR',
      );
    } catch (e) {
      ref.read(loggerProvider).error('Failed to track purchase event: $e');
    }
  }
        
        // Mark order as failed
        final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
        await enhancedCartValidator.markOrderAsFailed(tempOrderId);
        
        // Set error state
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
        ref.read(orderErrorMessageProvider.notifier).state = 
          'Failed to confirm order: ${orderResult.message}';
        
        if (kDebugMode) print('\n❌ === ORDER CONFIRMATION API FAILED === ❌');
        if (kDebugMode) print('Error: ${orderResult.message}');
        if (kDebugMode) print('Database Status: Payment Processing (may be unchanged)');
        if (kDebugMode) print('❌ === ORDER FLOW FAILED === ❌\n');
        
        return false;
      }
    } catch (e) {
      final logger = ref.read(loggerProvider);
      logger.error('❌ EXCEPTION IN ORDER CONFIRMATION: $e');
      
      // Mark order as failed
      final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
      await enhancedCartValidator.markOrderAsFailed(tempOrderId);
      
      // Set error state
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
      ref.read(orderErrorMessageProvider.notifier).state = 'Order confirmation error: $e';
      
      if (kDebugMode) print('\n💥 === ORDER CONFIRMATION ERROR === 💥');
      if (kDebugMode) print('Error: $e');
      if (kDebugMode) print('💥 === END ERROR === 💥\n');
      
      return false;
    }
  }
  
  /// Complete Payment Flow - orchestrates all three steps
  static Future<bool> executeCompletePaymentFlow({
    required BuildContext context,
    required WidgetRef ref,
    required CheckoutData checkoutData,
    required PaymentMethod selectedPaymentMethod,
    required String specialInstructions,
  }) async {
    try {
      final logger = ref.read(loggerProvider);
      
      logger.log('🚀 === STARTING COMPLETE PAYMENT FLOW === 🚀');
      logger.log('Payment Method: ${selectedPaymentMethod.paymentModeName}');
      logger.log('Delivery Method: ${checkoutData.deliveryMethod}');
      logger.log('Customer: ${checkoutData.selectedAddress?.fullName ?? "Self Pickup"}');
      
      // STEP 0: Prepare fresh session and identifiers for new order
      logger.log('=== STEP 0: PREPARING FRESH SESSION FOR NEW ORDER ===');
      
      final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
      
      // Ensure we have a fresh session ready for this new order
      final sessionReady = await enhancedCartValidator.ensureSessionReadyForOrder();
      if (!sessionReady) {
        logger.error('Failed to prepare order session');
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
        ref.read(orderErrorMessageProvider.notifier).state = 'Failed to prepare order session';
        return false;
      }
      
      // Get required data
      final cartItems = ref.read(cartItemsProvider);
      final selectedOutlet = ref.read(selectedOutletProvider).value!;
      final userProfile = (await ref.read(authRepositoryProvider).currentSession()).valueOrNull;
      
      // Prepare completely fresh identifiers for this new order
      final cartNotifier = ref.read(cartProvider.notifier);
      final freshIdentifiers = await cartNotifier.prepareForNewOrder();
      final currentCartKey = freshIdentifiers['cart_key'];
      final currentDeviceId = freshIdentifiers['device_id'];
      final currentTempOrderId = freshIdentifiers['temp_order_id'];
      
      if (currentCartKey == null || currentDeviceId == null || currentTempOrderId == null) {
        logger.error('Failed to generate order identifiers');
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
        ref.read(orderErrorMessageProvider.notifier).state = 'Failed to generate order identifiers';
        return false;
      }
      
      final deviceId = currentDeviceId;
      final cartKey = currentCartKey;
      final tempOrderId = currentTempOrderId;
      
      // Calculate totals
      final cartTotal = ref.read(cartTotalProvider);
      final cartSavings = ref.read(cartSavingsProvider);
      final deliveryChargesState = ref.read(deliveryChargesProvider);
      final deliveryCharge = deliveryChargesState.deliveryCharge;
      final finalAmount = cartTotal + deliveryCharge;
      
      // Prepare delivery address
      Address deliveryAddress;
      if (checkoutData.deliveryMethod == DeliveryMethod.homeDelivery) {
        deliveryAddress = checkoutData.selectedAddress!;
      } else {
        // Self pickup address
        deliveryAddress = Address(
          id: 'pickup_address',
          fullName: userProfile?.mobile ?? 'Customer',
          mobileNumber: userProfile?.mobile ?? '',
          emailId: userProfile?.mobile ?? '',
          deliveryAddrLine1: selectedOutlet.name,
          deliveryAddrLine2: selectedOutlet.address,
          deliveryAddrCity: 'Store Location',
          deliveryAddrPincode: ref.read(selectedPincodeProvider) ?? '',
          state: '',
          landmark: selectedOutlet.name,
          areaId: selectedOutlet.storeCode,
          isDefault: 'No',
          latitude: selectedOutlet.latitude,
          longitude: selectedOutlet.longitude,
        );
      }
      
      // Prepare other details
      final deliverySlot = checkoutData.deliveryTimeSlot ?? "9:00 AM - 10:00 PM";
      final deliveryDate = checkoutData.deliveryDate?.toIso8601String().split('T')[0] ?? 
                          DateTime.now().add(Duration(days: 1)).toIso8601String().split('T')[0];
      final deliveryMode = checkoutData.deliveryMethod == DeliveryMethod.homeDelivery 
          ? "Home Delivery" : "Self Pickup";
      final paymentMode = selectedPaymentMethod.paymentModeName;
      
      if (kDebugMode) print('\n🚀 === PAYMENT FLOW OVERVIEW === 🚀');
      if (kDebugMode) print('Step 1: Create database entry with status "Payment Processing"');
      if (kDebugMode) print('Step 2: Process payment (if online)');
      if (kDebugMode) print('Step 3: Update database with payment details and final status');
      if (kDebugMode) print('');
      if (kDebugMode) print('Order Details:');
      if (kDebugMode) print('- Temp Order ID: $tempOrderId');
      if (kDebugMode) print('- Amount: ₹${finalAmount.toStringAsFixed(2)}');
      if (kDebugMode) print('- Payment: $paymentMode');
      if (kDebugMode) print('- Delivery: $deliveryMode');
      if (kDebugMode) print('- Customer: ${deliveryAddress.fullName}');
      if (kDebugMode) print('🚀 === STARTING EXECUTION === 🚀\n');
      
      // STEP 1: Mark order as Payment Processing (creates database entry)
      final step1Success = await markOrderAsPaymentProcessing(
        ref: ref,
        tempOrderId: tempOrderId,
        deviceId: deviceId,
        storeCode: selectedOutlet.storeCode,
        cartItems: cartItems,
        deliveryAddress: deliveryAddress,
        deliverySlot: deliverySlot,
        deliveryDate: deliveryDate,
        deliveryMode: deliveryMode,
        paymentMode: paymentMode,
        finalAmount: finalAmount,
        cartTotal: cartTotal,
        cartSavings: cartSavings,
        deliveryCharge: deliveryCharge,
        accessKey: userProfile?.accessToken,
        mobileNo: userProfile?.mobile,
        specialNotes: specialInstructions,
      );
      
      if (!step1Success) {
        logger.error('❌ STEP 1 FAILED: Could not create database entry');
        return false;
      }
      
      // STEP 2: Process Payment (for all payment types)
      final paymentResult = await processPayment(
        ref: ref,
        amount: finalAmount,
        deliveryAddress: deliveryAddress,
        paymentMode: paymentMode,
        customOrderId: tempOrderId,
      );
      
      if (paymentResult == null) {
        logger.error('❌ STEP 2 FAILED: Payment processing returned null');
        await enhancedCartValidator.markOrderAsFailed(tempOrderId);
        return false;
      }
      
      // STEP 3: Update order with payment details and final status (ALWAYS CALLED)
      final step3Success = await updateOrderWithPaymentDetails(
        ref: ref,
        tempOrderId: tempOrderId,
        deviceId: deviceId,
        cartKey: cartKey,
        storeCode: selectedOutlet.storeCode,
        cartItems: cartItems,
        deliveryAddress: deliveryAddress,
        deliverySlot: deliverySlot,
        deliveryDate: deliveryDate,
        deliveryMode: deliveryMode,
        paymentMode: paymentMode,
        finalAmount: finalAmount,
        cartTotal: cartTotal,
        cartSavings: cartSavings,
        deliveryCharge: deliveryCharge,
        accessKey: userProfile?.accessToken,
        specialNotes: specialInstructions,
        paymentResult: paymentResult,
        deliverySlotId: checkoutData.deliverySlotId,
      );
      
      if (step3Success) {
        // Clear cart and checkout data cache after successful order
        await ref.read(cartProvider.notifier).clearCart();
        await CheckoutData.clearFromPrefs();  // Clear cached checkout data including special notes
        logger.log('🎉 === COMPLETE PAYMENT FLOW SUCCESSFUL === 🎉');
        return true;
      } else {
        logger.error('❌ STEP 3 FAILED: Could not update order with payment details');
        return false;
      }
      
    } catch (e) {
      final logger = ref.read(loggerProvider);
      logger.error('💥 === PAYMENT FLOW EXCEPTION === 💥');
      logger.error('Error: $e');
      
      // Set error state
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
      ref.read(orderErrorMessageProvider.notifier).state = 'Unexpected error: $e';
      
      // Mark order as failed
      final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
      final prefs = await SharedPreferences.getInstance();
      final tempOrderId = prefs.getString('temp_order_id');
      if (tempOrderId != null) {
        await enhancedCartValidator.markOrderAsFailed(tempOrderId);
      }
      
      return false;
    }
  }
  
  // Track successful purchase with Facebook Pixel
  static void _trackSuccessfulPurchase(
    WidgetRef ref,
    String orderId,
    List<CartItem> cartItems,
    double totalAmount,
  ) {
    try {
      final productIds = cartItems.map((item) => item.product.pCode).toList();
      
      FacebookPixelIntegration.trackCheckoutEvent(
        ref,
        eventType: 'purchase',
        productIds: productIds,
        totalValue: totalAmount,
        numItems: cartItems.length,
        orderId: orderId,
        currency: 'INR',
      );
    } catch (e) {
      ref.read(loggerProvider).error('Failed to track purchase event: $e');
    }
  }
}