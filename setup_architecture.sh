#!/bin/bash

# Make sure we're in the project root (parent of lib folder)
if [ ! -d "lib" ]; then
    echo "Error: This script must be run from your Flutter project root directory"
    exit 1
fi

# Core directories
mkdir -p lib/core/config
mkdir -p lib/core/constants
mkdir -p lib/core/network
mkdir -p lib/core/utils

# Data directories
mkdir -p lib/data/models
mkdir -p lib/data/repositories
mkdir -p lib/data/services

# Domain directories
mkdir -p lib/domain/entities
mkdir -p lib/domain/repositories
mkdir -p lib/domain/usecases

# Presentation directories
mkdir -p lib/presentation/providers
mkdir -p lib/presentation/routes
mkdir -p lib/presentation/features

# Create basic features directories
mkdir -p lib/presentation/features/home
mkdir -p lib/presentation/features/product
mkdir -p lib/presentation/features/cart
mkdir -p lib/presentation/features/checkout

# Create common files in core
touch lib/core/config/app_config.dart
touch lib/core/constants/app_constants.dart
touch lib/core/constants/app_colors.dart
touch lib/core/constants/app_text_styles.dart
touch lib/core/network/api_client.dart
touch lib/core/network/network_info.dart
touch lib/core/utils/logger.dart
touch lib/core/utils/extensions.dart

# Create Go Router configuration
touch lib/presentation/routes/app_router.dart
touch lib/presentation/routes/route_names.dart

# Create basic app setup
cat > lib/app.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'presentation/routes/app_router.dart';

class MyApp extends ConsumerWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Your App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
EOF

# Update main.dart
cat > lib/main.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  
  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}
EOF

# Create basic router configuration
cat > lib/presentation/routes/app_router.dart << 'EOF'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'route_names.dart';
import '../features/home/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        name: RouteNames.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Route not found: ${state.uri}'),
      ),
    ),
  );
});
EOF

# Create route names
cat > lib/presentation/routes/route_names.dart << 'EOF'
class RouteNames {
  static const String home = 'home';
  static const String productDetail = 'productDetail';
  static const String cart = 'cart';
  static const String checkout = 'checkout';
}
EOF

# Create a sample home screen
mkdir -p lib/presentation/features/home
cat > lib/presentation/features/home/home_screen.dart << 'EOF'
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Home'),
      ),
      body: const Center(
        child: Text('Home Screen'),
      ),
    );
  }
}
EOF

# Create README file with setup instructions
cat > README-ARCHITECTURE.md << 'EOF'
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
EOF

# Create gitignore files in empty directories to ensure they're committed
find lib -type d -empty -exec touch {}/.gitkeep \;

echo "Project structure created successfully!"
echo "Next steps:"
echo "1. Add required packages to pubspec.yaml"
echo "2. Run 'flutter pub get'"
echo "3. Check README-ARCHITECTURE.md for more information"