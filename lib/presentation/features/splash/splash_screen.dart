// lib/presentation/features/splash/splash_screen.dart
//
// Every visual on this screen — logo, size, background, tagline, animation,
// how long it is held and whether a spinner shows — comes from the tenant's
// project-config, edited in the admin panel under Mobile App > App Settings.
// main() applies the cached config before runApp, so the splash is already
// tenant-branded on the very first frame; a config change lands on the next
// launch. Anything unset falls back to the app's built-in default.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/presentation/widgets/back_button_wrapper.dart';
import '../../../core/branding/app_branding.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../providers/splash_provider.dart';
import 'package:patelmart/core/widgets/brand_logo.dart';
import '../../../di/infrastructure_providers.dart';

class SplashScreen extends ConsumerStatefulWidget {
  final String logoAsset;

  const SplashScreen({
    super.key,
    required this.logoAsset,
  });

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

    final branding = AppBranding.instance;
    final animation = branding.splashAnimation;

    // Setup animations
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    final fades = animation == SplashAnimation.fade ||
        animation == SplashAnimation.fadeScale;
    final scales = animation == SplashAnimation.scale ||
        animation == SplashAnimation.fadeScale;

    _opacityAnimation = Tween<double>(begin: fades ? 0.0 : 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: scales ? 0.8 : 1.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    // Start animation
    if (animation == SplashAnimation.none) {
      _controller.value = 1.0;
    } else {
      _controller.forward();
    }

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
    final branding = AppBranding.instance;

    // Use BackButtonWrapper with custom exit confirmation for splash screen
    // Since splash screen is the first screen, this will handle the back button
    // with the "press back again to exit" behavior
    return BackButtonWrapper(
      customExitMessage: 'Press back again to exit app',
      child: Scaffold(
        backgroundColor: branding.splashBackgroundColor ?? AppColors.background,
        body: DecoratedBox(
          decoration: BoxDecoration(
            image: branding.splashBackgroundImageUrl.isEmpty
                ? null
                : DecorationImage(
                    image: NetworkImage(branding.splashBackgroundImageUrl),
                    fit: BoxFit.cover,
                    // A background image that fails to load must not blank the
                    // splash — the background colour stays visible.
                    onError: (_, __) {},
                  ),
          ),
          child: Center(
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
                  child: BrandLogo(height: branding.splashLogoSize, splash: true),
                ),

                if (branding.splashTagline.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  AnimatedBuilder(
                    animation: _controller,
                    builder: (context, child) => Opacity(
                      opacity: _opacityAnimation.value,
                      child: child,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        branding.splashTagline,
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: branding.splashTaglineColor ??
                              AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],

                if (branding.splashShowLoader) ...[
                  const SizedBox(height: 48),
                  const CircularProgressIndicator(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
