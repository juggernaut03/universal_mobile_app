# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

**PatelMart** is a production e-commerce mobile application built with **Flutter** and **Dart** (SDK ^3.7.2). The app follows **Clean Architecture** with a feature-first organization pattern and uses **Riverpod** for state management. Current version: see `pubspec.yaml`

**Primary Technology Stack:**
- Flutter (iOS 14.0+, Android API 21+, Web, Desktop)
- Riverpod 2.6.1 (reactive state management)
- GoRouter 15.1.1 (navigation with deep linking)
- Firebase (push notifications, cloud services)
- Razorpay (payment processing)
- Google Maps integration

## Essential Commands

### Development Setup
```bash
flutter pub get                    # Install dependencies
flutter analyze                    # Run linter (flutter_lints)
flutter doctor                     # Check environment setup
flutter pub upgrade                # Update all dependencies
```

### Running the App
```bash
flutter run                        # Run on connected device/emulator
flutter run -d <device_id>         # Run on specific device
flutter run --release              # Run in release mode
flutter run --profile              # Run in profile mode (performance)
flutter clean && flutter pub get   # Clean rebuild
```

### Building
```bash
flutter build apk                  # Build Android APK
flutter build appbundle            # Build Android App Bundle (Play Store)
flutter build ios                  # Build iOS app
flutter build ios --release        # Build iOS release
flutter build web                  # Build for web
```

### Code Generation

None. `json_serializable`, `json_annotation` and `build_runner` were declared in
`pubspec.yaml` but never used — zero `@JsonSerializable` annotations and zero
`.g.dart` files — and were removed. All models hand-roll `fromJson`.

### Testing
```bash
flutter test                       # Run all tests
flutter test test/widget_test.dart # Run specific test file
flutter test --coverage            # Run tests with coverage report
```

## Architecture Overview

**Read `docs/ARCHITECTURE.md` first — it is the authority.** This file is a
quick orientation; that one states the rules.

The codebase is mid-migration to Clean Architecture (`docs/ARCHITECTURE_MIGRATION_PLAN.md`).
Phases 0-9 are done: `core/error`, `core/result`, `core/usecase`, a `lib/di/`
composition root, and a real `lib/domain/` layer (47 files) covering product,
auth, outlet/location, catalogue, cart, orders and checkout.

Older feature code still calls repositories directly. Both styles are present;
new code follows `docs/ARCHITECTURE.md`.

Run `dart run tool/check_architecture.dart` — it fails on layer violations. It
currently reports 7 known ones, all tracked as migration follow-ups.

The layers:

### Layer 1: Core (`lib/core/`)
Shared utilities, configurations, and reusable components across the entire app.

**Key Components:**
- **api_client.dart** - The single HTTP choke point: injects `X-Project-Code`,
  attaches the Bearer JWT on `*WithAuth` calls, forces logout on a 401. Resolve
  it from `lib/di/` — constructing `ApiClient` without a `CentralizedAuthManager`
  yields a client that silently sends no auth header.
- **centralized_auth_manager.dart** - Single source of truth for authentication state and token management
- **app_theme.dart** - Material Design 3 theme with Poppins font family (9 weights)
- **app_colors.dart** & **app_text_styles.dart** - Design system constants
- **responsive_utils.dart** - Responsive design helpers for adaptive layouts
- **location_utils.dart** - Geolocation utilities
- **logger.dart** - Structured logging
- **Reusable Widgets:** cached_network_image_widget, quantity_input_widget, bottom_navigation_widget, favorite_button, empty_state_widget, search_widget, app_drawer_widget

**API Configuration:**
- Base URL, project code and Razorpay key are build-time values — see
  `lib/core/config/env_config.dart`. They are supplied with `--dart-define`;
  the defaults there are for development.
- Timeout: 15 seconds

### Layer 2: Data (`lib/data/`)
Data access, API communication, local storage, and service implementations.

**Models (17 files):**
Core domain models: `product_model`, `category_model`, `outlet_model`, `pincode_model`, `auth_models`, `address_model`, `order_model`, `delivery_slot_model`, `payment_method_model`, `popular_category_models`, `best_seller_models`, and others. All use `json_serializable` for code generation.

**Repositories (18 files):**
Abstract data access layer implementing repository pattern. Key repositories:
- `auth_repository` - User authentication
- `product_repository` - Product data access
- `category_repository` - Category management
- `cart_repository` - Shopping cart persistence
- `order_repository` - Order management
- `outlet_repository` - Store/outlet selection
- `address_repository` - User addresses
- `favorites_repository` - Wishlist management
- Base: `base_repository.dart` - Abstract base with common patterns

**Services (28 files):**
Business logic and external API integration:
- **api_service.dart** - Centralized API call orchestration
- **auth_service.dart** - User authentication logic
- **cart_storage_service.dart**, **cart_validator.dart**, **cart_session_manager.dart** - Shopping cart business logic
- **order_service.dart**, **order_payment_processing_service.dart** - Order processing
- **firebase_notification_service.dart**, **advanced_notification_service.dart** - Push notifications (FCM)
- **location_service.dart**, **google_maps_service.dart** - Geolocation
- **payment_service.dart**, **webhook_payment_service.dart** - Razorpay integration
- **delivery_charges_service.dart**, **delivery_slot_service.dart** - Delivery options

