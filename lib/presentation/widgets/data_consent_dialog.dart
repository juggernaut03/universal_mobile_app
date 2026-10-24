// lib/presentation/widgets/data_consent_dialog.dart
//
// Shown once, right before the native App Tracking Transparency prompt, so
// the system "Allow Tracking" dialog isn't the first thing a user sees with
// no context for it. Explains what that permission actually controls: a
// device identifier shared with Meta/Facebook for ad personalization and
// measurement. This dialog only has a "Continue" button — the actual
// allow/deny decision always happens in Apple's own system prompt right
// after, never here, per App Tracking Transparency requirements.

import 'package:flutter/material.dart';

import '../../core/branding/app_branding.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class DataConsentDialog extends StatelessWidget {
  const DataConsentDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DataConsentDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appName = AppBranding.instance.appName;
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withOpacity(0.1),
              ),
              child: Icon(
                Icons.privacy_tip_outlined,
                color: AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your privacy choices',
              textAlign: TextAlign.center,
              style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '$appName uses your device activity to show more relevant offers '
              'and measure how well they work. On the next screen, iOS will ask '
              'whether $appName can track your activity across other companies\' '
              'apps and websites.\n\n'
              'You can allow or decline — $appName works either way, and you can '
              'change this anytime in iOS Settings > Privacy & Security > Tracking.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Continue'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
