// Checkout step 4 of 4 — payment. Split out of checkout_flow_screen.dart.
// lib/presentation/features/checkout/checkout_flow_screen.dart

import 'package:flutter/material.dart';
import 'package:patelmart/core/utils/app_snackbar.dart';
import '../../../../core/utils/input_formatters.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/models/address_model.dart';
import 'package:patelmart/data/models/payment_method_model.dart';
import 'package:patelmart/data/services/payment_service.dart';
import 'package:patelmart/presentation/providers/cart_validator_provider.dart';
import 'package:patelmart/presentation/providers/delivery_charges_provider.dart';
import 'package:patelmart/presentation/providers/location_provider.dart';
import 'package:patelmart/presentation/providers/order_providers.dart';
import 'package:patelmart/presentation/providers/outlet_provider.dart';
import 'package:patelmart/presentation/providers/payment_method_provider.dart';
import 'package:patelmart/utils/payment_data_formatter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../providers/cart_provider.dart';
import '../../../providers/checkout_timer_provider.dart';
// FACEBOOK PIXEL IMPORTS
import '../../../../di/service_providers.dart';
import '../../../../di/infrastructure_providers.dart';
import '../../../../di/auth_providers.dart';
import '../../../../domain/entities/auth_session.dart';
import 'package:flutter/foundation.dart';
import '../../../providers/loyalty_provider.dart';
import '../../../providers/steal_deals_provider.dart'
    show selectedCartOfferProvider, dealProductOfferInfoProvider;
import '../checkout_models.dart';
import '../widgets/loyalty_reward_picker.dart';
import '../widgets/cart_offer_picker.dart';
import 'order_success_dialog.dart';

// Checkout step enum to track progress

class PaymentStep extends ConsumerStatefulWidget {
  final CheckoutData checkoutData;

  const PaymentStep({
    super.key,
    required this.checkoutData,
  });

  @override
  ConsumerState<PaymentStep> createState() => _PaymentStepState();
}

class _PaymentStepState extends ConsumerState<PaymentStep> {
  PaymentMethod? _selectedPaymentMethod;
  final TextEditingController _instructionsController = TextEditingController();
  final TextEditingController _pickupNameController = TextEditingController();
  bool _isPlacingOrder = false;

  /// Last reason the order was refused, shown inline above PLACE ORDER.
  ///
  /// Exists because a SnackBar is not a dependable channel here: when the
  /// messenger is wedged, showAppSnackBar swallows the failure and the shopper
  /// is left tapping a button that does nothing.
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _instructionsController.text = widget.checkoutData.specialInstructions ?? '';
    _pickupNameController.text = widget.checkoutData.pickupName ?? '';

    // Reset the order state when initializing the payment step
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.initial;
      ref.read(orderErrorMessageProvider.notifier).state = null;

      // Try to restore previously selected payment method
      _restoreSelectedPaymentMethod();
    });
  }

  @override
  void dispose() {
    // Stop checkout timer when leaving checkout
    ref.read(checkoutTimerProvider.notifier).stopTimer();
    _instructionsController.dispose();
    _pickupNameController.dispose();
    super.dispose();
  }

  void _restoreSelectedPaymentMethod() {
    // If we have a previously selected payment method in checkoutData, try to restore it
    if (widget.checkoutData.paymentMethod != null) {
      final paymentMethodsAsync = ref.read(paymentMethodsProvider);
      paymentMethodsAsync.whenData((methods) {
        // Try to find the method by name
        final previousMethod = methods.firstWhere(
          (method) => method.paymentModeName == widget.checkoutData.paymentMethod ||
                      method.displayName == widget.checkoutData.paymentMethod,
          orElse: () => methods.isNotEmpty ? methods.first : PaymentMethod(
            id: '',
            idPaymentMode: 0,
            paymentModeName: 'Unknown',
          ),
        );
        
        if (previousMethod.idPaymentMode > 0) {
          setState(() {
            _selectedPaymentMethod = previousMethod;
          });
          ref.read(selectedPaymentMethodProvider.notifier).state = previousMethod;
        }
      });
    }
  }

  void _selectPaymentMethod(PaymentMethod method) {
    setState(() {
      _selectedPaymentMethod = method;
    });
    
    // Update providers
    ref.read(selectedPaymentMethodProvider.notifier).state = method;
    widget.checkoutData.paymentMethod = method.paymentModeName;
    
    final logger = ref.read(loggerProvider);
    logger.log('Selected payment method: ${method.displayName} (${method.paymentModeName})');
  }

  /// Reports [message] both ways: the SnackBar as before, and an inline
  /// banner above PLACE ORDER.
  ///
  /// The SnackBar alone is not dependable — showAppSnackBar swallows failures
  /// when the messenger is in a bad state, and it silently was here. Every one
  /// of these checks then aborted the order with no feedback whatsoever: the
  /// button simply did nothing.
  bool _failValidation(String message) {
    if (kDebugMode) print('[ORDER] validation failed: $message');
    _safeSetState(() => _validationError = message);
    _showErrorSnackBar(message);
    return false;
  }

  // Validate cart and ensure we have required data
  bool _validateOrderData() {
    if (kDebugMode) {
      print('[ORDER] validating | method=${_selectedPaymentMethod?.paymentModeName} '
          '| delivery=${widget.checkoutData.deliveryMethod} '
          '| address=${widget.checkoutData.selectedAddress != null} '
          '| date=${widget.checkoutData.deliveryDate != null} '
          '| slot=${widget.checkoutData.deliveryTimeSlot}');
    }
    _safeSetState(() => _validationError = null);
    // Check payment method
    if (_selectedPaymentMethod == null) {
      return _failValidation('Please select a payment method');
    }
    
    // Check if we have a delivery address (for home delivery)
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery &&
        widget.checkoutData.selectedAddress == null) {
      return _failValidation('Please select a delivery address');
    }

    // Validate address fields for home delivery (critical for online payment)
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery &&
        widget.checkoutData.selectedAddress != null) {
      final address = widget.checkoutData.selectedAddress!;

      // Check that address has required fields for payment
      if (address.mobileNumber.isEmpty || address.mobileNumber.trim().isEmpty) {
        return _failValidation('Address is missing mobile number. Please select a different address or update this one.');
      }



      if (address.fullName.isEmpty || address.fullName.trim().isEmpty) {
        return _failValidation('Address is missing recipient name. Please select a different address or update this one.');
      }
    }

    // Check if we have delivery date and time slot (for home delivery)
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery) {
      if (widget.checkoutData.deliveryDate == null) {
        return _failValidation('Please select a delivery date');
      }
      if (widget.checkoutData.deliveryTimeSlot == null ||
          widget.checkoutData.deliveryTimeSlot!.isEmpty) {
        return _failValidation('Please select a delivery time slot');
      }
    }

    // Check pickup name for self-pickup
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup) {
      if (widget.checkoutData.pickupName == null || widget.checkoutData.pickupName!.trim().isEmpty) {
        return _failValidation('Please enter your pickup name');
      }
    }
    
    // Check cart not empty
    final cartItems = ref.read(cartItemsProvider);
    if (cartItems.isEmpty) {
      return _failValidation('Your cart is empty');
    }
    
    // Check outlet selected
    final selectedOutlet = ref.read(selectedOutletProvider).value;
    if (selectedOutlet == null) {
      return _failValidation('No store selected');
    }
    
    return true;
  }

  /// Shows [message] through the app-level messenger.
  ///
  /// Deliberately not `ScaffoldMessenger.of(context)`, and deliberately not a
  /// messenger captured from this step either: both resolve to the checkout
  /// route's own messenger, which dies with the route, and `showSnackBar` then
  /// throws from its internal ancestor lookup.
  ///
  /// Every caller runs after at least one `await`, and that throw was caught by
  /// _placeOrder's own catch and shown to the shopper as "Order Failed" — for
  /// an order that had already been paid for.
  void _showErrorSnackBar(String message) {
    showAppSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  /// setState that tolerates the step having been disposed mid-flow.
  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    setState(fn);
  }

  String _buildSpecialNotes(AuthSession? userProfile) {
    final List<String> notes = [];

    // Add typed special instructions if provided
    final instructions = _instructionsController.text.trim();
    if (instructions.isNotEmpty) {
      notes.add(instructions);
    }

    // For self-pickup, add pickup name info
    if (widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup) {
      final pickupName = widget.checkoutData.pickupName?.trim().isNotEmpty == true
          ? widget.checkoutData.pickupName!
          : (userProfile?.mobile ?? '');
      notes.add('Pickup Name: $pickupName');
    }

    // Add profile name (using mobile since no explicit name field exists)
    final profileName = userProfile?.mobile ?? '';
    if (profileName.isNotEmpty) {
      notes.add('Profile Name: $profileName');
    }

    // Add mobile number
    final mobile = userProfile?.mobile ?? '';
    if (mobile.isNotEmpty) {
      notes.add('Mobile: $mobile');
    }

    // Join with " | " separator
    return notes.join(' | ');
  }





