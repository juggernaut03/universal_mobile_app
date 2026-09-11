// lib/presentation/widgets/confirmation_dialog.dart
//
// One confirm/cancel dialog shape, used everywhere the app asks "are you
// sure?" — delete address, delete account, sign out, clear cart. Each of
// those used to build its own AlertDialog by hand, so the same question
// looked different on every screen (some had no icon, some used
// ElevatedButton, some TextButton, some uppercase labels, none shared a
// destructive-action color). This is that one shape, built once.

import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_text_styles.dart';

class ConfirmationDialog extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String cancelLabel;
  final String confirmLabel;
  final Color confirmColor;

  ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.delete_outline,
    Color? iconColor,
    this.cancelLabel = 'Cancel',
    this.confirmLabel = 'Delete',
    Color? confirmColor,
  }) : iconColor = iconColor ?? AppColors.error,
       confirmColor = confirmColor ?? AppColors.error;

  /// Shows the dialog and resolves to `true` only if the destructive action
  /// was confirmed — `false` on Cancel, and `null` if dismissed some other
  /// way (back gesture, tap outside). Callers should treat anything but
  /// `true` as "don't proceed".
  static Future<bool?> show(
    BuildContext context, {
    required String title,
    required String message,
    IconData icon = Icons.delete_outline,
    Color? iconColor,
    String cancelLabel = 'Cancel',
    String confirmLabel = 'Delete',
    Color? confirmColor,
  }) {
    return showDialog<bool>(
      context: context,
      builder:
          (_) => ConfirmationDialog(
            title: title,
            message: message,
            icon: icon,
            iconColor: iconColor,
            cancelLabel: cancelLabel,
            confirmLabel: confirmLabel,
            confirmColor: confirmColor,
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconColor.withOpacity(0.1),
              ),
              child: Icon(icon, color: iconColor, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppTextStyles.h6.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: AppColors.neutral300),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(cancelLabel),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: confirmColor,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(confirmLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
