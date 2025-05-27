// lib/presentation/features/auth/otp_validation_screen.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../providers/auth_providers.dart';

class OtpValidationScreen extends ConsumerStatefulWidget {
  final String mobileNumber;
  final String? redirectRoute;

  const OtpValidationScreen({
    Key? key,
    required this.mobileNumber,
    this.redirectRoute,
  }) : super(key: key);

  @override
  ConsumerState<OtpValidationScreen> createState() => _OtpValidationScreenState();
}

class _OtpValidationScreenState extends ConsumerState<OtpValidationScreen> {
  final TextEditingController _otpController = TextEditingController();
  final StreamController<ErrorAnimationType> _errorController = StreamController<ErrorAnimationType>();
  Timer? _resendTimer;
  int _resendCountdown = 30;
  bool _isLoading = false;
  bool _isResending = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    // Start listening for SMS
    _listenForSms();
  }

  @override
  void dispose() {
    _otpController.dispose();
    _errorController.close();
    _resendTimer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _resendCountdown = 30;
    });
    
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendCountdown > 0) {
          _resendCountdown--;
        } else {
          timer.cancel();
        }
      });
    });
  }

  // Mock implementation - in a real app, this would use platform-specific code
  void _listenForSms() {
    // This is a placeholder for SMS auto-retrieval
    // For actual implementation on Android, you'd use SmsRetrieverApi
    // For iOS, you'd use iOS text field suggestions
  }

  Future<void> _resendOtp() async {
    if (_resendCountdown > 0) return;
    
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final repository = ref.read(authRepositoryProvider);
      await repository.requestOtp(widget.mobileNumber);
      
      // Start the countdown timer again
      _startResendTimer();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to resend OTP. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  Future<void> _validateOtp() async {
    final otp = _otpController.text.trim();
    
    // Validate OTP format
    if (otp.isEmpty || otp.length < 4) {
      _errorController.add(ErrorAnimationType.shake);
      setState(() {
        _errorMessage = 'Please enter a valid OTP';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Validate OTP
      final repository = ref.read(authRepositoryProvider);
      final validationResponse = await repository.validateOtp(widget.mobileNumber, otp);
      
      if (validationResponse.isSuccessful()) {
        // Update login state to success
        ref.read(loginStateProvider.notifier).state = LoginState.success;
        
        // Log success information
        ref.read(loggerProvider).log('OTP validation successful: ${validationResponse.message}');
        
        // Navigate to redirect route or home screen
        final route = widget.redirectRoute ?? '/home';
        
        // Use pushReplacement to clear the auth flow stack and go to destination
        if (mounted) {
          // Clear the navigation stack and go to the intended route
          context.go(route);
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome! You are now logged in.'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 2),
            ),
          );
          
          // Log the successful redirect
          ref.read(loggerProvider).log('Successfully redirected to: $route');
        }
      } else {
        setState(() {
          _errorMessage = 'Invalid OTP or authentication failed. Please try again.';
        });
        _errorController.add(ErrorAnimationType.shake);
        
        // Log failure information
        ref.read(loggerProvider).log('OTP validation failed: ${validationResponse.message}');
      }
    } catch (e) {
      ref.read(loggerProvider).error('Error during OTP validation: $e');
      
      setState(() {
        _errorMessage = 'Failed to validate OTP: ${e.toString()}';
      });
      _errorController.add(ErrorAnimationType.shake);
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = ResponsiveUtils.isSmall(context);
    final formattedMobile = '+91 ${widget.mobileNumber}';
    
    return BackButtonWrapper(
      alternateRoute: '/auth/login?redirectRoute=${widget.redirectRoute ?? ''}',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('OTP Verification'),
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              // Go back to login screen with the same redirect route
              if (widget.redirectRoute != null) {
                context.go('/auth/login?redirectRoute=${widget.redirectRoute}');
              } else {
                context.pop();
              }
            },
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
                  Image.asset(
                    'assets/images/patelLogo.png',
                    height: isSmallScreen ? 100 : 120,
                    fit: BoxFit.contain,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // OTP Verification Text
                  Text(
                    'OTP Verification',
                    style: AppTextStyles.h4.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Enter the OTP sent to',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 4),
                  
                  Text(
                    formattedMobile,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  // Show redirect context if coming from a specific screen
                  if (widget.redirectRoute != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'After verification, you\'ll be taken to ${_getScreenNameFromRoute(widget.redirectRoute!)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  
                  const SizedBox(height: 40),
                  
                  // OTP Input
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: PinCodeTextField(
                      appContext: context,
                      length: 4,
                      obscureText: false,
                      controller: _otpController,
                      animationType: AnimationType.fade,
                      errorAnimationController: _errorController,
                      keyboardType: TextInputType.number,
                      pinTheme: PinTheme(
                        shape: PinCodeFieldShape.box,
                        borderRadius: BorderRadius.circular(8),
                        fieldHeight: 56,
                        fieldWidth: 56,
                        activeFillColor: Colors.white,
                        selectedFillColor: Colors.white,
                        inactiveFillColor: Colors.white,
                        activeColor: AppColors.primary,
                        selectedColor: AppColors.primary,
                        inactiveColor: AppColors.neutral400,
                        borderWidth: 1.5,
                      ),
                      animationDuration: const Duration(milliseconds: 300),
                      enableActiveFill: true,
                      onCompleted: (_) {
                        _validateOtp();
                      },
                      onChanged: (value) {
                        // Update the provider value
                        ref.read(otpProvider.notifier).state = value;
                        
                        // Clear error when typing
                        if (_errorMessage != null) {
                          setState(() {
                            _errorMessage = null;
                          });
                        }
                      },
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                    ),
                  ),
                  
                  // Error Message
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  
                  const SizedBox(height: 24),
                  
                  // Resend OTP Link
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Didn\'t receive the OTP? ',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      _resendCountdown > 0
                          ? Text(
                              'Resend in $_resendCountdown s',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.neutral600,
                              ),
                            )
                          : _isResending
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : GestureDetector(
                                  onTap: _resendOtp,
                                  child: Text(
                                    'Resend OTP',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Verify Button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _validateOtp,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        disabledBackgroundColor: AppColors.primaryLight.withOpacity(0.7),
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
                              'Verify OTP',
                              style: AppTextStyles.buttonLarge.copyWith(
                                color: Colors.white,
                              ),
                            ),
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
      default:
        return 'the previous screen';
    }
  }
}