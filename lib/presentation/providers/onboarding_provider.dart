import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/models/onboarding_slide_model.dart';
import '../../di/repository_providers.dart';

// Onboarding state model
class OnboardingState {
  final bool isCompleted;
  final bool isLoading;
  final Object? error;

  const OnboardingState({
    this.isCompleted = false,
    this.isLoading = false,
    this.error,
  });

  OnboardingState copyWith({
    bool? isCompleted,
    bool? isLoading,
    Object? error,
  }) {
    return OnboardingState(
      isCompleted: isCompleted ?? this.isCompleted,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

// Provider to manage onboarding completion state
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState(isLoading: true)) {
    _loadOnboardingStatus();
  }

  Future<void> _loadOnboardingStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isCompleted = prefs.getBool('hasCompletedOnboarding') ?? false;
      state = OnboardingState(isCompleted: isCompleted);
    } catch (error) {
      state = OnboardingState(error: error);
    }
  }

  Future<void> completeOnboarding() async {
    try {
      state = state.copyWith(isLoading: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedOnboarding', true);
      state = OnboardingState(isCompleted: true);
    } catch (error) {
      state = OnboardingState(error: error, isCompleted: state.isCompleted);
    }
  }

  Future<void> resetOnboarding() async {
    try {
      state = state.copyWith(isLoading: true);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('hasCompletedOnboarding', false);
      state = OnboardingState(isCompleted: false);
    } catch (error) {
      state = OnboardingState(error: error, isCompleted: state.isCompleted);
    }
  }
}

final onboardingProvider = StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});

// Simple provider to check if onboarding is completed
final hasCompletedOnboardingProvider = Provider<bool>((ref) {
  return ref.watch(onboardingProvider).isCompleted;
});

/// Slides for the first-launch carousel, managed in the admin panel.
///
/// The repository already falls back to cache and then to the bundled slides,
/// so this never surfaces an error state to the screen.
final onboardingSlidesProvider =
    FutureProvider<List<OnboardingSlideModel>>((ref) async {
  return ref.watch(onboardingRepositoryProvider).getSlides();
});