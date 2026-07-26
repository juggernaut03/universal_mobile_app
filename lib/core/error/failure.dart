// lib/core/error/failure.dart
//
// The single vocabulary of failure for the whole application.
//
// A Failure is what crosses a layer boundary when an operation does not succeed.
// It is produced in the data layer (by translating an AppException) and consumed
// in the presentation layer. Domain and presentation code never sees an
// exception — only a Failure carried inside an [Err].
//
// Failure is `sealed`, so `switch` over it is exhaustive: adding a new failure
// type turns every unhandled call site into a compile error rather than a
// silent runtime fallthrough.

import 'package:flutter/foundation.dart';

/// Base type for every recoverable error surfaced to the domain layer.
///
/// [message] is a developer-facing description and is safe to log but NOT safe
/// to render — it may contain endpoint names, payload fragments or driver text.
/// Render [userMessage] instead.
@immutable
sealed class Failure {
  /// Developer-facing description. Log this; do not show it to users.
  final String message;

  /// The originating error, when one exists. Never rendered.
  final Object? cause;

  /// Stack trace captured where the failure originated.
  final StackTrace? stackTrace;

  const Failure(this.message, {this.cause, this.stackTrace});

  /// Safe, human-readable text for display in the UI.
  ///
  /// Subclasses override this with a message that reveals nothing about the
  /// system's internals.
  String get userMessage;

  /// Whether retrying the same operation could plausibly succeed.
  ///
  /// Lets the UI decide between showing a "Retry" affordance and a terminal
  /// error state, without inspecting the concrete failure type.
  bool get isRetryable;

  @override
  String toString() => '$runtimeType($message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Failure &&
          other.runtimeType == runtimeType &&
          other.message == message;

  @override
  int get hashCode => Object.hash(runtimeType, message);
}

/// The device could not reach the server: no connectivity, DNS failure,
/// connection refused, or the request exceeded its timeout.
final class NetworkFailure extends Failure {
  const NetworkFailure(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage =>
      'No internet connection. Please check your network and try again.';

  @override
  bool get isRetryable => true;
}

/// The server was reached but responded with an error status, or returned a
/// body that could not be understood.
final class ServerFailure extends Failure {
  /// HTTP status code, when the failure came from a completed response.
  final int? statusCode;

  const ServerFailure(
    super.message, {
    this.statusCode,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage =>
      'Something went wrong on our end. Please try again in a moment.';

  /// 5xx responses are transient; 4xx responses will fail identically on retry.
  @override
  bool get isRetryable => statusCode == null || statusCode! >= 500;

  @override
  String toString() => 'ServerFailure($statusCode, $message)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ServerFailure &&
          other.message == message &&
          other.statusCode == statusCode;

  @override
  int get hashCode => Object.hash(runtimeType, message, statusCode);
}

/// Local persistence failed: cache miss where a value was required, corrupt
/// cached payload, or a read/write error against storage.
final class CacheFailure extends Failure {
  const CacheFailure(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Could not load saved data. Please try again.';

  @override
  bool get isRetryable => true;
}

/// The caller is not authenticated, the session expired, or the server rejected
/// the credentials.
///
/// [requiresReauthentication] tells the presentation layer whether to route the
/// user to login, rather than each screen re-deriving that from the message.
final class AuthFailure extends Failure {
  /// Whether the user must sign in again to recover.
  final bool requiresReauthentication;

  const AuthFailure(
    super.message, {
    this.requiresReauthentication = true,
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => requiresReauthentication
      ? 'Your session has expired. Please sign in again.'
      : 'You are not authorised to perform this action.';

  /// Retrying without new credentials cannot help.
  @override
  bool get isRetryable => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AuthFailure &&
          other.message == message &&
          other.requiresReauthentication == requiresReauthentication;

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, requiresReauthentication);
}

/// Input or state failed a business rule — an empty cart at checkout, an
/// unserviceable pincode, an order below the minimum value.
///
/// This is the one failure whose [message] is authored by us rather than
/// derived from a system error, so it is safe to display directly.
final class ValidationFailure extends Failure {
  /// Field-level errors keyed by field name, for form rendering.
  final Map<String, String> fieldErrors;

  const ValidationFailure(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
    super.stackTrace,
  });

  /// Authored by us against a known business rule, so it is safe to render.
  @override
  String get userMessage => message;

  @override
  bool get isRetryable => false;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ValidationFailure &&
          other.message == message &&
          mapEquals(other.fieldErrors, fieldErrors);

  @override
  int get hashCode =>
      Object.hash(runtimeType, message, Object.hashAllUnordered(fieldErrors.keys));
}

/// The requested resource does not exist — an unknown product code, a deleted
/// address, an order that is not visible to this user.
final class NotFoundFailure extends Failure {
  const NotFoundFailure(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'We could not find what you were looking for.';

  @override
  bool get isRetryable => false;
}

/// Fallback for errors that do not map to any known category.
///
/// Reaching this type in production is a signal that a specific [Failure]
/// should be introduced for the underlying condition.
final class UnknownFailure extends Failure {
  const UnknownFailure(
    super.message, {
    super.cause,
    super.stackTrace,
  });

  @override
  String get userMessage => 'Something went wrong. Please try again.';

  @override
  bool get isRetryable => true;
}
