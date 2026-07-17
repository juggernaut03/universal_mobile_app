# Project Architecture

This project follows a clean architecture approach with the following structure:

## Directory Structure

```
lib/
├── core/
│   ├── config/              # App configuration
│   ├── constants/           # App constants
│   ├── network/             # Network handling
│   └── utils/               # Utilities
├── data/
│   ├── models/              # Data models
│   ├── repositories/        # Repository implementations
│   └── services/            # API services
├── domain/                  # Business logic
│   ├── entities/            # Business entities
│   ├── repositories/        # Repository interfaces
│   └── usecases/            # Use cases
├── presentation/
│   ├── providers/           # Riverpod providers
│   ├── routes/              # Go Router configuration
│   └── features/            # Feature-specific UI components
└── main.dart
```

## Key Technologies

- **State Management**: Flutter Riverpod
- **Navigation**: Go Router
- **Network**: Dio
- **Architecture**: Clean Architecture

## Getting Started

1. Make sure you have required dependencies in `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.3.0
  go_router: ^10.0.0
  dio: ^5.0.0
  shared_preferences: ^2.0.0
  # Add other dependencies as needed
```

2. Run `flutter pub get` to fetch dependencies
3. Start building features!