### Layer 3: Domain (`lib/domain/`)
Pure Dart — no Flutter, no http, no JSON. Entities, repository interfaces
(`IProductRepository`, `IAuthRepository`, `ICartRepository`, …) and use cases.

Every use case returns `Result<T>` (`core/result/result.dart`), a sealed
`Ok`/`Err` pair, so failures are values the compiler forces callers to handle.
This replaced the previous convention of returning `null` on error, which made
"offline", "HTTP 500", "not found" and "session expired" indistinguishable.

### Layer 4: Presentation (`lib/presentation/`)
User interface, screens, state management providers, and routing.

**Features (21 modules, 60+ screens):**
- **auth/** - OTP-based mobile login
- **home/** - Main feed with popular categories, seasonal picks, best sellers
- **product/** - Single product details with images, reviews, ratings
- **cart/** - Shopping cart with quantity adjustment and validation
- **checkout/** - Multi-step: address selection → delivery slot → payment method
- **orders/** - Order history and detailed order information
- **account/** - User profile and address management
- **favorites/** - Wishlist functionality
- **search/** - Product search with filters
- **category/** - Department and category browsing
- **location/** - Pincode and outlet selection
- Plus 10+ additional features (onboarding, splash, best_seller, store, support, etc.)

**State Management with Riverpod (35+ providers):**
All providers are in `lib/presentation/providers/` directory:

**Large, Critical Providers:**
- **cart_provider.dart** (720 lines) - Main shopping cart state with reactive updates
- **cart_validator_provider.dart** (570 lines) - Server-side cart validation logic
- **enhanced_cart_validator_provider.dart** (340 lines) - Advanced validation
- **favorites_provider.dart** (416 lines) - Wishlist state management
- **auth_providers.dart** (302 lines) - Authentication state and token management
- **launch_flow_provider.dart** (321 lines) - App initialization and onboarding flow
- **home_refresh_provider.dart** (193 lines) - Home screen pull-to-refresh logic
- **reorder_provider.dart** (232 lines) - Reorder from previous orders
- **location_provider.dart** (194 lines) - Geolocation state
- **delivery_charges_provider.dart** (204 lines) - Delivery cost calculations
- **popup_providers.dart** (196 lines) - Modal/popup management

**Provider Patterns Used:**
- `StateNotifierProvider` - Mutable state
- `FutureProvider` - Async data fetching with caching
- `Provider` - Computed/derived state
- `watchFamily` - Parameterized providers
- Automatic dependency resolution and smart invalidation

**Key Routing Setup:**
- GoRouter in `lib/presentation/routes/`
- Declarative route definitions with deep linking support
- Redirect guards based on auth state and launch flow
- Global navigator key for background navigation

## Important Development Patterns

### Caching Strategy
- **Product Data**: Cached for 20 hours with automatic invalidation
- **Product Images**: Cached via flutter_cache_manager with CDN integration
- **Daily Reset**: Automatic cache clearing at 2 AM via scheduled task
- **User Tokens**: Secure storage with flutter_secure_storage (10-day expiry)
- **Session Data**: SharedPreferences for temporary state

### Authentication Flow
1. User enters mobile number → SMS OTP sent
2. OTP validation → JWT token generated
3. Token stored securely with 10-day expiry
4. Centralized auth manager validates token on app launch
5. Auto-refresh and logout on expiry

### Cart Architecture
The cart is the most complex feature with extensive validation:
- **Local State**: Riverpod provider tracks cart items
- **Server Validation**: `cart_validator_service.dart` validates cart server-side before checkout
- **Session Management**: `cart_session_manager.dart` handles cart lifecycle
- **Reactive Updates**: Automatic UI updates on cart changes
- **Validation Rules**: Stock availability, pincode serviceability, minimum order value

### Location-Based Features
- **Pincode Selection**: Primary way to set delivery location
- **Outlet Switching**: Multiple stores per pincode
- **GPS Integration**: Geolocator for auto-location detection
- **Address Management**: Full CRUD for user addresses

### Payment Processing
- **Razorpay Integration**: Primary payment gateway
- **Multiple Methods**: Cards, UPI, NetBanking, Wallets
- **Webhook Handling**: Server-side payment confirmation
- **Order Payment Service**: Real-time payment validation

### Notification System
- **Firebase Cloud Messaging (FCM)**: Push notification backbone
- **Platform-Specific**: APNS tokens for iOS, FCM for Android
- **Background Handling**: Top-level handler for background messages
- **Local Notifications**: flutter_local_notifications for foreground alerts
- **Custom Data Handling**: Advanced notification service for rich notifications

### Facebook Analytics Integration
- **Conversion Tracking**: Track purchases, cart additions, views
- **Event Tracking**: Login, signup, search, custom events
- **E-commerce Analytics**: Product views, order completions

## Code Quality and Standards

**Linting:**
- Framework: flutter_lints (enforces Dart best practices)
- Disabled Rules: deprecated_member_use, depend_on_referenced_packages
- Code Style: 2-space indentation, snake_case files, PascalCase classes
- Documentation: Add comments for complex logic and non-obvious patterns

**Naming Conventions:**
- Files: snake_case (e.g., `cart_provider.dart`)
- Classes: PascalCase (e.g., `CartNotifier`)
- Variables: camelCase (e.g., `productList`)
- Constants: UPPER_SNAKE_CASE (e.g., `API_TIMEOUT`)

**Best Practices:**
- Use `const` constructors for widgets whenever possible
- Leverage Riverpod's automatic caching instead of manual management
- Handle loading and error states explicitly in async providers
- Implement proper error handling with user-friendly messages
- Use sealed classes for union types when modeling error states
- Optimize rebuilds with `Consumer` widget and specific provider watches

## Git Workflow

**Current Branch:** main

**Recent Commits Show Active Development:**
- Seasonal category refresh integration
- Popular category refresh implementation
- Category title standardization
- Order checkout improvements
- Firebase and notification enhancements

**Staging Areas:**
- iOS: AppFrameworkInfo.plist, Podfile, Podfile.lock, project.pbxproj (currently modified)

## Firebase Configuration

**Firebase Project:** patelrmartnotifications

**Keys:**
- Android App ID: `1:65652715036:android:12118f78c4d70d859cb9d9`
- iOS App ID: `1:65652715036:ios:3e9aa50a18bd787e9cb9d9`

**Configuration Files:**
- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- Dart: `lib/firebase_options.dart`

**Usage:** Push notifications, cloud messaging, analytics

## Important Files and Locations

**Entry Points:**
- `lib/main.dart` - Application entry point
- `lib/app.dart` - Main app widget with theme and routing setup

**Core Configuration:**
- `lib/core/config/app_config.dart` - App settings
- `lib/core/config/app_theme.dart` - Material Design theme
- `lib/core/constants/app_colors.dart` - Color palette
- `lib/presentation/routes/app_routes.dart` - GoRouter configuration

**Critical Business Logic:**
- `lib/data/services/cart_validator.dart` - Cart validation rules
- `lib/data/services/delivery_charges_service.dart` - Delivery cost calculation
- `lib/data/services/api_service.dart` - API call orchestration
- `lib/presentation/providers/cart_provider.dart` - Cart state (720 lines)

**UI Components:**
- `lib/core/widgets/` - Reusable widgets across features
- `lib/presentation/features/*/widgets/` - Feature-specific widgets

## Testing Notes

**Current Test Coverage:**
- 252 tests, all under `test/core`, `test/domain`, `test/data`
- Domain rules (cart validation, order status, checkout flow, pincode
  serviceability, session expiry) are covered and run without a device
- `test/widget_test.dart` and `test/timer_test.dart` are stale and do not compile

**Areas Needing Tests:**
- Widget and integration tests — there are none
- The payment path end-to-end against Razorpay test keys

## Common Development Tasks

### Adding a New Feature
1. Create feature folder in `lib/presentation/features/`
2. Implement screens/widgets for UI
3. Create Riverpod providers in `lib/presentation/providers/` if state needed
4. Add data models in `lib/data/models/` if API involved
5. Implement repository in `lib/data/repositories/` for data access
6. Add routes in `lib/presentation/routes/`
7. Import and register the route in app router config

### Adding API Integration
1. Create data model in `lib/data/models/` using `@JsonSerializable()`
2. Implement API calls in `lib/data/services/api_service.dart`
3. Create repository in `lib/data/repositories/` with repository interface
4. Create provider in `lib/presentation/providers/` for UI consumption
5. Write `fromJson`/`toJson` by hand, plus a `toEntity()` mapping to the domain entity

### Handling Complex State
1. Use `StateNotifierProvider` for mutable state
2. Create notifier class extending `StateNotifier`
3. Leverage Riverpod's dependency injection for services
4. Use family modifiers for parameterized state
5. Watch multiple providers in UI if needed

### Debugging
- Check `CentralizedAuthManager` for auth state issues
- Verify API responses in network logs
- Use `logger.dart` utility for structured logging
- Check Firebase console for notification issues
- Use browser DevTools for web version debugging

## Performance Considerations

**Optimization Techniques:**
- Widget const constructors minimize rebuilds
- Riverpod caching reduces redundant data fetches
- ListView.builder for efficient list rendering
- Image caching with flutter_cache_manager
- Lazy loading for product lists
- Code splitting supported on web

**Monitor:**
- Provider cache hit rates
- API response times
- Image load times
- Cart validation duration (critical path)
- Notification delivery delays

## Known Constraints

- App is portrait orientation only
- Requires Firebase initialization before launch
- iOS requires APNS token configuration for notifications
- Network calls timeout after 15 seconds
- Product cache invalidates every 20 hours
- User tokens expire after 10 days (auto-logout)
- Cart validation must succeed before checkout allowed
