// lib/presentation/providers/app_shell_providers.dart
//
// State for the app shell — drawer, back handling, onboarding.
//
// These were declared inside the widgets that consumed them, which is how
// provider declarations ended up scattered across 12 screen files.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/utils/back_handler.dart';
import '../../di/auth_providers.dart';
import '../../di/infrastructure_providers.dart';
import '../../di/repository_providers.dart';
import 'auth_providers.dart';

/// Hardware/gesture back handling.
final backButtonHandlerProvider = Provider<BackButtonHandler>((ref) {
  return BackButtonHandler(logger: ref.watch(loggerProvider));
});

/// Which onboarding page is showing.
final onboardingPageProvider = StateProvider<int>((ref) => 0);

/// Name shown in the drawer, falling back to "Guest" when signed out.
final userDisplayNameProvider = FutureProvider.autoDispose<String>((ref) async {
  final session =
      (await ref.read(authRepositoryProvider).currentSession()).valueOrNull;
  if (session == null) return 'Guest';

  try {
    final profile = await ref.read(profileRepositoryProvider).getUserProfile();
    final name = (profile['name'] ?? profile['full_name'] ?? '').toString().trim();
    return name.isEmpty ? session.mobile : name;
  } catch (_) {
    // The drawer must still render if the profile call fails.
    return session.mobile;
  }
});

/// Signed-in flag for immediate UI updates, without awaiting a fetch.
final quickLoginStatusProvider = Provider<bool>((ref) {
  return ref.watch(userProfileProvider).valueOrNull != null;
});
