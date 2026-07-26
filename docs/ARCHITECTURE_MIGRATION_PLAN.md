# Clean Architecture Migration Plan

**Target:** full migration of `universal_mobile_app` (63,573 lines / 210 Dart files) to a strict
4-layer Clean Architecture with enforced OOP contracts.

**Method:** Strangler Fig. The new layers are built alongside the old code. Each phase leaves the
app **compiling, running and shippable**. No phase requires a big-bang cutover.

---

## Current state (measured, not assumed)

| Layer | Files | Lines | Status |
|---|---:|---:|---|
| `presentation/` | 105 | 44,433 | Screens hold business logic; 25 files import `data/services` directly |
| `data/` | 56 | 10,313 | Repositories do HTTP + caching + scheduling in one class |
| `core/` | 31 | 4,818 | `api_client` exists but is bypassed by 28 files using raw `package:http` |
| `domain/` | **0** | **0** | Three `.gitkeep` files. The layer does not exist. |

**Structural defects to be fixed by this migration:**

1. No domain layer — no entities, no repository interfaces, no use cases.
2. No datasource layer — repositories mix remote I/O, cache I/O and business rules.
3. Errors collapse to `null`. `getProductByCode` returns `null` for network failure, HTTP 500,
   malformed JSON and expired auth alike. The UI cannot distinguish them.
4. DI is scattered across 26 files, including 12 **screens and widgets**.
   `productRepositoryProvider` is declared in `subcategory_providers.dart`.
   `orderRepositoryProvider` is declared **twice** (`order_history_provider.dart`,
   `reorder_provider.dart`) with different types.
5. Inverted dependency: `data/repositories/base_repository.dart` imports
   `presentation/providers/launch_flow_provider.dart`.
6. Competing implementations: 3 cart validators, 4 notification services, 2 popular-category
   providers.
7. `json_serializable` + `build_runner` are declared but unused (0 annotations, 0 `.g.dart`);
   all 23 models hand-roll `fromJson`.

---

## Target structure

```
lib/
├── core/                        # framework-agnostic, zero feature knowledge
│   ├── error/failure.dart       # sealed Failure hierarchy
│   ├── error/exceptions.dart    # thrown only inside data/, never escapes
│   ├── result/result.dart       # sealed Result<T> = Ok<T> | Err<T>
│   ├── usecase/usecase.dart     # abstract UseCase<Type, Params>
│   └── network/                 # ApiClient, NetworkInfo
│
├── di/                          # COMPOSITION ROOT — all provider wiring.
│                                #   May import every layer; the one exception
│                                #   to the dependency rule.
│
├── domain/                      # pure Dart. No Flutter, no JSON, no http.
│   ├── entities/                # immutable, final fields, value equality
│   ├── repositories/            # abstract interfaces ONLY
│   └── usecases/                # one class, one operation, one call()
│
├── data/                        # implements domain contracts
│   ├── datasources/
│   │   ├── remote/              # HTTP only. Throws typed exceptions.
│   │   └── local/               # cache/prefs/secure-storage only.
│   ├── models/                  # DTOs. fromJson/toJson + toEntity()/fromEntity()
│   └── repositories/            # *_repository_impl.dart — orchestrates datasources,
│                                #   catches exceptions, returns Result<T>
└── presentation/
    └── features/<feature>/
        ├── screens/             # widgets only
        ├── widgets/
        └── controllers/         # StateNotifier — depends ONLY on use cases
```

### Dependency rule (enforced in Phase 9)

```
presentation ──▶ domain ◀── data
                   ▲
                 core

        di/  ──▶ sees all of the above
```

`domain` imports nothing but `core`. `data` and `presentation` never import each other.
`di/` is the composition root and is the single exception — it may import every layer.

**Correction to the original plan:** DI was first placed at `core/di/`. That is
self-contradictory, since a DI module must import every repository and service while `core/`
is defined as having zero feature knowledge. The composition root is therefore `lib/di/`, a
sibling of the four layers.

---

## OOP contracts — non-negotiable

These are checked at review time in every phase.

