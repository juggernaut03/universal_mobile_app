# Architecture

The rules for writing code in this app. These are enforced at review time, and from Phase 9
onward by lint rules that fail the build.

> Migration status: **Phases 0-9 complete.** Foundation primitives, the `lib/di/`
> composition root, and a `lib/domain/` layer of 47 files covering product, auth,
> outlet/location, catalogue, cart, orders and checkout. 252 tests.
>
> Older feature code still calls repositories directly — both styles are present.
> New and migrated code follows this document.
>
> **Enforcement:** `dart run tool/check_architecture.dart` fails the build on a
> layer violation. It reports 7 known ones today, each tracked as a migration
> follow-up in ARCHITECTURE_MIGRATION_PLAN.md. Do not add to them.
> Sequence and remaining phases: [ARCHITECTURE_MIGRATION_PLAN.md](./ARCHITECTURE_MIGRATION_PLAN.md).
> Code written before Phase 0 does not yet follow these rules — new and migrated code must.

---

## The dependency rule

```
presentation ──▶ domain ◀── data
                   ▲
                 core

        di/  ──▶ sees all of the above
```

- **`domain/`** imports nothing but `core/`. No Flutter, no `http`, no `shared_preferences`,
  no JSON. It is pure Dart and must be unit-testable with no mocks of framework types.
- **`data/`** implements the interfaces declared in `domain/`. It never imports `presentation/`.
- **`presentation/`** calls use cases only. It never imports `data/`.
- **`core/`** is framework-level plumbing with zero feature knowledge.
- **`di/`** is the composition root — the single exception, permitted to import every layer,
  because constructing the object graph requires seeing all of it.

If a change needs an import that violates this, the design is wrong — not the rule.

### Why `lib/di/` and not `lib/core/di/`

The plan originally placed DI under `core/`. That is self-contradictory: a DI module must import
every repository and service, while `core/` is defined as having zero feature knowledge. The
composition root therefore sits at top level, as a sibling of the four layers, and is the only
place allowed to see all of them.

---

## Layers

### `core/`
Cross-cutting primitives. No feature knowledge.

| Path | Purpose |
|---|---|
| `core/error/failure.dart` | `sealed Failure` — the vocabulary of failure |
| `core/error/exceptions.dart` | `sealed AppException` — data layer's internal error channel |
| `core/error/failure_mapper.dart` | `guard()` / `mapErrorToFailure()` — the boundary translator |
| `core/result/result.dart` | `sealed Result<T>` = `Ok<T>` \| `Err<T>` |
| `core/usecase/usecase.dart` | `UseCase`, `SyncUseCase`, `StreamUseCase`, `NoParams`, `UseCaseParams` |
| `core/network/` | `ApiClient`, `NetworkInfo` |

### `di/` — the composition root

| Path | Purpose |
|---|---|
| `di/infrastructure_providers.dart` | logger, prefs, secure storage, http, FCM, cache, `ApiClient` |
| `di/repository_providers.dart` | repository wiring |
| `di/service_providers.dart` | service wiring |

### `domain/`
The business model. Pure Dart.

- `entities/` — immutable value objects. `final class`, `const` constructor, `final` fields,
  `copyWith`, value equality. **No `fromJson`/`toJson`** — serialisation is a data-layer concern.
- `repositories/` — `abstract interface class` only. Declares *what*, never *how*.
- `usecases/` — one class, one operation, one `call()`.

### `data/`
Implements the domain contracts.

- `datasources/remote/` — HTTP only. Throws `AppException`. Knows nothing about caching.
- `datasources/local/` — cache, prefs, secure storage only. Throws `CacheException`.
- `models/` — DTOs. Own `fromJson`/`toJson` **and** `toEntity()`/`fromEntity()`.
  A DTO never leaves the data layer; only entities cross the boundary.
- `repositories/` — `*_repository_impl.dart`. Orchestrates datasources, applies cache policy,
  converts exceptions to failures, returns `Result<T>`.

### `presentation/`
UI and UI state.

- `features/<name>/screens/` — widgets only.
- `features/<name>/widgets/` — feature-local components.
- `features/<name>/controllers/` — `StateNotifier`. Depends on **use cases only**.

---

## Error handling

Two channels, one translation point.

```
datasource ──throws AppException──▶ repository impl ──returns Err(Failure)──▶ domain ──▶ UI
                                          │
                                    guard() translates here
```

