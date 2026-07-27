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
// rendering a stale copy of a section. What ships to the phone and what the
// merchandiser sees are compiled from the same source.
//
// CanvasKit is specified on purpose: the HTML renderer approximates text
// layout and shadows, and a preview whose whole claim is fidelity cannot use
// an approximating backend.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/branding/app_branding.dart';
import '../core/config/app_theme.dart';
import '../core/time/clock.dart';
import 'preview_controller.dart';
import 'preview_host.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    ProviderScope(
      overrides: [
        // Scheduling reads the clock rather than the wall, so the admin can
        // ask what home looks like next Tuesday. Everything else — every
        // provider the sections use — is left exactly as production wires it.
        clockProvider.overrideWith((ref) {
          final instant = ref.watch(
            previewControllerProvider.select((s) => s.clockOverride),
          );
          return instant == null ? const SystemClock() : FixedClock(instant);
        }),
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

    return MaterialApp(
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

      home: const Scaffold(
        backgroundColor: Colors.transparent,
        body: PreviewHost(),
      ),
    );
  }
}