// Complete _placeOrder method for PaymentStep class in checkout_flow_screen.dart
// This works with the updated OrderService that handles payment failures
// Replace your existing _placeOrder method entirely with this one

// Complete _placeOrder method for PaymentStep class in checkout_flow_screen.dart
// Replace your existing _placeOrder method with this version that uses your current implementation

Future<void> _placeOrder() async {
  if (kDebugMode) print('\n[ORDER] ===== PLACE ORDER TAPPED =====');

  // Save instructions
  widget.checkoutData.specialInstructions = _instructionsController.text;

  // Save all checkout data
  await widget.checkoutData.saveToPrefs();

  // Validate order data
  if (!_validateOrderData()) {
    if (kDebugMode) print('[ORDER] STOP: pre-flight validation refused it');
    return;
  }
  if (kDebugMode) print('[ORDER] validation passed — starting payment flow');

  _safeSetState(() {
    _isPlacingOrder = true;
  });

  // Whether the order reached the backend, and what it said. The catch below
  // uses these to tell "the order failed" apart from "the screen fell over
  // after the order was already placed".
  var orderReachedBackend = false;
  var orderConfirmed = false;

  try {
    // Access logger through provider
    final logger = ref.read(loggerProvider);
    
    logger.log('🚀 === COMPLETE PAYMENT FLOW WITH FAILURE HANDLING STARTED === 🚀');
    logger.log('Payment Method: ${_selectedPaymentMethod!.paymentModeName}');
    logger.log('Delivery Method: ${widget.checkoutData.deliveryMethod}');
    
    // STEP 0: Prepare fresh session and identifiers for new order
    logger.log('=== STEP 0: PREPARING FRESH SESSION FOR NEW ORDER ===');
    
    final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
    
    // Ensure we have a fresh session ready for this new order
    final sessionReady = await enhancedCartValidator.ensureSessionReadyForOrder();
    if (!sessionReady) {
      _safeSetState(() {
        _isPlacingOrder = false;
      });
      _showErrorSnackBar("Failed to prepare order session. Please try again.");
      return;
    }
    
    // Prepare completely fresh identifiers for this new order using your existing implementation
    final cartNotifier = ref.read(cartProvider.notifier);
    final freshIdentifiers = await cartNotifier.prepareForNewOrder();
    final currentCartKey = freshIdentifiers['cart_key'];
    final currentDeviceId = freshIdentifiers['device_id'];
    final currentTempOrderId = freshIdentifiers['temp_order_id'];
    
    if (currentCartKey == null || currentDeviceId == null || currentTempOrderId == null) {
      _safeSetState(() {
        _isPlacingOrder = false;
      });
      _showErrorSnackBar("Failed to generate order identifiers. Please try again.");
      return;
    }
    
    String deviceId = currentDeviceId;
    String cartKey = currentCartKey;
    String tempOrderId = currentTempOrderId;
    
    logger.log('Fresh identifiers generated:');
    logger.log('- Fresh Temp Order ID: $tempOrderId');
    logger.log('- Fresh Cart Key: $cartKey');
    logger.log('- Device ID: $deviceId');
    
    // Get required data
    final cartItems = ref.read(cartItemsProvider);
    final selectedOutlet = ref.read(selectedOutletProvider).value!;
    
    // Get the user profile to access the access key and mobile number.
    //
    // No session means no identity to place an order against, and every call
    // below is authenticated. This used to fall through with accessKey and
    // mobileNo left null: the order was attempted anyway and died deep in the
    // flow as "Access denied. No token provided.", which reads like a server
    // fault. Stop here and say the real thing instead.
    final userProfile =
        (await ref.read(authRepositoryProvider).currentSession()).valueOrNull;
    if (userProfile == null) {
      if (kDebugMode) print('[ORDER] STOP: no valid session at order time');
      _safeSetState(() => _isPlacingOrder = false);
      ref.read(orderProcessStatusProvider.notifier).state =
          OrderProcessStatus.failed;
      _failValidation(
          'Your session has expired. Please sign in again to place this order.');
      return;
    }

    final String accessKey = userProfile.accessToken;
    final String mobileNo = userProfile.mobile;

    // Prepare delivery address
    Address deliveryAddress;

    if (widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery) {
      deliveryAddress = widget.checkoutData.selectedAddress!;

      // CRITICAL: Ensure address has valid payment fields for Razorpay
      if (deliveryAddress.mobileNumber.isEmpty ||
          deliveryAddress.fullName.isEmpty) {
        _showErrorSnackBar('Address details incomplete. Cannot process payment. Please select or update your address.');
        setState(() {
          _isPlacingOrder = false;
        });
        return;
      }
    } else {
      // Self pickup: no real address. This stub exists only to satisfy the
      // non-null Address type consumed below for logging and Razorpay's
      // prefill (customerName/Email/Phone) — its id is never sent to the
      // backend (see order_service.dart's confirmOrder, which omits
      // address_id entirely for pickup orders).
      // userProfile is non-null from here — the session is checked above — so
      // these no longer need to cope with an anonymous shopper.
      final mobileForPayment = userProfile.mobile.isNotEmpty
          ? userProfile.mobile
          : '9999999999'; // Fallback mobile for payment

      // Generate valid email from mobile or use default
      final emailForPayment = userProfile.mobile.isNotEmpty
          ? '${userProfile.mobile}@customer.patelrmart.com'
          : 'orders@patelrmart.com';

      deliveryAddress = Address(
        id: '',
        fullName: widget.checkoutData.pickupName?.trim().isNotEmpty == true
            ? widget.checkoutData.pickupName!
            : userProfile.mobile,
        mobileNumber: mobileForPayment,
        emailId: emailForPayment,
        deliveryAddrLine1: '',
        deliveryAddrLine2: '',
        deliveryAddrCity: '',
        deliveryAddrPincode: '',
        state: '',
        areaId: selectedOutlet.storeCode,
        isDefault: 'No',
      );
    }
    
    // Get delivery slot and date
    final deliverySlot = widget.checkoutData.deliveryTimeSlot ?? "9:00 AM - 10:00 PM";
    final deliveryDate = widget.checkoutData.deliveryDate?.toIso8601String().split('T')[0] ?? 
                        DateTime.now().add(Duration(days: 1)).toIso8601String().split('T')[0];
    
    // Calculate cart totals
    double cartTotal = 0;
    double cartSavings = 0;
    
    for (final item in cartItems) {
      cartTotal += item.totalPrice;
      cartSavings += item.savings;
    }
    
    // Get delivery/packing charges
    final deliveryChargesState = ref.read(deliveryChargesProvider);
    final deliveryCharge = deliveryChargesState.deliveryCharge;
    final isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;
    // Self-pickup carries only the packing fee, never the delivery/handling
    // charge — this is the amount actually charged via Razorpay below, so
    // getting it right matters more than the display-only widgets.
    final extraCharge = isSelfPickup ? deliveryChargesState.packingFee : deliveryCharge;

    // Cart-discount offer, if applied — see CartOfferRow. selectedCartOfferProvider
    // is already kept in sync with eligibility by stealDealsOffersProvider's
    // refetch cycle (cleared/reselected whenever the cart total changes), but
    // `unlocked` is re-checked here too as a final guard against a stale
    // selection slipping through between refetches. The server independently
    // re-validates offer_id at place-order time regardless (utils/orderService.js's
    // applyCartOffer) — this only keeps what's charged in sync with what's shown.
    final selectedCartOffer = ref.read(selectedCartOfferProvider);
    final cartOfferDiscount =
        (selectedCartOffer != null && selectedCartOffer.unlocked) ? selectedCartOffer.effectiveDiscount : 0.0;
    final offerId = cartOfferDiscount > 0 ? selectedCartOffer?.id : null;

    // Subtotal after the cart offer, before loyalty — matches the backend's
    // own stacking order (utils/orderService.js applies the cart discount
    // first, then computes the loyalty redemption's discount against what's
    // left), so this estimate and the server's authoritative one agree.
    final subtotalAfterOffer = cartTotal - cartOfferDiscount;

    // Loyalty reward voucher, if applied — see LoyaltyRewardRow. Re-checked
    // here (not just trusted from when it was selected) in case the cart
    // changed since, e.g. dropping below the voucher's minimum order value;
    // estimateDiscount returns null in that case and nothing is deducted.
    // The server enforces this authoritatively regardless (place-order
    // rejects an id that no longer qualifies), this just keeps what's
    // charged in sync with what's shown.
    final selectedRedemption = ref.read(selectedLoyaltyRedemptionProvider);
    final loyaltyDiscount = selectedRedemption?.estimateDiscount(
          orderSubtotal: subtotalAfterOffer,
          deliveryCharges: deliveryCharge,
        ) ??
        0;
    final loyaltyRedemptionId = loyaltyDiscount > 0 ? selectedRedemption?.id : null;

    // Product-deal ("Steal Deals") lines, if any are in the cart — see
    // dealProductOfferInfoProvider. Quantity is capped to the deal's own
    // max_quantity; the server applies the same cap independently
    // (utils/orderService.js's applyDeals), this just keeps the two in sync.
    final dealProductInfo = ref.read(dealProductOfferInfoProvider);
    final dealItems = <Map<String, dynamic>>[];
    for (final item in cartItems) {
      final info = dealProductInfo[item.product.pCode];
      if (info == null) continue;
      dealItems.add({
        'offer_id': info.offerId,
        'p_code': item.product.pCode,
        'quantity': item.quantity > info.maxQuantity ? info.maxQuantity : item.quantity,
      });
    }

    // Calculate final amount
    final finalAmount = subtotalAfterOffer + extraCharge - loyaltyDiscount;

    // Get delivery mode and payment mode
    final deliveryMode = widget.checkoutData.deliveryMethod == DeliveryMethod.homeDelivery 
        ? "Home Delivery"
        : "Self Pickup";
    
    final paymentMode = _selectedPaymentMethod!.paymentModeName;
    
    logger.log('=== ORDER DETAILS ===');
    logger.log('Delivery Mode: $deliveryMode');
    logger.log('Payment Mode: $paymentMode');
    logger.log('Cart Total: ₹${cartTotal.toStringAsFixed(2)}');
    logger.log('Delivery Charge: ₹${deliveryCharge.toStringAsFixed(2)}');
    logger.log('Final Amount: ₹${finalAmount.toStringAsFixed(2)}');
    logger.log('Customer: ${deliveryAddress.fullName}');
    
    // STEP 1: Mark order as "Payment Processing" - CREATE DATABASE ENTRY
    logger.log('=== STEP 1: CREATING DATABASE ENTRY WITH PAYMENT PROCESSING STATUS ===');
    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.markingPaymentProcessing;
    
    await enhancedCartValidator.markOrderAsPaymentProcessing(tempOrderId);
    
    if (kDebugMode) print('\n🔄 === STEP 1: CREATING DATABASE ENTRY === 🔄');
    if (kDebugMode) print('Temp Order ID: $tempOrderId');
    if (kDebugMode) print('Payment Mode: $paymentMode');
    if (kDebugMode) print('Amount: ₹${finalAmount.toStringAsFixed(2)}');
    if (kDebugMode) print('Customer: ${deliveryAddress.fullName}');
    if (kDebugMode) print('Database Status: Payment Processing');
    if (kDebugMode) print('🔄 === CALLING PAYMENT PROCESSING API === 🔄\n');
    
    // Call the order payment processing API to create database entry
    final paymentProcessingService = ref.read(orderPaymentProcessingServiceProvider);
    final paymentProcessingResult = await paymentProcessingService.markOrderAsPaymentProcessing(
      deviceId: deviceId,
      tempOrderId: tempOrderId,
      storeCode: selectedOutlet.storeCode,
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
      specialNotes: _buildSpecialNotes(userProfile),
    );
    
    // Store payment processing result
    ref.read(orderPaymentProcessingResultProvider.notifier).state = paymentProcessingResult;
    
    // Check if payment processing API call was successful
    if (!paymentProcessingResult.success) {
      _safeSetState(() {
        _isPlacingOrder = false;
      });
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
      ref.read(orderErrorMessageProvider.notifier).state = 
        'Failed to create order entry: ${paymentProcessingResult.message}';
      
      // Mark order as failed - this will create a new session automatically
      await enhancedCartValidator.markOrderAsFailed(tempOrderId);
      
      _showErrorSnackBar('Failed to create order entry. Please try again.');
      return;
    }
    
    logger.log('✅ DATABASE ENTRY CREATED SUCCESSFULLY');
    logger.log('Order ID: ${paymentProcessingResult.orderId ?? "Generated"}');
    logger.log('Database Status: Payment Processing');
    
    if (kDebugMode) print('\n✅ === STEP 1 COMPLETED: DATABASE ENTRY CREATED === ✅');
    if (kDebugMode) print('Order ID: ${paymentProcessingResult.orderId ?? "Generated"}');
    if (kDebugMode) print('Database Status: Payment Processing');
    if (kDebugMode) print('✅ === PROCEEDING TO PAYMENT === ✅\n');
    
    String? transactionId;
    PaymentResult? paymentResult;
    
    // STEP 2: Process payment (handle both success and failure)
    if (paymentMode.toLowerCase() == "online payment") {
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.processingPayment;
      
      logger.log('=== STEP 2: PROCESSING ONLINE PAYMENT ===');
      logger.log('Payment Method: ${_selectedPaymentMethod!.displayName}');
      logger.log('Final Amount: ₹${finalAmount.toStringAsFixed(2)}');
      
      if (kDebugMode) print('\n💳 === STEP 2: INITIATING ONLINE PAYMENT === 💳');
      if (kDebugMode) print('Amount: ₹${finalAmount.toStringAsFixed(2)}');
      if (kDebugMode) print('Customer: ${deliveryAddress.fullName}');
      if (kDebugMode) print('Phone: ${deliveryAddress.mobileNumber}');
      if (kDebugMode) print('Email: ${deliveryAddress.emailId}');
      if (kDebugMode) print('💳 === OPENING RAZORPAY CHECKOUT === 💳\n');
      
      // Initialize payment service
      final paymentService = ref.read(paymentServiceProvider);
      
      // Start Razorpay payment
      paymentResult = await paymentService.startPayment(
        amount: finalAmount,
        description: 'Order Payment - PatelMart',
        customerName: deliveryAddress.fullName,
        customerEmail: deliveryAddress.emailId,
        customerPhone: deliveryAddress.mobileNumber,
        customOrderId: tempOrderId, // Pass temp order ID as custom order ID
      );
      
      // Store payment result in provider
      ref.read(paymentResultProvider.notifier).state = paymentResult;
      
      logger.log('=== STEP 2 COMPLETED: PAYMENT RESULT ===');
      logger.log('Payment Success: ${paymentResult.success}');
      logger.log('Payment ID: ${paymentResult.paymentId ?? "None"}');
      logger.log('Status: ${paymentResult.status ?? "Unknown"}');
      logger.log('Method: ${paymentResult.method ?? "Unknown"}');
      logger.log('Error Message: ${paymentResult.message ?? "None"}');
      
      if (paymentResult.success) {
        transactionId = paymentResult.paymentId;
        
        if (kDebugMode) print('\n💳 === STEP 2: PAYMENT SUCCESSFUL === 💳');
        if (kDebugMode) print('Payment ID: ${paymentResult.paymentId}');
        if (kDebugMode) print('Status: ${paymentResult.status}');
        if (kDebugMode) print('Method: ${paymentResult.method}');
        if (kDebugMode) print('💳 === PROCEEDING TO ORDER CONFIRMATION === 💳\n');
      } else if (paymentResult.wasCancelledByUser) {
        // The customer closed the Razorpay sheet. Nothing went wrong, so the
        // order must not be recorded as "Payment Failed" — leave them on the
        // payment step to try again or change method.
        logger.log('Payment cancelled by customer — leaving order open');
        ref.read(orderProcessStatusProvider.notifier).state =
            OrderProcessStatus.initial;
        if (mounted) {
          showAppSnackBar(
            const SnackBar(content: Text('Payment cancelled.')),
          );
        }
        return;
      } else {
        // Payment failed - but continue to Step 3 to update database with failure
        logger.log('❌ PAYMENT FAILED - CONTINUING TO UPDATE DATABASE WITH FAILURE STATUS');
        logger.log('Payment Error: ${paymentResult.message}');
        logger.log('Will update order status to "Payment Failed"');
        
        if (kDebugMode) print('\n❌ === STEP 2: PAYMENT FAILED === ❌');
        if (kDebugMode) print('Payment Error: ${paymentResult.message}');
        if (kDebugMode) print('Error Code: ${paymentResult.error}');
        if (kDebugMode) print('Still proceeding to update database with failure status');
        if (kDebugMode) print('Database will be updated: Payment Processing → Payment Failed');
        if (kDebugMode) print('❌ === CONTINUING TO ORDER UPDATE === ❌\n');
        
        // Continue to Step 3 with failed payment result
        // transactionId remains null for failed payments
      }
    } else {
      // For COD, create a successful mock payment result
      paymentResult = PaymentResult(
        success: true,
        paymentId: 'COD_${DateTime.now().millisecondsSinceEpoch}',
        message: 'Cash on Delivery',
        fullPaymentData: {
          'payment_method': 'Cash on Delivery',
          'amount': finalAmount,
          'status': 'pending',
          'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000,
        },
      );
      
      if (kDebugMode) print('\n💰 === STEP 2: CASH ON DELIVERY === 💰');
      if (kDebugMode) print('Payment Method: Cash on Delivery');
      if (kDebugMode) print('No online payment required');
      if (kDebugMode) print('Database will be updated: Payment Processing → Order Confirmed');
      if (kDebugMode) print('💰 === PROCEEDING TO ORDER CONFIRMATION === 💰\n');
    }
    
    // STEP 3: Update order with proper status based on payment result (ALWAYS CALLED)
    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.confirmingOrder;
    
    logger.log('=== STEP 3: UPDATING DATABASE WITH FINAL STATUS ===');
    logger.log('Using Temp Order ID: $tempOrderId');
    logger.log('Payment Success: ${paymentResult.success}');
    logger.log('Transaction ID: ${transactionId ?? "None"}');
    
    // Determine what the final status should be
    String expectedOrderStatus;
    String expectedPaymentStatus;
    
    if (paymentMode.toLowerCase() == "online payment") {
      if (paymentResult.success) {
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
    
    if (kDebugMode) print('\n📋 === STEP 3: UPDATING ORDER WITH FINAL STATUS === 📋');
    if (kDebugMode) print('Temp Order ID: $tempOrderId');
    if (kDebugMode) print('Payment Success: ${paymentResult.success}');
    if (kDebugMode) print('Expected Order Status: $expectedOrderStatus');
    if (kDebugMode) print('Expected Payment Status: $expectedPaymentStatus');
    if (kDebugMode) print('Transaction ID: ${transactionId ?? "None"}');
    if (kDebugMode) print('Status Update: Payment Processing → $expectedOrderStatus');
    if (kDebugMode) print('📋 === CALLING ORDER CONFIRMATION API === 📋\n');
    
    // CRITICAL: Call order confirmation API with the payment result (success or failure)
    // The updated OrderService will automatically handle the status based on paymentResult
    final orderService = ref.read(orderServiceProvider);
    final orderResult = await orderService.confirmOrder(
      deviceId: deviceId,
      cartKey: cartKey,
      tempOrderId: tempOrderId, // Same temp order ID to update existing record
      storeCode: selectedOutlet.storeCode,
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
      paidAmount: (paymentResult.success == true) ? finalAmount.toString() : "0",
      accessKey: accessKey,
      transactionId: transactionId,
      specialNotes: _buildSpecialNotes(userProfile),
      paymentResult: paymentResult, // Pass the actual payment result (success or failure)
      paymentFormat: PaymentDataFormat.both,
      deliverySlotId: widget.checkoutData.deliverySlotId,
      paymentModeId: _selectedPaymentMethod?.idPaymentMode,
      deliveryDistance: ref.read(deliveryChargesProvider).distance,
      loyaltyRedemptionId: loyaltyRedemptionId,
      offerId: offerId,
      dealItems: dealItems,
    );

    // Store order result
    ref.read(orderConfirmationResultProvider.notifier).state = orderResult;

    // From here the backend has an answer, so a later throw is a client-side
    // problem rather than a failed order. `orderConfirmed` is set only in the
    // branches below that actually complete the order — `orderResult.success`
    // alone is not enough, since the confirmation call also succeeds when it
    // is recording a FAILED payment.
    orderReachedBackend = true;
    
    logger.log('=== STEP 3 COMPLETED: ORDER UPDATE RESULT ===');
    logger.log('Order API Success: ${orderResult.success}');
    logger.log('Order ID: ${orderResult.orderId ?? "None"}');
    logger.log('Expected Status: $expectedOrderStatus');
    logger.log('API Message: ${orderResult.message}');
    
    if (orderResult.success) {
      // API call successful - determine the outcome based on the message or payment result
      if (paymentResult.success && paymentMode.toLowerCase() == "online payment") {
        // Successful online payment
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.completed;
        await enhancedCartValidator.markOrderAsCompleted(tempOrderId);
        orderConfirmed = true;
        
        logger.log('✅ ORDER SUCCESSFULLY PLACED AND CONFIRMED');
        logger.log('Order ID: ${orderResult.orderId}');
        logger.log('Database Status: Order Confirmed');
        logger.log('Payment Status: Payment Confirmed');

        if (kDebugMode) print('\n🎉 === ORDER SUCCESSFULLY COMPLETED === 🎉');
        if (kDebugMode) print('Order ID: ${orderResult.orderId}');
        if (kDebugMode) print('Database Status: Order Confirmed');
        if (kDebugMode) print('Payment Status: Payment Confirmed');
        if (kDebugMode) print('Transaction ID: $transactionId');
        if (kDebugMode) print('Payment Processing → Order Confirmed ✅');
        if (kDebugMode) print('🎉 === ORDER FLOW COMPLETED === 🎉\n');

        // Stop checkout timer on successful order completion
        ref.read(checkoutTimerProvider.notifier).stopTimer();

        // Clear cart, checkout data cache, and show success
        await ref.read(cartProvider.notifier).clearCart();
        await CheckoutData.clearFromPrefs();  // Clear cached checkout data including special notes
        // The applied voucher (if any) is now spent server-side — drop the
        // selection and refetch so it stops appearing as available.
        ref.read(selectedLoyaltyRedemptionProvider.notifier).state = null;
        ref.read(loyaltyRefreshProvider.notifier).state++;
        // Same for a cart-discount offer — it's not a reusable coupon, so
        // don't leave it selected for the next order.
        ref.read(selectedCartOfferProvider.notifier).state = null;
        // _safeSetState, and before the mounted check rather than after it:
        // clearCart() and clearFromPrefs() are awaits, so the step can be gone
        // by the time they return, and a plain setState then throws
        // "setState() called after dispose()" on an order that succeeded.
        _safeSetState(() {
          _isPlacingOrder = false;
        });
        if (!mounted) return;
        showOrderSuccessDialog(
            context, ref, widget.checkoutData, orderResult.orderId ?? tempOrderId);
        
      } else if (paymentMode.toLowerCase() != "online payment") {
        // Cash on Delivery
        ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.completed;
        await enhancedCartValidator.markOrderAsCompleted(tempOrderId);
        orderConfirmed = true;
        
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

        // Stop checkout timer on successful order completion
        ref.read(checkoutTimerProvider.notifier).stopTimer();

        // Clear cart, checkout data cache, and show success
        await ref.read(cartProvider.notifier).clearCart();
        await CheckoutData.clearFromPrefs();  // Clear cached checkout data including special notes
        // The applied voucher (if any) is now spent server-side — drop the
        // selection and refetch so it stops appearing as available.
        ref.read(selectedLoyaltyRedemptionProvider.notifier).state = null;
        ref.read(loyaltyRefreshProvider.notifier).state++;
        // Same for a cart-discount offer — it's not a reusable coupon, so
        // don't leave it selected for the next order.
        ref.read(selectedCartOfferProvider.notifier).state = null;
        // _safeSetState, and before the mounted check rather than after it:
        // clearCart() and clearFromPrefs() are awaits, so the step can be gone
        // by the time they return, and a plain setState then throws
        // "setState() called after dispose()" on an order that succeeded.
        _safeSetState(() {
          _isPlacingOrder = false;
        });
        if (!mounted) return;
        showOrderSuccessDialog(
            context, ref, widget.checkoutData, orderResult.orderId ?? tempOrderId);
        
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
        
        setState(() {
          _isPlacingOrder = false;
        });
        
        // Show payment failure message
        _showErrorSnackBar('Payment failed . Please try again.');
      }
      
    } else {
      // API call itself failed
      _safeSetState(() {
        _isPlacingOrder = false;
      });
      ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
      ref.read(orderErrorMessageProvider.notifier).state = orderResult.message;
      await enhancedCartValidator.markOrderAsFailed(tempOrderId);
      
      logger.error('❌ Order confirmation API call failed: ${orderResult.message}');
      if (kDebugMode) print('\n❌ === ORDER CONFIRMATION API FAILED === ❌');
      if (kDebugMode) print('Error: ${orderResult.message}');
      if (kDebugMode) print('Database Status: Payment Processing (may be unchanged)');
      if (kDebugMode) print('❌ === ORDER FLOW FAILED === ❌\n');
      
      _showErrorSnackBar('Order confirmation failed: ${orderResult.message}');
    }
    
  } catch (e, stack) {
    _safeSetState(() {
      _isPlacingOrder = false;
    });

    final logger = ref.read(loggerProvider);

    // An order the backend already confirmed must never be flipped to
    // "failed" by a client-side throw. The money is taken and the order is
    // real; overwriting the status here showed the shopper "Order Failed" for
    // an order that had gone through, and markOrderAsFailed then tore down the
    // session that was tracking it.
    //
    // This is exactly what happened with "Looking up a deactivated widget's
    // ancestor is unsafe": a widget-lifecycle error, thrown after payment
    // succeeded, presented as a failed order.
    if (orderConfirmed) {
      logger.error(
          'Order was confirmed but the checkout screen threw afterwards: $e');
      logger.error('$stack');

      ref.read(orderProcessStatusProvider.notifier).state =
          OrderProcessStatus.completed;

      // Still clean up what the success path would have: the cart is paid for.
      try {
        ref.read(checkoutTimerProvider.notifier).stopTimer();
        await ref.read(cartProvider.notifier).clearCart();
        await CheckoutData.clearFromPrefs();
        ref.read(selectedLoyaltyRedemptionProvider.notifier).state = null;
        ref.read(loyaltyRefreshProvider.notifier).state++;
        ref.read(selectedCartOfferProvider.notifier).state = null;
      } catch (cleanupError) {
        logger.error('Post-order cleanup failed: $cleanupError');
      }

      if (kDebugMode) {
        print('\n⚠️  === ORDER PLACED, UI ERROR AFTERWARDS === ⚠️');
        print('Error: $e');
        print('Order status left as COMPLETED — check My Orders.\n');
      }
      return;
    }

    ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.failed;
    ref.read(orderErrorMessageProvider.notifier).state = orderReachedBackend
        // The backend answered and rejected it; that message is the useful one.
        ? 'Order could not be completed. Please check My Orders before retrying.'
        : 'Unexpected error: $e';

    // Mark order as failed - this will create a new session automatically
    final enhancedCartValidator = ref.read(enhancedCartValidatorProvider);
    final prefs = await SharedPreferences.getInstance();
    final tempOrderId = prefs.getString('temp_order_id');
    if (tempOrderId != null) {
      await enhancedCartValidator.markOrderAsFailed(tempOrderId);
    }

    logger.error('Unexpected error during order placement: $e');
    logger.error('$stack');

    if (kDebugMode) print('\n💥 === UNEXPECTED ERROR === 💥');
    if (kDebugMode) print('Error: $e');
    if (kDebugMode) print('💥 === ORDER FLOW FAILED === 💥\n');

    _showErrorSnackBar('An unexpected error occurred. Please try again.');
  }
}
// Enhanced order success dialog
// Helper method to format date for display

// Enhanced error display method

// Helper method for CartItem conversion (add this if you need it)
  IconData _getPaymentMethodIcon(PaymentMethod method) {
    switch (method.paymentModeName.toLowerCase()) {
      case 'pod':
        return Icons.money;
      case 'online payment':
        return Icons.credit_card;
      default:
        return Icons.payment;
    }
  }

  String _getPaymentMethodSubtitle(PaymentMethod method, bool isSelfPickup) {
    switch (method.paymentModeName.toLowerCase()) {
      case 'pod':
        return isSelfPickup 
            ? 'Pay when you collect your order' 
            : 'Pay when your order is delivered';
      case 'online payment':
        return 'Pay securely with card, UPI or net banking';
      default:
        return 'Secure payment option';
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderProcessStatus = ref.watch(orderProcessStatusProvider);
    final orderError = ref.watch(orderErrorMessageProvider);
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    
    // Show loading spinner with status message
    if (orderProcessStatus == OrderProcessStatus.validatingCart ||
        orderProcessStatus == OrderProcessStatus.processingPayment ||
        orderProcessStatus == OrderProcessStatus.confirmingOrder) {
      String statusMessage;
      switch (orderProcessStatus) {
        case OrderProcessStatus.validatingCart:
          statusMessage = 'Validating your cart...';
          break;
        case OrderProcessStatus.processingPayment:
          statusMessage = 'Processing payment...';
          break;
        case OrderProcessStatus.confirmingOrder:
          statusMessage = 'Placing your order...';
          break;
        default:
          statusMessage = 'Processing...';
      }
      
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text(
              statusMessage,
              style: AppTextStyles.bodyLarge,
            ),
          ],
        ),
      );
    }
    
    // If there's an error, display it
    if (orderProcessStatus == OrderProcessStatus.failed && orderError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              color: Colors.red,
              size: 64,
            ),
            SizedBox(height: 16),
            Text(
              'Order Failed',
              style: AppTextStyles.h5,
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                orderError,
                style: AppTextStyles.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                ref.read(orderProcessStatusProvider.notifier).state = OrderProcessStatus.initial;
                ref.read(orderErrorMessageProvider.notifier).state = null;
              },
              child: Text('Try Again'),
            ),
          ],
        ),
      );
    }

    // Normal payment flow UI
    final bool isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;
    
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Main scrollable content
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Show store pickup info if self-pickup is selected
                  if (isSelfPickup)
                    _buildStorePickupInfo(),
                  
                  // Order Summary Section
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(16.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.grey[200]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.receipt_long,
                                color: AppColors.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ORDER SUMMARY',
                                style: AppTextStyles.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          _buildCompactOrderSummary(),
                        ],
                      ),
                    ),
                  ),

                  // Pickup name field (only for self-pickup)
                  if (isSelfPickup)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: TextField(
                        controller: _pickupNameController,
                        inputFormatters: [NoEmojiInputFormatter()],
                        decoration: InputDecoration(
                          labelText: 'Pickup Name',
                          hintText: 'Enter your name for pickup',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onChanged: (value) {
                          widget.checkoutData.pickupName = value;
                        },
                      ),
                    ),

                  // Special instructions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: TextField(
                      controller: _instructionsController,
                      inputFormatters: [NoEmojiInputFormatter()],
                      decoration: InputDecoration(
                        hintText: isSelfPickup
                            ? 'Any special instructions for pickup?'
                            : 'Any special instructions for delivery?',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: Colors.grey[300]!),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      maxLines: 2,
                    ),
                  ),
                  
                  // Payment methods section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                    child: Row(
                      children: [
                        Icon(
                          Icons.payment,
                          color: AppColors.primary.withOpacity(0.7),
                          size: 24,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'PAYMENT METHOD',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                    child: Text(
                      'Select your preferred payment option',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Payment method options from API
                  _buildPaymentMethodOptions(),
                  
                  // Security info
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.blue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.security,
                            color: Colors.blue,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'All transactions are secure and encrypted',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Colors.blue,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Extra space for scrollability
                  SizedBox(height: 70),
                ],
              ),
            ),
          ),
          
          // Fixed bottom button
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 4,
                ),
              ],
            ),
            padding: EdgeInsets.only(
              left: 16.0,
              right: 16.0,
              top: 12.0,
              bottom: bottomPadding > 0 ? bottomPadding : 16.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Why the order was refused, right where the shopper is
                // looking. Previously this only ever went to a SnackBar, and
                // when the messenger was wedged that meant no feedback at all.
                if (_validationError != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline,
                            size: 18, color: AppColors.error),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _validationError!,
                            style: AppTextStyles.bodySmall
                                .copyWith(color: AppColors.error),
                          ),
                        ),
                      ],
                    ),
                  ),
                SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                // Also blocks when the selected address turned out to be
                // outside the store's delivery radius (or otherwise
                // uncalculated) — see the matching comment in
                // delivery_address_step.dart. Placing an order should not be
                // reachable for an address delivery was never confirmed for.
                onPressed: _isPlacingOrder ||
                        _selectedPaymentMethod == null ||
                        ref.watch(deliveryChargesProvider).error != null
                    ? null
                    : _placeOrder,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: _isPlacingOrder
                    ? const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 2,
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Text('PLACE ORDER'),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
              ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentMethodOptions() {
    return Consumer(
      builder: (context, ref, child) {
        final paymentMethodsAsync = ref.watch(paymentMethodsProvider);
        
        return paymentMethodsAsync.when(
          loading: () => Padding(
            padding: const EdgeInsets.all(32.0),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text(
                    'Loading payment methods...',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          error: (error, stackTrace) {
            ref.read(loggerProvider).error('Error loading payment methods: $error');
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: AppColors.errorLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withOpacity(0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.error,
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Failed to load payment methods',
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.error,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please check your connection and try again',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () {
                        ref.invalidate(paymentMethodsProvider);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          },
          data: (paymentMethods) {
            if (paymentMethods.isEmpty) {
              return Padding(
                padding: const EdgeInsets.all(16.0),
                child: Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.payment_outlined,
                        color: Colors.orange,
                        size: 48,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No payment methods available',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange[800],
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Please contact support for assistance',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              );
            }

            // Auto-select first payment method if none selected
            if (_selectedPaymentMethod == null && paymentMethods.isNotEmpty) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final firstMethod = paymentMethods.first;
                setState(() {
                  _selectedPaymentMethod = firstMethod;
                });
                ref.read(selectedPaymentMethodProvider.notifier).state = firstMethod;
                widget.checkoutData.paymentMethod = firstMethod.paymentModeName;
              });
            }

            return Column(
              children: [
                ...paymentMethods.asMap().entries.map((entry) {
                  final index = entry.key;
                  final method = entry.value;
                  
                  return Column(
                    children: [
                      _buildPaymentMethodOption(method),
                      if (index < paymentMethods.length - 1)
                        const Divider(height: 1),
                    ],
                  );
                }),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildPaymentMethodOption(PaymentMethod method) {
    final isSelected = _selectedPaymentMethod?.idPaymentMode == method.idPaymentMode;
    final bool isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;
    
    return InkWell(
      onTap: () => _selectPaymentMethod(method),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: 16.0,
          vertical: 12.0,
        ),
        child: Row(
          children: [
            // Icon
            CircleAvatar(
              backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
              radius: 20,
              child: Icon(
                _getPaymentMethodIcon(method),
                color: isSelected ? Colors.white : Colors.grey[700],
                size: 18,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Text
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    method.displayName,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _getPaymentMethodSubtitle(method, isSelfPickup),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Radio button
            Radio<int>(
              value: method.idPaymentMode,
              groupValue: _selectedPaymentMethod?.idPaymentMode,
              activeColor: AppColors.primary,
              onChanged: (newValue) {
                if (newValue != null) {
                  _selectPaymentMethod(method);
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompactOrderSummary() {
    return Consumer(
      builder: (context, ref, _) {
        final cartItems = ref.watch(cartItemsProvider);
        final cartTotal = ref.watch(cartTotalProvider);
        final cartSavings = ref.watch(cartSavingsProvider);
        
        // Get delivery charges
        final deliveryChargesState = ref.watch(deliveryChargesProvider);
        final deliveryCharge = deliveryChargesState.deliveryCharge;
        final isFreeDelivery = deliveryChargesState.freeDeliveryEligible;
        final distance = deliveryChargesState.distance;
        // See the matching comment in delivery_time_step.dart: handling/
        // packaging are store-configured flat fees that free delivery does
        // NOT waive.
        final distanceCharge = deliveryChargesState.distanceCharge;
        final handlingFee = deliveryChargesState.handlingFee;
        final packageFee = deliveryChargesState.packageFee;
        final packingFee = deliveryChargesState.packingFee;
        final isSelfPickup = widget.checkoutData.deliveryMethod == DeliveryMethod.selfPickup;

        // Cart-discount offer, if applied — see CartOfferRow. Display-only,
        // same as the loyalty voucher below; the server re-validates and
        // recomputes this at place-order time.
        final selectedCartOffer = ref.watch(selectedCartOfferProvider);
        final cartOfferDiscount =
            (selectedCartOffer != null && selectedCartOffer.unlocked) ? selectedCartOffer.effectiveDiscount : 0.0;
        final subtotalAfterOffer = cartTotal - cartOfferDiscount;

        // Loyalty reward voucher, if the customer applied one — see
        // LoyaltyRewardRow. Computed against what's left after the cart
        // offer (matches the backend's stacking order — see the matching
        // comment in _placeOrder). Display-only: the server independently
        // computes and validates this at place-order time.
        final selectedRedemption = ref.watch(selectedLoyaltyRedemptionProvider);
        final loyaltyDiscount = selectedRedemption?.estimateDiscount(
              orderSubtotal: subtotalAfterOffer,
              deliveryCharges: deliveryCharge,
            ) ??
            0;

        // Calculate final amount — self-pickup carries only the packing fee.
        final extraCharge = isSelfPickup ? packingFee : deliveryCharge;
        final finalAmount = subtotalAfterOffer + extraCharge - loyaltyDiscount;

        return Column(
          children: [
            // Quick summary with item count
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${cartItems.length} items',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                Text(
                  '₹${cartTotal.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
            
            // Distance information
            if (!isSelfPickup && distance > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.directions_car,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Distance',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${distance.toStringAsFixed(1)} km',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 8),

            // Delivery charges — not charged for self-pickup.
            if (!isSelfPickup) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.local_shipping,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Delivery Fee',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      if (deliveryChargesState.isLoading)
                        Padding(
                          padding: const EdgeInsets.only(left: 4.0),
                          child: SizedBox(
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                  Text(
                    deliveryChargesState.isLoading
                        ? 'Calculating...'
                        : (isFreeDelivery && distanceCharge <= 0)
                          ? 'FREE'
                          : '₹${distanceCharge.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: (isFreeDelivery && distanceCharge <= 0) ? Colors.green : null,
                      fontWeight: (isFreeDelivery && distanceCharge <= 0) ? FontWeight.bold : null,
                    ),
                  ),
                ],
              ),
            ],

            // Handling fee — store-configured flat charge (admin panel),
            // shown only when the store actually has one set. Not charged
            // for self-pickup.
            if (!isSelfPickup && !deliveryChargesState.isLoading && handlingFee > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.build_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Handling Fee',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${handlingFee.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ],

            // Packaging fee — same idea, shown only when set. Not charged
            // for self-pickup (see Packing Fee below).
            if (!isSelfPickup && !deliveryChargesState.isLoading && packageFee > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Packaging Fee',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${packageFee.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ],

            // Packing fee — self-pickup only, admin-controlled (Outlet >
            // Delivery Fees > "Charge packing fee on self-pickup orders").
            if (isSelfPickup && !deliveryChargesState.isLoading && packingFee > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2_outlined,
                        size: 14,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Packing Fee',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${packingFee.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ],

            // Savings if any
            if (cartSavings > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.savings,
                        size: 14,
                        color: Colors.green,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Savings',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '₹${cartSavings.toStringAsFixed(2)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.green,
                    ),
                  ),
                ],
              ),
            ],

            const CartOfferRow(),

            LoyaltyRewardRow(orderSubtotal: subtotalAfterOffer, deliveryCharges: deliveryCharge),

            const Divider(height: 16),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'TOTAL',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '₹${finalAmount.toStringAsFixed(2)}',
                  style: AppTextStyles.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
            
            // Free delivery notification
            if (!isSelfPickup && isFreeDelivery && distance > 0) ...[
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.check_circle,
                    size: 14,
                    color: Colors.green,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Free delivery eligible',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  // Build store pickup info from selected outlet data
  Widget _buildStorePickupInfo() {
    return Consumer(
      builder: (context, ref, _) {
        final selectedOutletAsync = ref.watch(selectedOutletProvider);
        
        return selectedOutletAsync.when(
          data: (outlet) {
            if (outlet == null) {
              return const SizedBox.shrink();
            }
            
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue[200]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.store, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Self Pickup Details',
                            style: AppTextStyles.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      outlet.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      outlet.address,
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact: +91 1234567890',
                      style: const TextStyle(color: Colors.black87),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Working Hours: ${outlet.openTime}',
                      style: TextStyle(color: Colors.blue[700]),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Delivery Time: ${outlet.deliveryTime}',
                      style: TextStyle(color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16.0),
            child: Center(
              child: CircularProgressIndicator(),
            ),
          ),
          error: (error, _) => Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: AppColors.errorLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.error_outline, color: AppColors.error),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Store Information Unavailable',
                          style: AppTextStyles.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.error,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please go back and select a store for pickup.',
                    style: AppTextStyles.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
  // Widget _buildPaymentMethodOption({
  //   required String title,
  //   required String subtitle,
  //   required IconData icon,
  //   required String value,
  // }) {
  //   final isSelected = _selectedPaymentMethod == value;
    
  //   return InkWell(
  //     onTap: () => _selectPaymentMethod(value),
  //     child: Padding(
  //       padding: const EdgeInsets.symmetric(
  //         horizontal: 16.0,
  //         vertical: 12.0,
  //       ),
  //       child: Row(
  //         children: [
  //           // Icon
  //           CircleAvatar(
  //             backgroundColor: isSelected ? AppColors.primary : Colors.grey[200],
  //             radius: 20,
  //             child: Icon(
  //               icon,
  //               color: isSelected ? Colors.white : Colors.grey[700],
  //               size: 18,
  //             ),
  //           ),
            
  //           const SizedBox(width: 16),
            
  //           // Text
  //           Expanded(
  //             child: Column(
  //               crossAxisAlignment: CrossAxisAlignment.start,
  //               children: [
  //                 Text(
  //                   title,
  //                   style: AppTextStyles.bodyLarge.copyWith(
  //                     fontWeight: FontWeight.w500,
  //                   ),
  //                 ),
  //                 Text(
  //                   subtitle,
  //                   style: AppTextStyles.bodySmall.copyWith(
  //                     color: AppColors.textSecondary,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
            
  //           // Radio button
  //           Radio<String>(
  //             value: value,
  //             groupValue: _selectedPaymentMethod,
  //             activeColor: AppColors.primary,
  //             onChanged: (newValue) {
  //               if (newValue != null) {
  //                 _selectPaymentMethod(newValue);
  //               }
  //             },
  //           ),
  //         ],
  //       ),
  //     ),
  //   );
  // }

