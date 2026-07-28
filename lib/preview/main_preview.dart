// lib/preview/main_preview.dart
//
// Web entrypoint for the admin panel's live preview.
//
//   flutter build web -t lib/preview/main_preview.dart \
//     --output build/preview --web-renderer canvaskit
//
// A second entrypoint rather than a second project. The preview imports the
// app's own widgets, theme, models and API client directly, so there is no
// shared-package boundary to keep in sync and no possibility of the preview
// rendering a stale copy of a screen. What ships to the phone and what the
// merchandiser sees are compiled from the same source.
//
// CanvasKit is specified on purpose: the HTML renderer approximates text
// layout and shadows, and a preview whose whole claim is fidelity cannot use
// an approximating backend.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/branding/app_branding.dart';
import '../core/config/app_theme.dart';
import '../core/time/clock.dart';
import '../di/infrastructure_providers.dart';
import '../presentation/providers/onboarding_provider.dart';
import '../presentation/providers/splash_provider.dart';
import 'preview_bridge.dart';
import 'preview_controller.dart';
import 'preview_host.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // The real screens reach for stored preferences the same way here as they do
  // on the phone — favourites, the selected outlet, cached branding. The
  // provider throws until it is overridden, so without this a rail that reads
  // prefs renders its error state and the preview misreports a working screen
  // as broken. Backed by localStorage on web, scoped to this origin.
  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),

        // Scheduling reads the clock rather than the wall, so the admin can
        // ask what a screen looks like next Tuesday.
        clockProvider.overrideWith((ref) {
          final instant = ref.watch(
            previewControllerProvider.select((s) => s.clockOverride),
          );
          return instant == null ? const SystemClock() : FixedClock(instant);
        }),

        // Onboarding draws the admin's unsaved slides instead of what the API
        // last returned — otherwise the preview would lag every edit by a save.
        onboardingSlidesProvider.overrideWith(
          (ref) async => ref.watch(previewSlidesProvider),
        ),

        // The splash screen's job on a phone is to finish and get out of the
        // way. Held open here, because a splash the merchandiser cannot look
        // at is not a preview of anything.
        splashInitializationProvider.overrideWith(
          (ref) => Completer<void>().future,
        ),
      ],
      child: const PreviewApp(),
    ),
  );
}

class PreviewApp extends ConsumerWidget {
  const PreviewApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branding = AppBranding.instance;

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: '${branding.appName} preview',

      // The app's own theme object, not a copy of its values. A preview with
      // its own ThemeData would drift the first time a colour changed.
      //
      // There is deliberately no darkTheme here: the app itself ships a single
      // theme, so a dark preview would be showing something no shopper can
      // see. When AppTheme gains a dark variant, add it in both places at
      // once — inventing one here is how a preview starts lying.
      theme: AppTheme.theme,

      routerConfig: ref.watch(_previewRouterProvider),
    );
  }
}

/// A router that reports navigation instead of performing it.
///
/// The real screens call `context.go` — onboarding does it on Finish — and
/// without a GoRouter ancestor that throws. Following the route would be worse
/// still: the merchandiser would tap once and lose the screen they were
/// editing. So every route resolves back to the preview surface, and the
/// attempted destination is sent to the panel to display.
///
/// Held in a provider rather than built in `build`, which would hand
/// MaterialApp a new router on every rebuild and reset its state each time.
final _previewRouterProvider = Provider<GoRouter>((ref) => GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            backgroundColor: Colors.transparent,
            body: PreviewHost(),
          ),
        ),
      ],
      redirect: (context, state) {
        final target = state.uri.toString();
        if (target == '/') return null;

        ref.read(previewBridgeProvider).reportNavigation(target);
        return '/';
      },
    ));
