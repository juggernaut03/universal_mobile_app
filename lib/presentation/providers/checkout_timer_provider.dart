// lib/presentation/providers/checkout_timer_provider.dart

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/logger.dart';
import 'launch_flow_provider.dart';

// ⚙️ TIMER CONFIGURATION - Centralized settings
class CheckoutTimerConfig {
  static const int totalDurationSeconds = 600; // 10 minutes
  static const int warningZoneSeconds = 120; // 2 minutes warning
  static String get description => '${totalDurationSeconds ~/ 60} minutes';
}

// Timer state model
class CheckoutTimerState {
  final int remainingSeconds;
  final bool isActive;
  final bool hasExpired;
  final DateTime? startTime;

  const CheckoutTimerState({
    required this.remainingSeconds,
    required this.isActive,
    required this.hasExpired,
    this.startTime,
  });

  CheckoutTimerState copyWith({
    int? remainingSeconds,
    bool? isActive,
    bool? hasExpired,
    DateTime? startTime,
  }) {
    return CheckoutTimerState(
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      isActive: isActive ?? this.isActive,
      hasExpired: hasExpired ?? this.hasExpired,
      startTime: startTime ?? this.startTime,
    );
  }

  // Format remaining time as MM:SS
  String get formattedTime {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  // Check if timer is in warning zone (last 2 minutes)
  bool get isInWarningZone =>
      remainingSeconds <= CheckoutTimerConfig.warningZoneSeconds && remainingSeconds > 0;

  // Check if timer is in critical zone (last 30 seconds)
  bool get isInCriticalZone => remainingSeconds <= 30 && remainingSeconds > 0;
}

// Timer notifier with automatic reset logic
class CheckoutTimerNotifier extends StateNotifier<CheckoutTimerState> {
  Timer? _timer;
  final Logger _logger;

  CheckoutTimerNotifier(this._logger)
      : super(const CheckoutTimerState(
          remainingSeconds: CheckoutTimerConfig.totalDurationSeconds,
          isActive: false,
          hasExpired: false,
        ));

  // Start the countdown timer
  void startTimer() {
    if (state.isActive) {
      _logger.log('Timer already active, ignoring start request');
      return;
    }

    _logger.log('Starting checkout timer for ${CheckoutTimerConfig.totalDurationSeconds} seconds');

    state = state.copyWith(
      remainingSeconds: CheckoutTimerConfig.totalDurationSeconds,
      isActive: true,
      hasExpired: false,
      startTime: DateTime.now(),
    );

    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  // Force reset and start fresh timer (for new checkout sessions)
  void forceResetAndStart() {
    _logger.log('Force resetting and starting checkout timer');
    stopTimer();
    startTimer();
  }

  // Stop and reset timer
  void stopTimer() {
    _logger.log('Stopping checkout timer');

    _timer?.cancel();
    _timer = null;

    state = const CheckoutTimerState(
      remainingSeconds: CheckoutTimerConfig.totalDurationSeconds,
      isActive: false,
      hasExpired: false,
    );
  }

  // Pause timer (optional feature)
  void pauseTimer() {
    if (!state.isActive) return;

    _logger.log('Pausing checkout timer');
    _timer?.cancel();
    _timer = null;

    state = state.copyWith(isActive: false);
  }

  // Resume timer (optional feature)
  void resumeTimer() {
    if (state.isActive || state.hasExpired) return;

    _logger.log('Resuming checkout timer');
    state = state.copyWith(isActive: true);
    _timer = Timer.periodic(const Duration(seconds: 1), _onTimerTick);
  }

  // Handle timer tick
  void _onTimerTick(Timer timer) {
    if (!state.isActive || state.remainingSeconds <= 0) return;

    final newRemaining = state.remainingSeconds - 1;

    if (newRemaining <= 0) {
      _onTimerExpired();
    } else {
      state = state.copyWith(remainingSeconds: newRemaining);
    }
  }

  // Handle timer expiration
  void _onTimerExpired() {
    _logger.log('Checkout timer expired - redirecting to cart');

    _timer?.cancel();
    _timer = null;

    state = state.copyWith(
      remainingSeconds: 0,
      isActive: false,
      hasExpired: true,
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

// Main timer provider
final checkoutTimerProvider = StateNotifierProvider<CheckoutTimerNotifier, CheckoutTimerState>((ref) {
  final logger = ref.watch(loggerProvider);
  return CheckoutTimerNotifier(logger);
});

// Convenience provider for timer expiration state
final checkoutTimerExpiredProvider = Provider<bool>((ref) {
  final timerState = ref.watch(checkoutTimerProvider);
  return timerState.hasExpired;
});

// Convenience provider for timer active state
final checkoutTimerActiveProvider = Provider<bool>((ref) {
  final timerState = ref.watch(checkoutTimerProvider);
  return timerState.isActive;
});

// Convenience provider for formatted time display
final checkoutTimerDisplayProvider = Provider<String>((ref) {
  final timerState = ref.watch(checkoutTimerProvider);
  return timerState.formattedTime;
});
