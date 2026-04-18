import 'package:flutter/services.dart';

/// Input formatter that blocks emoji and pictographic characters,
/// prevents leading whitespace, and collapses consecutive spaces.
class NoEmojiInputFormatter extends TextInputFormatter {
  // Matches emoji, pictographs, symbols, flags, and variation selectors.
  static final RegExp _emojiRegex = RegExp(
    r'[\u{1F000}-\u{1FFFF}\u{2600}-\u{27BF}\u{2300}-\u{23FF}\u{2B00}-\u{2BFF}\u{FE00}-\u{FE0F}\u{1F1E6}-\u{1F1FF}\u{200D}]',
    unicode: true,
  );

  // Matches 2+ consecutive whitespace characters
  static final RegExp _multiSpaceRegex = RegExp(r' {2,}');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    // 1) Strip emojis
    if (_emojiRegex.hasMatch(text)) {
      text = text.replaceAll(_emojiRegex, '');
    }

    // 2) Remove leading whitespace
    text = text.trimLeft();

    // 3) Collapse multiple spaces into single space
    if (_multiSpaceRegex.hasMatch(text)) {
      text = text.replaceAll(_multiSpaceRegex, ' ');
    }

    // If nothing changed, return as-is to preserve cursor position
    if (text == newValue.text) {
      return newValue;
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(
        offset: text.length < newValue.selection.baseOffset
            ? text.length
            : newValue.selection.baseOffset.clamp(0, text.length),
      ),
    );
  }
}