| Rule | Meaning |
|---|---|
| **Abstraction** | Every repository has an `abstract interface class` in `domain/repositories/`. Concrete classes live only in `data/`. Nothing depends on a concrete class. |
| **Encapsulation** | All fields private (`_field`). No public mutable collections — expose `UnmodifiableListView` or copies. No public setters on entities. |
| **Immutability** | Entities and DTOs are `final class` with `const` constructors, `final` fields, and `copyWith`. No mutation after construction. |
| **Constructor injection** | No singletons, no service locators, no static mutable state. Dependencies arrive via constructor and are declared in `lib/di/`. |
| **Composition over inheritance** | `BaseRepository` (currently a 10-method grab-bag inherited for convenience) is dissolved. Shared behaviour becomes injected collaborators. |
| **Single responsibility** | A class does one thing. `ProductRepository` currently does HTTP + caching + image prefetch + cache scheduling → splits into 4 collaborators. |
| **Liskov** | Any `IProductRepository` implementation is substitutable. No impl-specific methods called through the interface. |
| **Interface segregation** | No fat interfaces. A consumer needing 1 method does not depend on a 10-method contract. |
| **Exhaustive errors** | `sealed` types force the compiler to reject unhandled cases. No `default:` branches on sealed switches. |

---

## Phase 0 — Foundation

**Goal:** core primitives every later phase depends on. **Zero behaviour change.**

### DECIDED: error model — sealed `Result<T>` + `Failure`

Chosen over `fpdart`'s `Either` (avoids a new dependency) and over typed exceptions (nothing
would force a caller to handle failures — the current null-swallowing bug could recur).

The compiler enforces exhaustive handling at every call site:

```dart
sealed class Result<T> { const Result(); }
final class Ok<T>  extends Result<T> { final T value;         const Ok(this.value); }
final class Err<T> extends Result<T> { final Failure failure; const Err(this.failure); }

sealed class Failure { final String message; const Failure(this.message); }
final class NetworkFailure    extends Failure { ... }
final class ServerFailure     extends Failure { ... }
final class CacheFailure      extends Failure { ... }
final class AuthFailure       extends Failure { ... }
final class ValidationFailure extends Failure { ... }
final class UnknownFailure    extends Failure { ... }

// call site — compiler rejects a missing branch
switch (result) {
  Ok(:final value)    => render(value),
  Err(:final failure) => showError(failure),
}
```

This is what replaces `return null` in `getProductByCode` and everywhere like it. No `default:`
branch is permitted on a sealed switch — that would defeat exhaustiveness checking.

### Files created

- `core/error/failure.dart` — the sealed `Failure` hierarchy above
- `core/error/exceptions.dart` — `ServerException`, `CacheException`, `AuthException`.
  Thrown **inside `data/` only**, converted to `Failure` at the repository boundary.
  An exception must never escape the data layer.
- `core/result/result.dart` — `sealed class Result<T>` with `Ok<T>` / `Err<T>`
- `core/usecase/usecase.dart` — `abstract class UseCase<Type, Params>` with
  `Future<Result<Type>> call(Params params)`, plus `NoParams`
- `core/usecase/stream_usecase.dart`

**Touches no existing file.** Nothing can regress.

**Exit criteria**
- `flutter analyze lib` reports no new issues
- Unit tests for `Result` and `Failure` exhaustiveness pass
- `ARCHITECTURE.md` committed with the rules above

---

## Phase 1 — DI consolidation & layer-violation repair

**Goal:** one place declares dependencies; illegal imports removed. Still no feature rewrites.

1. Create `lib/di/` and move the scattered DI `Provider` declarations into it, grouped by kind
   (`infrastructure_providers.dart`, `repository_providers.dart`, `service_providers.dart`).
   Presentation *state* providers stay with their feature — only dependency wiring moves.
2. Resolve the duplicate `orderRepositoryProvider` (two declarations, two types).
3. Remove the 12 provider declarations living inside screens/widgets
   (`promotional_banner_widget.dart`, `search_screen.dart`, `my_profile_screen.dart`, …).
4. Delete the `data → presentation` import in `base_repository.dart`.
5. Move `lib/api_postman/` → `docs/api/`. Delete the tracked `~/.ssh/config` directory.

**Risk:** low — mechanical moves, compiler-verified.

