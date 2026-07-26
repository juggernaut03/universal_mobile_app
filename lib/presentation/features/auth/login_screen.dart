// lib/presentation/features/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../providers/auth_providers.dart';
// FACEBOOK PIXEL IMPORTS
import '../../../facebook_pixel/facebook_pixel_integration.dart';
import 'package:patelmart/core/widgets/brand_logo.dart';
import '../../../core/result/result.dart';
import '../../../di/auth_providers.dart';
import '../../../domain/usecases/auth/request_otp.dart';
import '../../../di/infrastructure_providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirectRoute;

  const LoginScreen({
    super.key,
    this.redirectRoute,
  });

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _mobileController = TextEditingController();
  final FocusNode _mobileFocusNode = FocusNode();
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    
    // Add listener to update the provider value
    _mobileController.addListener(_updateMobileNumber);
  }

  @override
  void dispose() {
    _mobileController.removeListener(_updateMobileNumber);
    _mobileController.dispose();
    _mobileFocusNode.dispose();
    super.dispose();
  }

  void _updateMobileNumber() {
    ref.read(mobileNumberProvider.notifier).state = _mobileController.text;
  }

  // Single navigation handler
  void _handleBackNavigation() {
    final logger = ref.read(loggerProvider);
    logger.log('Back navigation from LoginScreen');
    
    try {
      // Always go to home - don't go to redirect route on back navigation
      // Users should only go to redirect route after successful login
      context.go('/home');
    } catch (e) {
      logger.error('Error handling back navigation: $e');
      // Fallback - try to pop or go to home
      if (context.canPop()) {
        context.pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    }
  }

  Future<void> _requestOtp() async {
    setState(() {
      _errorMessage = null;
      _isLoading = true;
    });

    // The 10-digit rule used to be duplicated here and in otpRequestProvider.
    // It now lives in the RequestOtp use case and comes back as a
    // ValidationFailure, so there is one definition of "valid mobile number".
    final mobileNumber = _mobileController.text.trim();
    final result = await ref.read(requestOtpUseCaseProvider)(
      RequestOtpParams(mobile: mobileNumber),
    );

    if (!mounted) return;

    switch (result) {
      case Ok():
        ref.read(loggerProvider).log('OTP requested for $mobileNumber');

        await FacebookPixelIntegration.trackUserAuth(
          ref,
          eventType: 'login',
          userId: mobileNumber,
          method: 'phone',
        );

        if (!mounted) return;
        ref.read(loginStateProvider.notifier).state = LoginState.otpRequested;
        setState(() => _isLoading = false);

        context.pushReplacement(
          '/auth/otp',
          extra: {
            'mobile': mobileNumber,
            'redirectRoute': widget.redirectRoute,
          },
        );

      case Err(:final failure):
        ref.read(loggerProvider).error('OTP request failed: ${failure.message}');
        setState(() {
          // Was 'Failed to request OTP: ${e.toString()}' — a raw exception
          // shown to the user.
          _errorMessage = failure.userMessage;
          _isLoading = false;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = ResponsiveUtils.isSmall(context);
    
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvoked: (bool didPop) async {
        if (!didPop) {
          _handleBackNavigation();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Login'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackNavigation,
          ),
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 24 : screenWidth * 0.1,
                vertical: 24,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Logo
                  BrandLogo(height: isSmallScreen ? 120 : 150),
                  
                  const SizedBox(height: 40),
                  
                  // Welcome Text
                  Text(
  "Welcome to Patel's R Mart",
  style: AppTextStyles.h4.copyWith(
    color: AppColors.primary,
    fontWeight: FontWeight.bold,
  ),
  textAlign: TextAlign.center,
),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Enter your mobile number to continue',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Show redirect context if coming from a specific screen
                  if (widget.redirectRoute != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryLight.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                      ),
                      child: Text(
                        'Login to access ${_getScreenNameFromRoute(widget.redirectRoute!)}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                  
                  // Mobile Number Input
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mobile Number',
                        style: AppTextStyles.labelMedium.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      
                      const SizedBox(height: 8),
                      
                      TextFormField(
                        controller: _mobileController,
                        focusNode: _mobileFocusNode,
                        keyboardType: TextInputType.phone,
                        maxLength: 10,
                        style: AppTextStyles.bodyLarge,
                        decoration: InputDecoration(
                          hintText: 'Enter 10-digit mobile number',
                          prefixIcon: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12, 
                              vertical: 10
                            ),
                            margin: const EdgeInsets.only(right: 8),
                            child: Text(
                              '+91',
                              style: AppTextStyles.bodyLarge.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                          prefixIconConstraints: const BoxConstraints(
                            minWidth: 0,
                            minHeight: 0,
                          ),
                          errorText: _errorMessage,
                          counterText: '',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.primary, width: 2),
                          ),
                          errorBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(color: AppColors.error, width: 1),
                          ),
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onFieldSubmitted: (_) => _requestOtp(),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Continue Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _requestOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: AppColors.primaryLight.withOpacity(0.7),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              'Request OTP',
                              style: AppTextStyles.buttonLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Terms & Conditions
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      'By continuing, you agree to our Terms of Service and Privacy Policy',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Helper method to get user-friendly screen names
  String _getScreenNameFromRoute(String route) {
    switch (route) {
      case '/cart':
        return 'your cart';
      case '/favorites':
        return 'your favorites';
      case '/account':
        return 'your account';
      case '/my-orders':
        return 'your orders';
      case '/profile':
        return 'your profile';
      case '/address-book':
        return 'address book';
      case '/checkout-flow':
        return 'checkout';
      case '/savings':
        return 'savings';
      case '/reorder':
        return 'reorder';
      default:
        return 'this feature';
    }
  }
}