// lib/core/error/failure_mapper.dart
//
// The single translation point between the data layer's exception channel and
// the domain layer's Failure channel.
//
//   datasource --throws AppException--> repository impl --Err(Failure)--> domain
//                                            ^
//                                       uses this
//
// Repository implementations should not hand-roll this mapping; a missed case
// is how an untyped error leaks upward. Prefer `guard`, which wraps the call
// and performs the translation in one place.

import 'dart:async' as async;
import 'dart:io';

import 'package:http/http.dart' as http;

import '../result/result.dart';
import 'exceptions.dart';
import 'failure.dart';

/// Translates any thrown [error] into the equivalent [Failure].
///
/// Handles the project's own [AppException] types first, then the platform and
/// package errors datasources may surface without wrapping. Anything
/// unrecognised becomes [UnknownFailure] — reaching that case in production is
/// a signal that a specific failure type should be introduced.
Failure mapErrorToFailure(Object error, [StackTrace? stackTrace]) {
  return switch (error) {
    // ---- Project exceptions (the expected path) ----
    NetworkException e =>
      NetworkFailure(e.message, cause: e.cause, stackTrace: e.stackTrace ?? stackTrace),
    RequestTimeoutException e => NetworkFailure(
        e.timeout == null
            ? e.message
            : '${e.message} (timeout: ${e.timeout!.inSeconds}s)',
        cause: e.cause,
        stackTrace: e.stackTrace ?? stackTrace,
      ),
    ServerException e => ServerFailure(
        e.message,
        statusCode: e.statusCode,
        cause: e.cause,
        stackTrace: e.stackTrace ?? stackTrace,
      ),
    ParsingException e => ServerFailure(
        e.targetType == null
            ? e.message
            : '${e.message} (while parsing ${e.targetType})',
        cause: e.cause,
        stackTrace: e.stackTrace ?? stackTrace,
      ),
    CacheException e =>
      CacheFailure(e.message, cause: e.cause, stackTrace: e.stackTrace ?? stackTrace),
    AuthException e => AuthFailure(
        e.message,
        requiresReauthentication: e.requiresReauthentication,
        cause: e.cause,
        stackTrace: e.stackTrace ?? stackTrace,
      ),
    ValidationException e => ValidationFailure(
        e.message,
        fieldErrors: e.fieldErrors,
        cause: e.cause,
        stackTrace: e.stackTrace ?? stackTrace,
      ),
    NotFoundException e =>
      NotFoundFailure(e.message, cause: e.cause, stackTrace: e.stackTrace ?? stackTrace),

    // ---- Platform / package errors reaching us unwrapped ----
    SocketException e =>
      NetworkFailure('Network unreachable: ${e.message}', cause: e, stackTrace: stackTrace),
    HttpException e =>
      NetworkFailure('HTTP error: ${e.message}', cause: e, stackTrace: stackTrace),
    http.ClientException e =>
      NetworkFailure('Request failed: ${e.message}', cause: e, stackTrace: stackTrace),
    async.TimeoutException e => NetworkFailure(
        'Request timed out${e.duration == null ? '' : ' after ${e.duration!.inSeconds}s'}',
        cause: e,
        stackTrace: stackTrace,
      ),
    FormatException e => ServerFailure(
        'Malformed response: ${e.message}',
        cause: e,
        stackTrace: stackTrace,
      ),

    // ---- Anything else ----
    _ => UnknownFailure(error.toString(), cause: error, stackTrace: stackTrace),
  };
}

/// Runs [operation] and converts any thrown error into an [Err].
///
/// The standard body of a repository method:
///
/// ```dart
/// @override
/// Future<Result<Product>> getProductByCode(String code) =>
///     guard(() async => (await _remote.fetchProduct(code)).toEntity());
/// ```
///
/// This keeps the try/catch out of every method and guarantees no exception
/// escapes the data layer.
Future<Result<T>> guard<T>(Future<T> Function() operation) async {
  try {
    return Ok(await operation());
  } catch (error, stackTrace) {
    return Err(mapErrorToFailure(error, stackTrace));
  }
}

/// Synchronous counterpart of [guard], for parsing and cache reads that do not
/// involve I/O.
Result<T> guardSync<T>(T Function() operation) {
  try {
    return Ok(operation());
  } catch (error, stackTrace) {
    return Err(mapErrorToFailure(error, stackTrace));
  }
}
