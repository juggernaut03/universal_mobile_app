import 'package:flutter/services.dart';

/// Input formatter that blocks emoji and pictographic characters.
/// Use on any TextField/TextFormField that should accept only regular text/numbers.
class NoEmojiInputFormatter extends TextInputFormatter {
  // Matches emoji, pictographs, symbols, flags, and variation selectors.
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}\u{FE00}-\u{FE0F}\u{1F1E6}-\u{1F1FF}\u{200D}]',
    unicode: true,
  );

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (_emojiRegex.hasMatch(newValue.text)) {
      // Strip emojis and return the cleaned text
      final cleaned = newValue.text.replaceAll(_emojiRegex, '');
      return TextEditingValue(
        text: cleaned,
        selection: TextSelection.collapsed(offset: cleaned.length),
      );
    }
    return newValue;
  }
}
