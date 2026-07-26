// lib/core/usecase/usecase.dart
//
// A use case is one business operation, expressed as one class with one public
// method. It is the ONLY thing the presentation layer is allowed to call.
//
//   presentation --> UseCase --> IRepository (domain interface)
//                                     ^
//                              implemented in data/
//
// Rules:
//   * One use case, one operation. If a class needs a second public method,
//     it is two use cases.
//   * Use cases depend on domain interfaces only — never on a concrete
//     repository, a datasource, an http client, or anything from Flutter.
//   * Dependencies arrive through the constructor. No singletons, no locators.
//   * Every use case returns Result<T>; failures are values, not exceptions.

import 'package:flutter/foundation.dart';

import '../result/result.dart';

/// An asynchronous business operation taking [P] parameters and producing [T].
///
/// Invoked through `call`, so instances are used as functions:
///
/// ```dart
/// final result = await getProducts(GetProductsParams(storeCode: 'KLK'));
/// ```
abstract class UseCase<T, P> {
  const UseCase();

  /// Executes the operation.
  Future<Result<T>> call(P params);
}

/// A business operation that completes synchronously.
///
/// Use for pure computation over already-loaded state — cart totals, delivery
/// charge calculation, eligibility rules. Anything touching I/O is a [UseCase].
abstract class SyncUseCase<T, P> {
  const SyncUseCase();

  /// Executes the operation.
  Result<T> call(P params);
}

/// A business operation exposing a continuous stream of values, such as auth
/// state or cart contents.
///
/// Each emission is a [Result], so a mid-stream failure does not terminate the
/// subscription.
abstract class StreamUseCase<T, P> {
  const StreamUseCase();

  /// Opens the stream.
  Stream<Result<T>> call(P params);
}

/// Parameter object for use cases that take no input.
///
/// A dedicated type rather than `void` keeps the generic signature uniform and
/// keeps every use case callable the same way.
@immutable
final class NoParams {
  const NoParams();

  @override
  bool operator ==(Object other) => other is NoParams;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'NoParams()';
}

/// Base class for use case parameter objects.
///
/// Params are passed to Riverpod `family` providers, which key their cache by
/// argument equality — so params MUST implement `==` and `hashCode` or every
/// rebuild allocates a fresh provider and the cache never hits. Extending this
/// class documents that obligation; it does not fulfil it.
///
/// ```dart
/// final class GetProductsParams extends UseCaseParams {
///   final String storeCode;
///   const GetProductsParams({required this.storeCode});
///
///   @override
///   List<Object?> get props => [storeCode];
/// }
/// ```
@immutable
abstract class UseCaseParams {
  const UseCaseParams();

  /// The fields that define this object's identity.
  List<Object?> get props;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UseCaseParams &&
          other.runtimeType == runtimeType &&
          listEquals(other.props, props);

  @override
  int get hashCode => Object.hashAll([runtimeType, ...props]);

  @override
  String toString() => '$runtimeType(${props.join(', ')})';
}
