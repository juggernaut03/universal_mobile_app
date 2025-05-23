// lib/presentation/features/auth/login_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:patelmart/presentation/providers/launch_flow_provider.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../core/widgets/back_button_wrapper.dart';
import '../../providers/auth_providers.dart';
import 'otp_validation_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  final String? redirectRoute;

  const LoginScreen({
    Key? key,
    this.redirectRoute,
  }) : super(key: key);

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

  // lib/presentation/features/auth/login_screen.dart (update the _requestOtp method)

Future<void> _requestOtp() async {
  // Clear any previous errors
  setState(() {
    _errorMessage = null;
  });

  // Validate mobile number format
  final mobileNumber = _mobileController.text.trim();
  if (mobileNumber.isEmpty || mobileNumber.length != 10) {
    setState(() {
      _errorMessage = 'Please enter a valid 10-digit mobile number';
    });
    return;
  }

  // Show loading indicator
  setState(() {
    _isLoading = true;
  });

  try {
    // Request OTP
    final repository = ref.read(authRepositoryProvider);
    final otpResponse = await repository.requestOtp(mobileNumber);
    
    // Log success details
    ref.read(loggerProvider).log('OTP requested successfully. Status: ${otpResponse.status}, Mobile: ${otpResponse.mobile}');
    
    // Update the login state
    ref.read(loginStateProvider.notifier).state = LoginState.otpRequested;
    
    // Navigate to OTP validation screen
    if (mounted) {
      // Navigate to OTP screen
      context.push(
        '/auth/otp',
        extra: {
          'mobile': mobileNumber,
          'redirectRoute': widget.redirectRoute,
        },
      );
    }
  } catch (e) {
    // Be more specific about the error
    ref.read(loggerProvider).error('OTP request failed with error: $e');
    
    // Show error message
    setState(() {
      _errorMessage = 'Failed to request OTP: ${e.toString()}';
    });
  } finally {
    // Hide loading indicator
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
    
    return BackButtonWrapper(
      customExitMessage: widget.redirectRoute != null 
          ? null 
          : 'Press back again to exit',
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Login'),
          centerTitle: true,
          leading: widget.redirectRoute != null 
              ? IconButton(
                  icon: const Icon(Icons.arrow_back),
                 onPressed: () {
              context.push('/home');
            },
                )
              : null,
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
                    height: isSmallScreen ? 120 : 150,
                    fit: BoxFit.contain,
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Welcome Text
                  Text(
                    'Welcome to PatelMart',
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
                  Text(
                    'By continuing, you agree to our Terms of Service and Privacy Policy',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}