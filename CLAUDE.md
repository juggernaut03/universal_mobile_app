# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

PatelMart is a comprehensive e-commerce Flutter application built with modern architecture patterns. The app follows clean architecture principles with centralized state management using Riverpod and declarative routing with GoRouter.

## Architecture

### Core Architecture Pattern
- **Clean Architecture**: Separation of concerns with proper layering
- **State Management**: Flutter Riverpod for reactive state management
- **Navigation**: GoRouter for declarative routing and deep linking
- **Network Layer**: Centralized API client with automatic error handling
- **Authentication**: Centralized access token management system

### Project Structure
```
lib/
├── core/                     # Core utilities and infrastructure
│   ├── auth/                 # Centralized authentication management
│   ├── config/               # App configuration
│   ├── constants/            # App-wide constants
│   ├── network/              # Network handling and API client
│   ├── utils/                # Utility functions
│   └── widgets/              # Reusable UI widgets
├── data/                     # Data layer
│   ├── models/               # Data models and entities
│   ├── repositories/         # Repository implementations
│   └── services/             # Service implementations
├── presentation/             # UI layer
│   ├── features/             # Feature-specific screens and widgets
│   ├── providers/            # Riverpod state providers
│   └── routes/               # Routing configuration
└── main.dart                 # Application entry point
```

## Development Commands

### Flutter Commands
```bash
# Get dependencies
flutter pub get

# Run the app in debug mode
flutter run

# Run on specific device
flutter run -d <device-id>

# Build APK for Android
flutter build apk

# Build iOS app
flutter build ios

# Run tests
flutter test

# Generate code (for build_runner)
flutter packages pub run build_runner build

# Clean and rebuild
flutter clean && flutter pub get
```

### Code Generation
The project uses code generation for JSON serialization:
```bash
# Generate code once
flutter packages pub run build_runner build

# Watch for changes and auto-generate
flutter packages pub run build_runner watch

# Clean generated files and rebuild
flutter packages pub run build_runner build --delete-conflicting-outputs
```

### Linting and Analysis
```bash
# Run Dart analyzer
flutter analyze

# Run specific linter rules
dart analyze --fatal-infos

# Format code
dart format .

# Check for outdated packages
flutter pub outdated
```

## Key Development Patterns

### Centralized Access Token Management
All authenticated API requests use the centralized authentication system:

```dart
// For repositories - extend BaseRepository
class MyRepository extends BaseRepository {
  // Use postWithAuth() or getWithAuth() for authenticated requests
  Future<Data> fetchData() async {
    return await makeAuthenticatedRequest<Data>(
      () async {
        final response = await postWithAuth('/api/endpoint', body: {});
        return Data.fromJson(response);
      },
      onAuthError: () => null,
    );
  }
}

// For services - inject CentralizedAuthManager
class MyService {
  final CentralizedAuthManager _authManager;
  
  Future<String?> getAccessKey() => _authManager.getValidAccessKey();
}
```

### State Management with Riverpod
```dart
// Provider definition
final myDataProvider = FutureProvider<Data>((ref) async {
  final repository = ref.watch(myRepositoryProvider);
  return await repository.fetchData();
});

// Usage in widgets
class MyWidget extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(myDataProvider);
    
    return dataAsync.when(
      data: (data) => Text(data.toString()),
      loading: () => CircularProgressIndicator(),
      error: (error, stack) => Text('Error: $error'),
    );
  }
}
```

### Repository Pattern
All repositories should extend `BaseRepository` for consistent access token management:

```dart
class ExampleRepository extends BaseRepository {
  ExampleRepository({
    required super.authManager,
    required super.apiClient,
    required super.logger,
  });

  Future<List<Item>> getItems() async {
    return await makeAuthenticatedRequest<List<Item>>(
      () async {
        logActivity('Fetching items');
        final response = await postWithAuth('/api/items', body: {});
        return (response['items'] as List)
            .map((item) => Item.fromJson(item))
            .toList();
      },
      onAuthError: () => <Item>[],
    ) ?? <Item>[];
  }
}
```

### Error Handling
- All repositories use `makeAuthenticatedRequest()` for consistent error handling
- Network errors are handled by the `ApiClient`
- Authentication errors trigger automatic token refresh
- UI shows appropriate error states using Riverpod's AsyncValue

### Logging
Use the centralized Logger for consistent logging:
```dart
// In repositories
logActivity('Operation description');

// In services  
_logger.log('Info message');
_logger.error('Error message');
_logger.warning('Warning message');
```