**An `AppException` must never escape `data/`.** If one reaches a use case or a widget, a
repository is missing its `guard()` — that is a bug, not a style issue.

### Writing a repository method

```dart
@override
Future<Result<Product>> getProductByCode(String code) =>
    guard(() async => (await _remote.fetchProduct(code)).toEntity());
```

`guard` catches everything and maps it via `mapErrorToFailure`, so no method needs its own
try/catch.

### Consuming a Result

```dart
switch (result) {
  Ok(:final value)    => _render(value),
  Err(:final failure) => _showError(failure),
}
```

**Never add `default:` to a switch over a sealed type.** It defeats exhaustiveness checking,
which is the entire reason these types are sealed. Adding a new `Failure` subtype should break
compilation at every site that needs updating — that is the feature.

### Displaying an error

- `failure.message` is **developer-facing**. Log it. Never render it — it may contain endpoint
  names or payload fragments.
- `failure.userMessage` is **user-facing**. Render this.
- `failure.isRetryable` decides whether to offer a "Retry" affordance. Do not re-derive that by
  inspecting the concrete type.

### What replaced `return null`

Returning `null` on error collapsed "offline", "HTTP 500", "malformed JSON" and "session expired"
into one value the UI could not act on. `Result` keeps them distinguishable. `valueOrNull` exists
for interop during migration only — reaching for it discards the failure and reintroduces the
original bug.

---

## OOP contracts

| Rule | What it means in practice |
|---|---|
| **Abstraction** | Every repository has an `abstract interface class` in `domain/repositories/`. Nothing depends on a concrete class. |
| **Encapsulation** | Fields are private (`_field`). No public mutable collections — expose `UnmodifiableListView` or a copy. Entities have no setters. |
| **Immutability** | Entities and DTOs are `final class` with `const` constructors and `final` fields. Change means `copyWith`, not mutation. |
| **Constructor injection** | Dependencies arrive via the constructor. No singletons, no service locators, no static mutable state. Wiring lives in `lib/di/`. |
| **Composition over inheritance** | Share behaviour by injecting a collaborator, not by extending a base class for convenience. |
| **Single responsibility** | One class, one reason to change. A class doing HTTP *and* caching *and* scheduling is three classes. |
| **Liskov substitution** | Any implementation of an interface is substitutable. Never call impl-specific methods through an interface. |
| **Interface segregation** | No fat interfaces. A consumer needing one method must not depend on a ten-method contract. |
| **Exhaustive errors** | `sealed` types + no `default:` branches. The compiler finds unhandled cases, not production. |

---

## Writing a use case

```dart
final class GetProductsParams extends UseCaseParams {
  final String storeCode;
  final String departmentId;

  const GetProductsParams({required this.storeCode, required this.departmentId});

  @override
  List<Object?> get props => [storeCode, departmentId];
}

final class GetProducts extends UseCase<List<Product>, GetProductsParams> {
  final IProductRepository _repository;

  const GetProducts(this._repository);

  @override
  Future<Result<List<Product>>> call(GetProductsParams params) =>
      _repository.getProducts(
        storeCode: params.storeCode,
        departmentId: params.departmentId,
      );
}
```

**Params must implement `==` and `hashCode`.** Riverpod `family` providers key their cache by
argument equality — without it, every rebuild allocates a new provider and the cache never hits.
Extending `UseCaseParams` and overriding `props` handles this.

A use case needing a second public method is two use cases.

---

## Testing

| Layer | Test with |
|---|---|
| `domain/usecases/` | Mocked repository interface. No HTTP, no Flutter. |
| `data/repositories/` | Mocked datasources. Assert exception → `Failure` translation. |
| `data/datasources/` | Mocked `http.Client`. Assert typed exceptions are thrown. |
| `presentation/controllers/` | Mocked use cases. Assert state transitions. |

Tests land in the same PR as the code, not afterwards.

---

## Conventions

- Files `snake_case`, classes `PascalCase`, members `camelCase`.
- Interfaces are prefixed `I` (`IProductRepository`); implementations suffixed `Impl`
  (`ProductRepositoryImpl`).
- Use cases are named for the operation (`GetProducts`, `PlaceOrder`), not the noun.
- No `print()`. Use the injected `Logger`.
- **When code is replaced, delete what it replaced in the same PR.** The `enhanced_` / `simple_` /
  `advanced_` prefixes currently in this codebase are the result of ignoring this — it produced
  three cart validators and four notification services, all partially wired.
