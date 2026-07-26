// lib/presentation/features/onboarding/onboarding_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../presentation/widgets/back_button_wrapper.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/launch_flow_provider.dart';

// Provider to track the current onboarding page
final onboardingPageProvider = StateProvider<int>((ref) => 0);

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentPage = ref.watch(onboardingPageProvider);
    final pageController = PageController(initialPage: currentPage);
    
    // Onboarding content data
    final onboardingData = [
      OnboardingPageData(
        title: 'Shop with Ease ',
        description: 'Browse and add your favorite products to the cart effortlessly. Your next purchase is just a few taps away!',
        imagePath: 'assets/images/cart.webp',
      ),
      OnboardingPageData(
        title: 'Fast & Reliable Delivery',
        description: 'Get your orders delivered quickly and safely right to your doorstep.',
        imagePath: 'assets/images/delivery.webp',
      ),
      OnboardingPageData(
        title: 'Reorder with Just One Tap',
        description: 'Loved your last purchase? Quickly reorder your favorite items anytime without the hassle of searching again.',
        imagePath: 'assets/images/reorder.webp',
      ),
    ];

    // Handler for page changes
    void onPageChanged(int page) {
      ref.read(onboardingPageProvider.notifier).state = page;
    }

    // Function to complete onboarding and navigate to home
    void completeOnboarding() async {
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(
          child: CircularProgressIndicator(),
        ),
      );

      try {
        // Mark onboarding as completed
        await ref.read(onboardingProvider.notifier).completeOnboarding();
        
        // Update the launch flow state - critical for proper flow continuation
        ref.read(launchFlowProvider.notifier).onboardingCompleted();
        
        // Try to fetch location and check pincode
        await ref.read(launchFlowProvider.notifier).fetchLocationAndCheckPincode();
        
        // Navigation will be handled by the router based on the updated launch state
        if (context.mounted) {
          Navigator.pop(context); // Dismiss loading indicator
          context.go('/home'); // The router will redirect as needed
        }
      } catch (e) {
        if (context.mounted) {
          Navigator.pop(context); // Dismiss loading indicator
          // Go to pincode selection as fallback
          context.go('/pincode-selection');
        }
      }
    }

    // Function to go to next page
    void goToNextPage() {
      final nextPage = currentPage + 1;
      if (nextPage < onboardingData.length) {
        pageController.animateToPage(
          nextPage,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        completeOnboarding();
      }
    }

    // Function to skip onboarding
    void skipOnboarding() {
      completeOnboarding();
    }

    // Use BackButtonWrapper with custom handling for onboarding
    // For onboarding screen, pressing back on first page shows exit confirmation
    // On other pages, it goes back to previous onboarding page
    return BackButtonWrapper(
      customExitMessage: 'Press back again to exit app',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              // Skip button
              Align(
                alignment: Alignment.topRight,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: TextButton(
                    onPressed: skipOnboarding,
                    child: Text(
                      'Skip',
                      style: AppTextStyles.buttonMedium.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ),
              
              // Page content (illustrations and text)
              Expanded(
                child: PageView.builder(
                  controller: pageController,
                  onPageChanged: onPageChanged,
                  itemCount: onboardingData.length,
                  itemBuilder: (context, index) {
                    return OnboardingPage(
                      data: onboardingData[index],
                      responsivePadding: ResponsiveUtils.getResponsivePadding(context),
                    );
                  },
                ),
              ),
              
              // Bottom navigation (indicators and next/start button)
              Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: ResponsiveUtils.isSmall(context) ? 16.0 : 24.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Page indicators
                    Row(
                      children: List.generate(
                        onboardingData.length,
                        (index) => PageIndicator(
                          isActive: currentPage == index,
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.primaryLighter,
                        ),
                      ),
                    ),
                    
                    // Next/Get Started button
                    ElevatedButton(
                      onPressed: goToNextPage,
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text(
                        currentPage == onboardingData.length - 1
                            ? 'Get Started'
                            : 'Next',
                        style: AppTextStyles.buttonMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// Data class to hold onboarding page content
class OnboardingPageData {
  final String title;
  final String description;
  final String imagePath;

  OnboardingPageData({
    required this.title,
    required this.description,
    required this.imagePath,
  });
}

// Individual onboarding page
class OnboardingPage extends StatelessWidget {
  final OnboardingPageData data;
  final EdgeInsets responsivePadding;

  const OnboardingPage({
    super.key,
    required this.data,
    required this.responsivePadding,
  });

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    // INCREASED IMAGE SIZE - Changed from 0.7/0.6/0.5 to 0.85/0.75/0.65
    final imageSize = ResponsiveUtils.getResponsiveValue(
      context: context,
      small: screenSize.width * 0.85,   // Increased from 0.7
      medium: screenSize.width * 0.75,  // Increased from 0.6
      large: screenSize.width * 0.65,   // Increased from 0.5
    );

    return Padding(
      padding: responsivePadding,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Image with animation - REMOVED BORDER AND INCREASED SIZE
          AnimatedImageContainer(
            size: imageSize,
            imagePath: data.imagePath,
          ),
          const SizedBox(height: 48),
          
          // Title
          Text(
            data.title,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          // Description
          Text(
            data.description,
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// Animated container for WebP images - REMOVED BORDER AND BACKGROUND COLOR
class AnimatedImageContainer extends StatefulWidget {
  final double size;
  final String imagePath;

  const AnimatedImageContainer({
    super.key,
    required this.size,
    required this.imagePath,
  });

  @override
  State<AnimatedImageContainer> createState() => _AnimatedImageContainerState();
}

class _AnimatedImageContainerState extends State<AnimatedImageContainer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeInOut,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          // REMOVED: Container with border and background color
          // CHANGED: Direct image without container wrapper
          child: SizedBox(
            width: widget.size,
            height: widget.size,
            child: Image.asset(
              widget.imagePath,
              fit: BoxFit.contain,
            ),
          ),
        );
      },
    );
  }
}

// Custom page indicator
class PageIndicator extends StatelessWidget {
  final bool isActive;
  final Color activeColor;
  final Color inactiveColor;

  const PageIndicator({
    super.key,
    required this.isActive,
    required this.activeColor,
    required this.inactiveColor,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      height: 8,
      width: isActive ? 24 : 8,
      decoration: BoxDecoration(
        color: isActive ? activeColor : inactiveColor,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}