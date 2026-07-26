// lib/presentation/features/splash/splash_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/presentation/widgets/back_button_wrapper.dart';
import '../../../core/constants/app_colors.dart';
import '../../providers/splash_provider.dart';
import 'package:patelmart/core/widgets/brand_logo.dart';
import '../../../di/infrastructure_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final String logoAsset;
  
  const SplashScreen({
    Key? key,
    required this.logoAsset,
  }) : super(key: key);

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;
  late Animation<double> _scaleAnimation;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    
    // Setup animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );
    
    // Start animation
    _controller.forward();
    
    // Start initialization
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    if (_isInitialized) return;
    
    final logger = ref.read(loggerProvider);
    logger.log('Starting app initialization from splash screen');
    
    try {
      // Trigger initialization process
      await ref.read(splashInitializationProvider.future);
      
      if (mounted) {
        // Set splash as completed to prevent returning to it
        ref.read(splashCompletedProvider.notifier).state = true;
        _isInitialized = true;
        
        logger.log('Splash initialization completed successfully');
        
        // The router will handle proper redirection based on app state
      }
    } catch (e) {
      logger.error('Error during app initialization: $e');
      
      // Even on error, mark splash as completed to move forward
      if (mounted) {
        ref.read(splashCompletedProvider.notifier).state = true;
        _isInitialized = true;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use BackButtonWrapper with custom exit confirmation for splash screen
    // Since splash screen is the first screen, this will handle the back button
    // with the "press back again to exit" behavior
    return BackButtonWrapper(
      customExitMessage: 'Press back again to exit app',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo with animation
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: Transform.scale(
                      scale: _scaleAnimation.value,
                      child: child,
                    ),
                  );
                },
                child: const BrandLogo(height: 300, splash: true),
              ),
              
              const SizedBox(height: 24),
              
              // App name
              AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  return Opacity(
                    opacity: _opacityAnimation.value,
                    child: child,
                  );
                },
              
              ),
              
              const SizedBox(height: 48),
              
              // Loading indicator
              const CircularProgressIndicator(),
            ],
          ),
        ),
      ),
    );
  }
}