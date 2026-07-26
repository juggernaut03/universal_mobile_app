// lib/domain/entities/pincode.dart

import 'package:meta/meta.dart';

/// An Indian postal code.
///
/// A value object rather than a bare `String`, so a pincode cannot be confused
/// with a store code, an order id or any other string in a call signature —
/// and so the 6-digit rule is stated once.
@immutable
final class Pincode {
  final String value;

  const Pincode._(this.value);

  static final RegExp _format = RegExp(r'^[1-9]\d{5}$');

  /// Builds a pincode, or returns null when [raw] is not six digits.
  ///
  /// Indian pincodes never start with 0, which is why the pattern excludes it.
  static Pincode? tryParse(String? raw) {
    final trimmed = raw?.trim() ?? '';
    return _format.hasMatch(trimmed) ? Pincode._(trimmed) : null;
  }

  /// Whether [raw] would produce a valid pincode.
  static bool isValid(String? raw) => tryParse(raw) != null;

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Pincode && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => value;
}

/// Whether the app delivers to a pincode, and why not when it does not.
///
/// Replaces `PincodeCheckResponse`, which encoded the answer as `count == 1`
/// with an `isPincodeServiceable()` method to decode it — the same
/// integer-as-boolean pattern as the old `authentication == 1`.
@immutable
final class Serviceability {
  final Pincode pincode;
  final bool isServiceable;

  /// Operator-supplied explanation, shown when not serviceable.
  final String message;

  const Serviceability({
    required this.pincode,
    required this.isServiceable,
    this.message = '',
  });

  /// Text to show the user when delivery is unavailable.
  String get unavailableMessage => message.isNotEmpty
      ? message
      : 'We do not deliver to $pincode yet.';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Serviceability &&
          other.pincode == pincode &&
          other.isServiceable == isServiceable;

  @override
  int get hashCode => Object.hash(pincode, isServiceable);

  @override
  String toString() => 'Serviceability($pincode, serviceable: $isServiceable)';
}
