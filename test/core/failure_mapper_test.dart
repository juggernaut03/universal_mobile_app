// test/core/failure_mapper_test.dart
//
// Phase 0 foundation tests: the Failure hierarchy and the exception-to-failure
// boundary translation.

import 'dart:async' as async;
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:patelmart/core/error/exceptions.dart';
import 'package:patelmart/core/error/failure.dart';
import 'package:patelmart/core/error/failure_mapper.dart';
import 'package:patelmart/core/result/result.dart';

void main() {
  group('Failure.userMessage', () {
    test('never leaks the developer message, except for ValidationFailure', () {
      const developerDetail = 'POST /products/get-products returned 500';

      const failures = <Failure>[
        NetworkFailure(developerDetail),
        ServerFailure(developerDetail),
        CacheFailure(developerDetail),
        AuthFailure(developerDetail),
        NotFoundFailure(developerDetail),
        UnknownFailure(developerDetail),
      ];

      for (final failure in failures) {
        expect(
          failure.userMessage,
          isNot(contains(developerDetail)),
          reason: '${failure.runtimeType} leaked its developer message',
        );
        expect(failure.userMessage, isNotEmpty);
      }
    });

    test('ValidationFailure renders its message, being authored by us', () {
      const failure = ValidationFailure('Minimum order value is Rs. 200');

      expect(failure.userMessage, 'Minimum order value is Rs. 200');
    });
  });

  group('Failure.isRetryable', () {
    test('network and cache failures are retryable', () {
      expect(const NetworkFailure('x').isRetryable, isTrue);
      expect(const CacheFailure('x').isRetryable, isTrue);
    });

    test('server 5xx is retryable, 4xx is not', () {
      expect(const ServerFailure('x', statusCode: 503).isRetryable, isTrue);
      expect(const ServerFailure('x', statusCode: 400).isRetryable, isFalse);
      expect(const ServerFailure('x', statusCode: 404).isRetryable, isFalse);
    });

    test('unknown status is treated as retryable', () {
      expect(const ServerFailure('x').isRetryable, isTrue);
    });

    test('auth, validation and not-found are not retryable', () {
      expect(const AuthFailure('x').isRetryable, isFalse);
      expect(const ValidationFailure('x').isRetryable, isFalse);
      expect(const NotFoundFailure('x').isRetryable, isFalse);
    });
  });

  group('AuthFailure.requiresReauthentication', () {
    test('drives which message the user sees', () {
      expect(
        const AuthFailure('x').userMessage,
        contains('sign in again'),
      );
      expect(
        const AuthFailure('x', requiresReauthentication: false).userMessage,
        contains('not authorised'),
      );
    });
  });

  group('mapErrorToFailure — project exceptions', () {
    test('maps each AppException to its Failure counterpart', () {
      expect(
        mapErrorToFailure(const NetworkException('offline')),
        isA<NetworkFailure>(),
      );
      expect(
        mapErrorToFailure(const RequestTimeoutException('slow')),
        isA<NetworkFailure>(),
      );
      expect(
        mapErrorToFailure(const ServerException('boom', statusCode: 500)),
        isA<ServerFailure>(),
      );
      expect(
        mapErrorToFailure(const ParsingException('bad json')),
        isA<ServerFailure>(),
      );
      expect(
        mapErrorToFailure(const CacheException('disk full')),
        isA<CacheFailure>(),
      );
      expect(
        mapErrorToFailure(const AuthException('expired')),
        isA<AuthFailure>(),
      );
      expect(
        mapErrorToFailure(const ValidationException('too small')),
        isA<ValidationFailure>(),
      );
      expect(
        mapErrorToFailure(const NotFoundException('gone')),
        isA<NotFoundFailure>(),
      );
    });

    test('preserves the status code across the boundary', () {
      final failure =
          mapErrorToFailure(const ServerException('boom', statusCode: 503));

      expect((failure as ServerFailure).statusCode, 503);
      expect(failure.isRetryable, isTrue);
    });

    test('preserves requiresReauthentication across the boundary', () {
      final failure = mapErrorToFailure(
        const AuthException('forbidden', requiresReauthentication: false),
      );

      expect((failure as AuthFailure).requiresReauthentication, isFalse);
    });

    test('preserves field errors across the boundary', () {
      final failure = mapErrorToFailure(
        const ValidationException('bad', fieldErrors: {'pincode': 'required'}),
      );

      expect((failure as ValidationFailure).fieldErrors, {'pincode': 'required'});
    });

    test('includes the timeout budget in the message when known', () {
      final failure = mapErrorToFailure(
        const RequestTimeoutException('timed out',
            timeout: Duration(seconds: 15)),
      );

      expect(failure.message, contains('15s'));
    });
  });

  group('mapErrorToFailure — unwrapped platform errors', () {
    test('SocketException becomes NetworkFailure', () {
      expect(
        mapErrorToFailure(const SocketException('unreachable')),
        isA<NetworkFailure>(),
      );
    });

    test('http.ClientException becomes NetworkFailure', () {
      expect(
        mapErrorToFailure(http.ClientException('connection closed')),
        isA<NetworkFailure>(),
      );
    });

    test('async TimeoutException becomes NetworkFailure', () {
      expect(
        mapErrorToFailure(async.TimeoutException('slow')),
        isA<NetworkFailure>(),
      );
    });

    test('FormatException becomes ServerFailure', () {
      expect(
        mapErrorToFailure(const FormatException('unexpected token')),
        isA<ServerFailure>(),
      );
    });

    test('anything unrecognised becomes UnknownFailure', () {
      expect(mapErrorToFailure(StateError('bad state')), isA<UnknownFailure>());
      expect(mapErrorToFailure('a bare string'), isA<UnknownFailure>());
    });

    test('retains the original error as cause for diagnostics', () {
      final original = StateError('bad state');

      expect(mapErrorToFailure(original).cause, same(original));
    });
  });

  group('guard', () {
    test('wraps a successful operation in Ok', () async {
      expect(await guard(() async => 42), const Ok<int>(42));
    });

    test('converts a thrown AppException into a typed Err', () async {
      final result =
          await guard<int>(() async => throw const AuthException('expired'));

      expect(result.failureOrNull, isA<AuthFailure>());
    });

    test('converts an unexpected throw into UnknownFailure', () async {
      final result = await guard<int>(() async => throw StateError('oops'));

      expect(result.failureOrNull, isA<UnknownFailure>());
    });

    test('lets no exception escape', () async {
      // The core guarantee: whatever the operation throws, guard returns.
      await expectLater(
        guard<int>(() async => throw const ServerException('boom')),
        completion(isA<Err<int>>()),
      );
    });
  });

  group('guardSync', () {
    test('wraps a successful computation in Ok', () {
      expect(guardSync(() => 42), const Ok<int>(42));
    });

    test('converts a FormatException into ServerFailure', () {
      final result = guardSync<int>(
        () => throw const FormatException('unexpected token'),
      );

      expect(result.failureOrNull, isA<ServerFailure>());
    });
  });

  group('Failure equality', () {
    test('same type and message are equal', () {
      expect(const NetworkFailure('x'), const NetworkFailure('x'));
    });

    test('different failure types are never equal', () {
      expect(const NetworkFailure('x'), isNot(const CacheFailure('x')));
    });

    test('ServerFailure distinguishes status codes', () {
      expect(
        const ServerFailure('x', statusCode: 500),
        isNot(const ServerFailure('x', statusCode: 404)),
      );
    });
  });
}
