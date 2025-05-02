# PatelMart Flutter Application

## Overview

PatelMart is a comprehensive e-commerce application built with Flutter, following modern development practices and architecture. The app allows users to browse products by category, add items to cart, select delivery options, and place orders with various payment methods.

## Key Features

- **Location-based Services**: Pincode and outlet selection for contextual shopping
- **Product Browsing**: Department, category, and subcategory-based product navigation
- **Responsive Design**: Adaptive UI that works across different screen sizes
- **Cart Management**: Add/remove products, update quantities, validate server-side
- **Checkout Flow**: Multi-step checkout process with address, time slot, and payment selection
- **User Authentication**: OTP-based mobile number authentication
- **User Profile**: Manage personal details and saved addresses
- **Order Management**: Place orders with multiple payment options

## Technical Architecture

### Project Structure

The application follows a feature-first, clean architecture approach:

```
lib/
├── core/                  # Core utilities and common components
│   ├── config/            # App configuration
│   ├── constants/         # App-wide constants
│   ├── network/           # Network handling
│   ├── utils/             # Utility functions
│   └── widgets/           # Reusable widgets
├── data/                  # Data layer
│   ├── models/            # Data models
│   ├── repositories/      # Repositories
│   └── services/          # Service implementations
├── presentation/          # UI layer
│   ├── features/          # Feature-specific screens
│   ├── providers/         # State management providers
│   ├── routes/            # Routing configuration
│   └── widgets/           # Feature-specific widgets
└── main.dart              # Application entry point
```

### State Management

The application uses [Riverpod](https://riverpod.dev/) for state management, providing:

- **Reactive State Updates**: UI automatically updates when state changes
- **Provider Dependencies**: Providers can depend on other providers
- **Cached Data**: Data fetching with caching and error handling
- **Async Values**: Built-in loading and error state handling

### Navigation

[GoRouter](https://pub.dev/packages/go_router) is used for navigation with:

- **Declarative Routes**: Clear route definitions
- **Deep Linking**: Support for deep links and dynamic route parameters
- **Route Redirects**: Conditional redirects based on app state

### Data Caching Strategy

The app implements a sophisticated caching strategy:

- **Product Data**: Cached for 20 hours with automatic invalidation
- **Product Images**: Cached using flutter_cache_manager
- **Daily Cache Clearing**: Automatic cache reset at 2 AM
- **Secure Storage**: User tokens stored securely with 10-day expiry

## Performance Optimizations

- **Widget Optimizations**: Efficient widget rebuilds using const constructors
- **Lazy Loading**: Products and images loaded on-demand
- **Cached Network Images**: Reduced bandwidth usage with image caching
- **List Rendering**: Efficient list rendering with ListView.builder

## Responsive Design Patterns

The app uses several responsive design patterns:

- **MediaQuery**: Screen size detection for adaptive layouts
- **Relative Sizing**: Proportional sizing instead of fixed dimensions
- **Device Breakpoints**: Screen-specific layouts based on device size
- **Flexible Layouts**: Expanded and Flexible widgets for proportional spacing

## Error Handling and UI Patterns

- **Contextual Error UI**: Different UI treatments based on error type
- **Graceful Fallbacks**: Display cached data when offline
- **User Feedback**: Clear error messages with actionable recovery steps
- **Empty States**: Well-designed empty state screens

## Security Measures

- **Secure Storage**: Sensitive information stored in flutter_secure_storage
- **OTP Authentication**: SMS-based verification for user accounts
- **Token Expiry**: Access tokens expire after 10 days
- **API Security**: All API calls include project code verification

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Dart SDK
- Android Studio / XCode for emulators
- A physical device or emulator

### Installation

1. Clone the repository
   ```bash
   git clone https://github.com/yourusername/patelmart.git
   ```

2. Navigate to the project directory
   ```bash
   cd patelmart
   ```

3. Install dependencies
   ```bash
   flutter pub get
   ```

4. Run the app
   ```bash
   flutter run
   ```

### Environment Configuration

Create a `.env` file in the project root with the following variables:

```
API_BASE_URL=https://newtech.shalviadvision.com/api
GOOGLE_MAPS_API_KEY=your_google_maps_api_key
RAZORPAY_KEY_ID=your_razorpay_key_id
```

## Dependencies

Major dependencies include:

- **flutter_riverpod**: State management
- **go_router**: Navigation and routing
- **http**: API communication
- **shared_preferences**: Local storage
- **flutter_secure_storage**: Secure storage for sensitive data
- **cached_network_image**: Image caching
- **geolocator**: Location services
- **google_maps_flutter**: Maps integration
- **razorpay_flutter**: Payment processing
- **connectivity_plus**: Network connectivity detection

## Best Practices Implemented

1. **Clean Architecture**: Separation of concerns with proper layering
2. **Repository Pattern**: Abstraction of data sources
3. **Dependency Injection**: Using Riverpod for service locator pattern
4. **State Management**: Efficient state management with Riverpod
5. **Error Handling**: Comprehensive error handling with user-friendly messages
6. **Caching**: Smart caching with proper invalidation
7. **Code Organization**: Feature-first organization for better maintainability
8. **Responsive Design**: Adaptive layouts for all screen sizes
9. **Testability**: Architecture designed for testability

## Coding Standards

- **Naming Conventions**: Consistent naming using snake_case for files, PascalCase for classes
- **Code Formatting**: Standard Dart formatting with 2-space indentation
- **Documentation**: In-code documentation for complex logic
- **Folder Structure**: Organized by feature and layer
- **State Management**: Consistent patterns for state management
- **Error Handling**: Systematic approach to error handling

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Acknowledgements

- Flutter team for the amazing framework
- All third-party package authors
- Design inspiration from various e-commerce applications