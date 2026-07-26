// lib/core/result/result.dart
//
// The return type of every use case and every repository method.
//
// Replaces the codebase's previous convention of returning `null` on error,
// which collapsed "no connectivity", "HTTP 500", "malformed JSON" and "session
// expired" into one indistinguishable value that the UI could not act on.
//
// Result is `sealed`, so a `switch` over it must handle both branches or the
// code does not compile:
//
//   switch (result) {
//     Ok(:final value)    => render(value),
//     Err(:final failure) => showError(failure.userMessage),
//   }
//
// Do NOT add a `default:` branch to such a switch — it defeats exhaustiveness
// checking and reintroduces the silent-fallthrough problem this type exists to
// prevent.

import 'package:flutter/foundation.dart';

import '../error/failure.dart';

/// The outcome of an operation that can fail: either an [Ok] carrying a value
/// of type [T], or an [Err] carrying a [Failure].
@immutable
sealed class Result<T> {
  const Result();

  /// Wraps a successful value.
  const factory Result.ok(T value) = Ok<T>;

  /// Wraps a failure.
  const factory Result.err(Failure failure) = Err<T>;

  /// Whether this is an [Ok].
  bool get isOk => this is Ok<T>;

  /// Whether this is an [Err].
  bool get isErr => this is Err<T>;

  /// The value if this is an [Ok], otherwise `null`.
  ///
  /// Provided for interop with existing nullable call sites during the
  /// migration. Prefer pattern matching — this getter discards the failure,
  /// which is precisely the information the old code was missing.
  T? get valueOrNull => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>() => null,
      };

  /// The failure if this is an [Err], otherwise `null`.
  Failure? get failureOrNull => switch (this) {
        Ok<T>() => null,
        Err<T>(:final failure) => failure,
      };

  /// Collapses both branches into a single value of type [R].
  ///
  /// Both handlers are required, so no case can be forgotten.
  R fold<R>(R Function(T value) onOk, R Function(Failure failure) onErr) =>
      switch (this) {
        Ok<T>(:final value) => onOk(value),
        Err<T>(:final failure) => onErr(failure),
      };

  /// Transforms the success value, leaving a failure untouched.
  Result<R> map<R>(R Function(T value) transform) => switch (this) {
        Ok<T>(:final value) => Ok<R>(transform(value)),
        Err<T>(:final failure) => Err<R>(failure),
      };

  /// Chains another fallible operation, leaving a failure untouched.
  ///
  /// Use when the next step can itself fail — this avoids nesting
  /// `Result<Result<R>>`.
  Result<R> flatMap<R>(Result<R> Function(T value) transform) =>
      switch (this) {
        Ok<T>(:final value) => transform(value),
        Err<T>(:final failure) => Err<R>(failure),
      };

  /// Transforms the failure, leaving a success untouched.
  ///
  /// Useful at a layer boundary that needs to re-describe an error in its own
  /// vocabulary.
  Result<T> mapErr(Failure Function(Failure failure) transform) =>
      switch (this) {
        Ok<T>() => this,
        Err<T>(:final failure) => Err<T>(transform(failure)),
      };

  /// The success value, or the result of [orElse] when this is an [Err].
  T getOrElse(T Function(Failure failure) orElse) => switch (this) {
        Ok<T>(:final value) => value,
        Err<T>(:final failure) => orElse(failure),
      };

  /// Runs [onOk] for its side effect when this is an [Ok]. Returns `this` so
  /// calls can be chained.
  Result<T> onSuccess(void Function(T value) onOk) {
    if (this case Ok<T>(:final value)) {
      onOk(value);
    }
    return this;
  }

  /// Runs [onErr] for its side effect when this is an [Err]. Returns `this` so
  /// calls can be chained. Handy for logging without altering control flow.
  Result<T> onFailure(void Function(Failure failure) onErr) {
    if (this case Err<T>(:final failure)) {
      onErr(failure);
    }
    return this;
  }
}

/// A successful [Result] carrying a [value].
final class Ok<T> extends Result<T> {
  /// The value produced by the operation.
  final T value;

  const Ok(this.value);

  @override
  String toString() => 'Ok($value)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Ok<T> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok<T>, value);
}

/// A failed [Result] carrying a [failure].
final class Err<T> extends Result<T> {
  /// The reason the operation did not succeed.
  final Failure failure;

  const Err(this.failure);

  @override
  String toString() => 'Err($failure)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Err<T> && other.failure == failure;

  @override
  int get hashCode => Object.hash(Err<T>, failure);
}

/// Async combinators for `Future<Result<T>>`, so a chain of awaited fallible
/// steps reads without intermediate unwrapping.
extension FutureResultX<T> on Future<Result<T>> {
  /// Awaits, then applies [Result.map].
  Future<Result<R>> mapAsync<R>(R Function(T value) transform) async =>
      (await this).map(transform);

  /// Awaits, then chains another asynchronous fallible operation.
  Future<Result<R>> flatMapAsync<R>(
    Future<Result<R>> Function(T value) transform,
  ) async {
    final result = await this;
    return switch (result) {
      Ok<T>(:final value) => await transform(value),
      Err<T>(:final failure) => Err<R>(failure),
    };
  }

  /// Awaits, then applies [Result.fold].
  Future<R> foldAsync<R>(
    R Function(T value) onOk,
    R Function(Failure failure) onErr,
  ) async =>
      (await this).fold(onOk, onErr);
}