## API Integration

### Base URLs
- **Development**: `https://newtech.shalviadvision.com/api`
- All API requests automatically include `project_code` parameter
- Authenticated requests automatically include `access_key` parameter

### Common API Patterns
- **Authentication**: OTP-based mobile number verification
- **Data Format**: JSON request/response format
- **Error Handling**: Standardized error response format
- **Caching**: 20-hour cache for product data with daily reset at 2 AM

## Security Considerations

### Access Token Management
- **Storage**: FlutterSecureStorage for sensitive data
- **Expiry**: 10-day token expiration with automatic refresh
- **Validation**: Periodic validation every 5 minutes
- **Centralization**: All token access goes through `CentralizedAuthManager`

### Data Protection
- Never log complete access tokens (only first 8 characters)
- Use secure storage for sensitive information
- Validate API responses for authentication errors
- Clear cached data on logout

## Testing

### Widget Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Run tests with coverage
flutter test --coverage
```

### Test Structure
- Unit tests for models and utilities
- Widget tests for UI components
- Integration tests for complete user flows

## Common Issues and Solutions

### Access Token Issues
- **Problem**: API returns "unauthorized" errors
- **Solution**: Check `CentralizedAuthManager.isLoggedIn()` and token expiry
- **Debug**: Use `CentralizedAuthManager.refreshValidation()` to force token refresh

### State Management Issues
- **Problem**: UI not updating after data changes
- **Solution**: Ensure providers are properly invalidated using `ref.invalidate()`
- **Debug**: Check provider dependencies and cache invalidation

### Build Issues
- **Problem**: Code generation errors
- **Solution**: Run `flutter packages pub run build_runner clean` then rebuild
- **Debug**: Check that all models have proper JSON annotations

## Performance Optimization

### Image Caching
- Use `cached_network_image` for all remote images
- Automatic cache management with size limits
- Proper placeholder and error handling

### List Performance
- Use `ListView.builder` for long lists
- Implement proper `itemExtent` when possible
- Use `const` constructors where applicable

### Memory Management
- Dispose controllers and streams properly
- Use `AutoDisposeProvider` for temporary state
- Monitor memory usage with Flutter Inspector

## Deployment

### Android
```bash
# Build release APK
flutter build apk --release

# Build App Bundle
flutter build appbundle --release
```

### iOS
```bash
# Build for iOS
flutter build ios --release

# Archive for App Store
flutter build ios --release --export-options-plist=ios/exportOptions.plist
```

### Environment Configuration
- Development and production configurations
- API endpoints configurable per environment
- Feature flags for gradual rollouts

## Dependencies Management

### Major Dependencies
- `flutter_riverpod`: State management
- `go_router`: Navigation and routing  
- `dio`: HTTP client (when needed, prefer ApiClient)
- `http`: Primary HTTP client for API calls
- `flutter_secure_storage`: Secure storage for access tokens
- `cached_network_image`: Image caching and network image handling
- `firebase_messaging`: Push notifications and FCM
- `google_maps_flutter`: Maps integration for location services
- `geolocator`: Location services and permissions
- `razorpay_flutter`: Payment gateway integration
- `connectivity_plus`: Network connectivity detection
- `json_annotation` & `json_serializable`: Code generation for JSON serialization
- `intl`: Internationalization and date formatting

### Adding New Dependencies
1. Add to `pubspec.yaml`
2. Run `flutter pub get`
3. Update this documentation if it affects architecture
4. Ensure proper integration with existing patterns

## Code Style and Standards

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Functions/Variables: `camelCase`
- Constants: `UPPER_SNAKE_CASE`

### Documentation
- Document complex business logic
- Add TODO comments for known issues
- Keep this CLAUDE.md file updated with architectural changes

### Git Workflow
- Feature branches for new development
- Pull requests for code review
- Meaningful commit messages with context

## Asset Management

### Images and Fonts
- Images stored in `assets/images/` directory
- Custom Poppins font family with all weights (100-900)
- Icon fonts included with app icon configuration via `flutter_launcher_icons`
- Use `cached_network_image` for remote images with automatic caching

### Code Generation Files
- Generated files are ignored in git (`.g.dart`, `.freezed.dart`)
- Run code generation after model changes
- Generated files should not be manually edited

## Current Version
- App version: 4.0.2+10038 (build 10038)
- Requires Dart ^3.7.2