**Exit criteria**
- No DI-shaped provider (`*RepositoryProvider`, `*ServiceProvider`, `*ClientProvider`,
  `*ManagerProvider`) is declared outside `lib/di/`, and no name is declared twice
- No file in `data/` imports `presentation/`
- App builds and boots on device

---

## Phase 2 — Reference vertical slice: **Product**

**Goal:** one feature migrated end-to-end. This becomes the template every later phase copies.

Product is chosen because it is self-contained (3 repository methods) yet exercises every concern:
remote fetch, local cache, cache expiry scheduling, image prefetch, error handling.

```
domain/entities/product.dart                     Product (pure, immutable)
domain/repositories/i_product_repository.dart    abstract interface
domain/usecases/product/get_products.dart        UseCase<List<Product>, GetProductsParams>
domain/usecases/product/get_product_by_code.dart
data/datasources/remote/product_remote_datasource.dart   HTTP only
data/datasources/local/product_local_datasource.dart     cache only
data/models/product_model.dart                   + toEntity() / fromEntity()
data/repositories/product_repository_impl.dart   implements IProductRepository
presentation/.../controllers/product_controller.dart
```

The existing 227-line `ProductRepository` splits into: remote datasource, local datasource,
image-prefetch collaborator, cache-policy collaborator.

**Exit criteria**
- Product screens read only from use cases — no `data/` import anywhere in `features/product/`
- Every failure path returns a typed `Failure`, not `null`
- Unit tests: use cases with mocked repository; repository with mocked datasources
- Reviewed and signed off as the pattern before Phase 3 starts

---

## Phase 3 — Shared kernel (highest fan-in)

**This is the hard phase.** These providers are depended on by nearly every feature, so they must
be clean before dependants migrate. Split into three independently shippable sub-phases.

### 3a — Auth & token (fan-in 10/19)
`auth_repository` (5 methods), `auth_service` (9), `CentralizedAuthManager`.
Introduce `IAuthRepository`, `ITokenStore`. Token storage becomes an injected collaborator
instead of a manager reached through static access.

### 3b — Location, pincode & outlet (fan-in 12/19)
`outlet_repository`, `location_repository` (7 methods), `location_service`, `google_maps_service`,
`geocoding`. Consolidate `outlet_status_provider` into the outlet domain.

### 3c — Launch flow decomposition (fan-in **19/19**)
`launch_flow_provider` (321 lines) is imported by every single feature and additionally declares
`apiServiceProvider`, `locationServiceProvider`, `storageServiceProvider`. It is a god object.

Decompose into: `AppBootstrapUseCase`, `SessionUseCase`, `OnboardingStateUseCase` — and move the
three service declarations to `lib/di/`.

**Risk:** high. 3c touches every feature's imports. Do it in its own PR, on its own, with a full
regression pass.

**Exit criteria per sub-phase**
- Interfaces in `domain/`, impls in `data/`, no direct service access from `presentation/`
- Existing behaviour verified by manual QA script (login, OTP, logout, token expiry, pincode
  change, outlet switch, cold start, warm start)

---

## Phase 4 — Catalog (read-mostly, low risk)

`category` (2 methods), `subcategory` (1), `best_seller` (2), `popular_category` (2),
`search`, `seasonal_picks`, `steal_deals`.

Also collapses the duplicate `popular_category_providers` / `popular_category_section_providers`
into one domain.

Chosen after the kernel because these are read-only paths — a regression is visible immediately
and costs no money. Good place to build team fluency with the pattern.

**Exit criteria**: no `features/{category,subcategory,search,best_seller}/**` file imports `data/`.

---

## Phase 5 — Cart (fan-in 11/19)

The most complex non-payment domain. Currently spread across:
- `cart_provider.dart` (900 lines)
- `cart_validator.dart` (11 methods) + `cart_validator_provider.dart` (570 lines) +
  `enhanced_cart_validator_provider.dart` (340 lines) — **three competing validators**
- `cart_storage_service.dart`, `cart_session_manager.dart` (10 methods)

Work: define one `CartValidationPolicy` in `domain/`, delete the other two implementations,
model cart state as a sealed union, move persistence behind `ICartRepository`.

