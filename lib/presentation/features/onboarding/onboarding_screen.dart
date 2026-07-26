// lib/presentation/features/onboarding/onboarding_screen.dart
//
// Slides come from the backend (POST /api/onboarding/list), managed in the
// admin panel under Mobile App > Screens > Onboarding. The repository falls
// back to its cache and then to a bundled set, so this screen always has
// something to render — it never shows an error state.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/utils/responsive_utils.dart';
import '../../../data/models/onboarding_slide_model.dart';
import '../../../presentation/widgets/back_button_wrapper.dart';
import '../../providers/onboarding_provider.dart';
import '../../providers/launch_flow_provider.dart';
import '../../providers/app_shell_providers.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  // Held for the lifetime of the screen. It used to be constructed inside
  // build(), which produced a fresh controller on every rebuild — so
  // animateToPage ran against a discarded one and the page never moved.
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: ref.read(onboardingPageProvider));
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
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
      if (mounted) {
        Navigator.pop(context); // Dismiss loading indicator
        context.go('/home'); // The router will redirect as needed
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context); // Dismiss loading indicator
        // Go to pincode selection as fallback
        context.go('/pincode-selection');
      }
    }
  }

  void _goToNextPage(int currentPage, int slideCount) {
    final nextPage = currentPage + 1;
    if (nextPage < slideCount) {
      _pageController.animateToPage(
        nextPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentPage = ref.watch(onboardingPageProvider);
    final slidesAsync = ref.watch(onboardingSlidesProvider);

    // Use BackButtonWrapper with custom handling for onboarding
    // For onboarding screen, pressing back on first page shows exit confirmation
    // On other pages, it goes back to previous onboarding page
    return BackButtonWrapper(
      customExitMessage: 'Press back again to exit app',
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: slidesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            // The repository already falls back to bundled slides, so an error
            // here means something unexpected — move the user along rather
            // than trapping them on a dead screen.
            error: (_, __) => _buildContent(
              context,
              OnboardingSlideModel.bundledDefaults,
              currentPage,
            ),
            data: (slides) => _buildContent(context, slides, currentPage),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<OnboardingSlideModel> slides,
    int currentPage,
  ) {
    if (slides.isEmpty) {
      // A tenant may deactivate every slide; skipping straight through is the
      // sensible reading of "no onboarding configured".
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _completeOnboarding();
      });
      return const Center(child: CircularProgressIndicator());
    }

    // Clamp: the slide list can shrink between launches while a stale page
    // index is still in state.
    final safePage = currentPage.clamp(0, slides.length - 1);

    return Column(
      children: [
        // Skip button
        Align(
          alignment: Alignment.topRight,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextButton(
              onPressed: _completeOnboarding,
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
            controller: _pageController,
            onPageChanged: (page) =>
                ref.read(onboardingPageProvider.notifier).state = page,
            itemCount: slides.length,
            itemBuilder: (context, index) {
              return OnboardingPage(
                slide: slides[index],
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
                  slides.length,
                  (index) => PageIndicator(
                    isActive: safePage == index,
                    activeColor: AppColors.primary,
                    inactiveColor: AppColors.primaryLighter,
                  ),
                ),
              ),

              // Next/Get Started button
              ElevatedButton(
                onPressed: () => _goToNextPage(safePage, slides.length),
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
                  safePage == slides.length - 1 ? 'Get Started' : 'Next',
                  style: AppTextStyles.buttonMedium,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// Individual onboarding page
class OnboardingPage extends StatelessWidget {
  final OnboardingSlideModel slide;
  final EdgeInsets responsivePadding;

  const OnboardingPage({
    super.key,
    required this.slide,
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
            slide: slide,
          ),
          const SizedBox(height: 48),

          // Title
          Text(
            slide.title,
            style: AppTextStyles.h3.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),

          // Description
          Text(
            slide.description,
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

// Animated container for slide images - REMOVED BORDER AND BACKGROUND COLOR
class AnimatedImageContainer extends StatefulWidget {
  final double size;
  final OnboardingSlideModel slide;

  const AnimatedImageContainer({
    super.key,
    required this.size,
    required this.slide,
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

  /// Admin-managed slides are remote URLs; the bundled fallback set ships as
  /// assets. Both render at the same size through this one widget.
  Widget _buildImage() {
    if (widget.slide.isAsset) {
      return Image.asset(widget.slide.imageUrl, fit: BoxFit.contain);
    }

    return CachedNetworkImage(
      imageUrl: widget.slide.imageUrl,
      fit: BoxFit.contain,
      placeholder: (context, _) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      errorWidget: (context, _, __) => Icon(
        Icons.image_not_supported_outlined,
        size: widget.size * 0.4,
        color: AppColors.textSecondary,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Transform.scale(
          scale: _scaleAnimation.value,
          child: child,
        );
      },
      // Outside the builder: the image should not be rebuilt 60 times a second
      // just because the scale changed.
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: _buildImage(),
      ),
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
