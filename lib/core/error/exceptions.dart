// lib/core/error/exceptions.dart
//
// Exceptions are the data layer's INTERNAL error channel.
//
//   datasource  --throws AppException-->  repository impl  --returns Err(Failure)-->  domain
//
// Datasources throw these. Repository implementations catch them and translate
// them into a [Failure] (see failure_mapper.dart). An AppException must never
// escape the data layer — if one reaches domain or presentation code, a
// repository is missing its try/catch and that is a bug.

import 'package:flutter/foundation.dart';

/// Base type for every exception thrown inside the data layer.
@immutable
sealed class AppException implements Exception {
  /// Developer-facing description. Logged, never rendered.
  final String message;

  /// The originating error this wraps, when there is one.
  final Object? cause;

  /// Stack trace captured at the throw site.
  final StackTrace? stackTrace;

  const AppException(this.message, {this.cause, this.stackTrace});

  @override
  String toString() => '$runtimeType: $message';
}

/// The request never completed: no connectivity, DNS failure, connection
/// refused, or a socket-level error.
final class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// The request exceeded its time budget.
///
/// Distinct from [NetworkException] because a timeout may mean the server did
/// receive the request — which matters for non-idempotent calls such as order
/// placement, where a blind retry could double-submit.
///
/// Named `Request…` rather than `TimeoutException` so it does not collide with
/// `dart:async`'s `TimeoutException`, which datasources catch and wrap.
final class RequestTimeoutException extends AppException {
  /// The budget that elapsed.
  final Duration? timeout;

  const RequestTimeoutException(
    super.message, {
    this.timeout,
    super.cause,
    super.stackTrace,
  });
}

/// The server responded with a non-success status code.
final class ServerException extends AppException {
  /// HTTP status code of the response.
  final int? statusCode;

  /// Raw response body, retained for diagnostics only.
  final String? body;

  const ServerException(
    super.message, {
    this.statusCode,
    this.body,
    super.cause,
    super.stackTrace,
  });

  @override
  String toString() => 'ServerException($statusCode): $message';
}

/// A response arrived but could not be decoded into the expected shape:
/// malformed JSON, a missing required field, or an unexpected type.
final class ParsingException extends AppException {
  /// The type that was being constructed when parsing failed.
  final String? targetType;

  const ParsingException(
    super.message, {
    this.targetType,
    super.cause,
    super.stackTrace,
  });
}

/// A local storage read or write failed, or cached data was unusable.
final class CacheException extends AppException {
  const CacheException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}

/// Credentials are absent, expired, or were rejected by the server.
final class AuthException extends AppException {
  /// Whether recovery requires the user to sign in again.
  final bool requiresReauthentication;

  const AuthException(
    super.message, {
    this.requiresReauthentication = true,
    super.cause,
    super.stackTrace,
  });
}

/// The server understood the request but reported a business-rule violation
/// (unserviceable pincode, item out of stock, order below minimum value).
final class ValidationException extends AppException {
  /// Field-level errors keyed by field name.
  final Map<String, String> fieldErrors;

  const ValidationException(
    super.message, {
    this.fieldErrors = const {},
    super.cause,
    super.stackTrace,
  });
}

/// The requested resource does not exist.
final class NotFoundException extends AppException {
  const NotFoundException(
    super.message, {
    super.cause,
    super.stackTrace,
  });
}
