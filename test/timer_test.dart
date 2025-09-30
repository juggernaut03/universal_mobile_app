import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../lib/presentation/providers/checkout_timer_provider.dart';
import '../lib/core/utils/logger.dart';

void main() {
  test('Timer should countdown correctly', () async {
    final logger = Logger();
    final container = ProviderContainer();
    final timerNotifier = CheckoutTimerNotifier(logger);

    // Start timer
    timerNotifier.startTimer();

    // Check initial state
    expect(timerNotifier.state.remainingSeconds, 600);
    expect(timerNotifier.state.isActive, true);
    expect(timerNotifier.state.hasExpired, false);

    // Wait for 2 seconds
    await Future.delayed(const Duration(seconds: 2));

    // Check that timer has counted down
    expect(timerNotifier.state.remainingSeconds, lessThan(600));
    expect(timerNotifier.state.isActive, true);

    // Stop timer
    timerNotifier.stopTimer();

    expect(timerNotifier.state.isActive, false);
    expect(timerNotifier.state.remainingSeconds, 600); // Reset to initial
  });
}
