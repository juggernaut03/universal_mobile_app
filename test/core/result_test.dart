// test/core/result_test.dart
//
// Phase 0 foundation tests: the Result<T> contract.

import 'package:flutter_test/flutter_test.dart';
import 'package:patelmart/core/error/failure.dart';
import 'package:patelmart/core/result/result.dart';

void main() {
  const failure = NetworkFailure('no connectivity');

  group('Ok', () {
    test('reports isOk and exposes its value', () {
      const result = Ok<int>(42);

      expect(result.isOk, isTrue);
      expect(result.isErr, isFalse);
      expect(result.valueOrNull, 42);
      expect(result.failureOrNull, isNull);
    });

    test('folds through the success branch', () {
      const result = Ok<int>(42);

      expect(result.fold((v) => 'ok:$v', (f) => 'err:${f.message}'), 'ok:42');
    });

    test('map transforms the value', () {
      expect(const Ok<int>(21).map((v) => v * 2), const Ok<int>(42));
    });

    test('flatMap chains into the next operation', () {
      final result = const Ok<int>(21).flatMap((v) => Ok<String>('$v'));

      expect(result, const Ok<String>('21'));
    });

    test('mapErr leaves a success untouched', () {
      final result =
          const Ok<int>(42).mapErr((f) => const CacheFailure('replaced'));

      expect(result, const Ok<int>(42));
    });

    test('getOrElse returns the value without invoking the fallback', () {
      var fallbackCalled = false;

      final value = const Ok<int>(42).getOrElse((f) {
        fallbackCalled = true;
        return 0;
      });

      expect(value, 42);
      expect(fallbackCalled, isFalse);
    });

    test('onSuccess fires and onFailure does not', () {
      var successes = 0;
      var failures = 0;

      const Ok<int>(42)
          .onSuccess((_) => successes++)
          .onFailure((_) => failures++);

      expect(successes, 1);
      expect(failures, 0);
    });
  });

  group('Err', () {
    test('reports isErr and exposes its failure', () {
      const result = Err<int>(failure);

      expect(result.isOk, isFalse);
      expect(result.isErr, isTrue);
      expect(result.valueOrNull, isNull);
      expect(result.failureOrNull, failure);
    });

    test('folds through the failure branch', () {
      const result = Err<int>(failure);

      expect(
        result.fold((v) => 'ok:$v', (f) => 'err:${f.message}'),
        'err:no connectivity',
      );
    });

    test('map propagates the failure without invoking the transform', () {
      var transformCalled = false;

      final result = const Err<int>(failure).map((v) {
        transformCalled = true;
        return v * 2;
      });

      expect(result, const Err<int>(failure));
      expect(transformCalled, isFalse);
    });

    test('flatMap short-circuits', () {
      var transformCalled = false;

      final result = const Err<int>(failure).flatMap((v) {
        transformCalled = true;
        return Ok<String>('$v');
      });

      expect(result, const Err<String>(failure));
      expect(transformCalled, isFalse);
    });

    test('mapErr replaces the failure', () {
      final result =
          const Err<int>(failure).mapErr((f) => const CacheFailure('replaced'));

      expect(result.failureOrNull, const CacheFailure('replaced'));
    });

    test('getOrElse falls back using the failure', () {
      final value = const Err<int>(failure).getOrElse((f) => f.message.length);

      expect(value, 'no connectivity'.length);
    });

    test('onFailure fires and onSuccess does not', () {
      var successes = 0;
      var failures = 0;

      const Err<int>(failure)
          .onSuccess((_) => successes++)
          .onFailure((_) => failures++);

      expect(successes, 0);
      expect(failures, 1);
    });
  });

  group('exhaustiveness', () {
    // The point of sealing Result: a switch with both branches and no
    // `default:` compiles. If a third subtype were ever added, this stops
    // compiling — which is the intended alarm.
    String describe(Result<int> result) => switch (result) {
          Ok(:final value) => 'ok:$value',
          Err(:final failure) => 'err:${failure.message}',
        };

    test('switch covers both branches with no default', () {
      expect(describe(const Ok(1)), 'ok:1');
      expect(describe(const Err(failure)), 'err:no connectivity');
    });
  });

  group('equality', () {
    test('same-type results with equal payloads are equal', () {
      expect(const Ok<int>(1), const Ok<int>(1));
      expect(const Err<int>(failure), const Err<int>(failure));
      expect(const Ok<int>(1).hashCode, const Ok<int>(1).hashCode);
    });

    test('differing payloads are not equal', () {
      expect(const Ok<int>(1), isNot(const Ok<int>(2)));
      expect(
        const Err<int>(failure),
        isNot(const Err<int>(CacheFailure('other'))),
      );
    });

    test('Ok and Err are never equal', () {
      expect(const Ok<int>(1), isNot(const Err<int>(failure)));
    });
  });

  group('factory constructors', () {
    test('Result.ok and Result.err build the matching subtypes', () {
      expect(const Result<int>.ok(1), isA<Ok<int>>());
      expect(const Result<int>.err(failure), isA<Err<int>>());
    });
  });

  group('FutureResultX', () {
    test('mapAsync transforms a successful future', () async {
      final result = await Future.value(const Ok<int>(21)).mapAsync((v) => v * 2);

      expect(result, const Ok<int>(42));
    });

    test('flatMapAsync chains an async fallible step', () async {
      final result = await Future.value(const Ok<int>(21))
          .flatMapAsync((v) async => Ok<String>('$v'));

      expect(result, const Ok<String>('21'));
    });

    test('flatMapAsync short-circuits on failure', () async {
      var transformCalled = false;

      final result =
          await Future.value(const Err<int>(failure)).flatMapAsync((v) async {
        transformCalled = true;
        return Ok<String>('$v');
      });

      expect(result, const Err<String>(failure));
      expect(transformCalled, isFalse);
    });

    test('foldAsync collapses both branches', () async {
      expect(
        await Future.value(const Ok<int>(42))
            .foldAsync((v) => 'ok:$v', (f) => 'err'),
        'ok:42',
      );
      expect(
        await Future.value(const Err<int>(failure))
            .foldAsync((v) => 'ok:$v', (f) => 'err'),
        'err',
      );
    });
  });
}