**Exit criteria**
- Exactly one validation implementation remains
- Validation rules (stock, serviceability, min order value) are unit-testable without HTTP
- Cart survives app kill/restore; quantity edits, removals and merges verified

---

## Phase 6 — Orders & account

`order_repository` (4), `order_service`, `address_repository` (4), `profile_repository`,
`favorites_repository` (3), `reorder_provider` (232 lines), `order_history_provider`.

Fixes the duplicate `orderRepositoryProvider` properly (Phase 1 only de-duplicated the declaration).

**Exit criteria**: order history, order detail, reorder, address CRUD, profile edit, favourites
all run through use cases.

---

## Phase 7 — Checkout & payments (highest risk — last)

`checkout_flow_screen.dart` is **4,713 lines** containing `CheckoutData` and four step widgets
(`DeliveryMethodStep`, `DeliveryAddressStep`, `DeliveryTimeStep`, `PaymentStep` ~1,270 lines).
The feature imports **14 providers**.

1. Split the file into `checkout/screens/steps/*.dart` — mechanical, no logic change, own commit.
2. Model the flow as a sealed `CheckoutStep` state machine in `domain/`.
3. `payment_service`, `payment_method_service`, `order_payment_processing_service`,
   `webhook_payment_service`, `delivery_charges_service` (3), `delivery_slot_service` behind
   `IPaymentGateway` / `IDeliveryRepository`.
4. Razorpay stays behind the `IPaymentGateway` interface so it can be faked in tests.

**Risk: highest — this path takes money.** Full regression: COD, UPI, card, netbanking, wallet,
payment failure, payment cancellation, webhook reconciliation, slot unavailability, address change
mid-flow, session timeout.

**Exit criteria**: no step widget exceeds 400 lines; payment gateway mockable; end-to-end test on
Razorpay test keys before release.

---

## Phase 8 — Cross-cutting: notifications

Four competing services — `firebase_notification_service` (6 methods),
`advanced_notification_service` (9), `simple_notification_service` (0), `ios_notification_service`
(5) — collapse behind one `INotificationService` with platform strategies.

Also moves the FCM background handler and iOS permission logic out of `main.dart` (887 lines)
into `core/notifications/`, leaving `main.dart` as a thin entry point.

---

## Phase 9 — Enforcement & cleanup

Makes the architecture **impossible to violate silently**.

1. Add `custom_lint` + `import_lint` rules encoding the dependency rule. Illegal import = build
   failure, not a review comment.
2. Decide `json_serializable`: adopt it across all 23 models, or remove the three unused deps.
3. `dart fix --apply` — clears ~200 of the 668 lint issues mechanically.
4. Fix the 35 `use_build_context_synchronously` (21 in `location_change_screen.dart`).
5. Replace 292 `print()` calls with the injected `Logger`; ban `avoid_print` as an **error**.
6. Delete dead code surfaced by migration; remove `flutter_0*.log`.
7. Rewrite `CLAUDE.md` — it currently documents a domain layer, a codegen workflow, a base URL,
   a project code and a version that do not match the code.

**Exit criteria**: `flutter analyze` clean at zero issues; CI fails on layer violation.

---

## Sequencing rationale

```
Phase 0  Foundation          no dependencies
Phase 1  DI + violations     needs 0
Phase 2  Product slice       needs 0,1 — proves the pattern
Phase 3  Shared kernel       needs 2 — fan-in 10-19, unblocks everything
Phase 4  Catalog             needs 3 — low risk, builds fluency
Phase 5  Cart                needs 3,4
Phase 6  Orders & account    needs 3,5
Phase 7  Checkout            needs 3,5,6 — imports 14 providers, must be last
Phase 8  Notifications       needs 3 — parallelisable with 4-6
Phase 9  Enforcement         needs all
```

Phase 8 is the only one that can run in parallel with others.

---

## Ground rules for every phase

- One phase = one PR = one reviewable unit. Never mix a phase with a feature change.
- The app compiles, boots and is shippable at the end of every phase.
- Old code is deleted in the same phase that replaces it — no "enhanced_" / "simple_" duplicates
  left behind. That practice is what produced the current 3 validators and 4 notification services.
- Tests land with the phase, not after.
- No phase begins before the previous phase's exit criteria are signed off.
