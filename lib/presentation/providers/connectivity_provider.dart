// lib/presentation/providers/connectivity_provider.dart
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Live device-level connectivity (wifi/cellular link present or not) — not
/// "can we reach our backend". It exists so the home screen can show a
/// single clear "no internet connection" screen instead of letting every
/// individual banner/category widget fail independently and render its own
/// broken-looking placeholder.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

/// True once we've positively observed no connectivity. Starts `false`
/// (assume online) so the app doesn't flash a "no internet" screen before
/// the first connectivity event arrives.
final isOfflineProvider = Provider<bool>((ref) {
  final connectivity = ref.watch(connectivityStreamProvider);
  return connectivity.maybeWhen(
    data:
        (results) =>
            results.isNotEmpty &&
            results.every((r) => r == ConnectivityResult.none),
    orElse: () => false,
  );
});
