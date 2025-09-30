import 'dart:math' as math;
import 'package:flutter/services.dart';

/// Blocks non-ASCII characters and invokes [onBlocked] every time
/// a non-English character input is attempted.
class AsciiOnlyInputFormatter extends TextInputFormatter {
  AsciiOnlyInputFormatter({required this.onBlocked});

  final void Function() onBlocked;

  static final RegExp _nonAscii = RegExp(r"[^\x00-\x7F]");

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_nonAscii.hasMatch(newValue.text)) {
      final String sanitized = newValue.text.replaceAll(_nonAscii, '');

      // Notify caller every time we block non-English input
      onBlocked();

      final int removed = newValue.text.length - sanitized.length;
      final int base = newValue.selection.baseOffset;
      final int newOffset = math.max(0, math.min(sanitized.length, base - removed));

      return TextEditingValue(
        text: sanitized,
        selection: TextSelection.collapsed(offset: newOffset),
        composing: TextRange.empty,
      );
    }
    return newValue;
  }
}