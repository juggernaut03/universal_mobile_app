// lib/data/repositories/base_repository.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/auth/centralized_auth_manager.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../../presentation/providers/launch_flow_provider.dart';

/// Base repository class that provides centralized access token management
/// and common repository functionality
abstract class BaseRepository {
  final CentralizedAuthManager _authManager;
  final ApiClient _apiClient;
  final Logger _logger;

  BaseRepository({
    required CentralizedAuthManager authManager,
    required ApiClient apiClient,
    required Logger logger,
  }) : _authManager = authManager,
       _apiClient = apiClient,
       _logger = logger;

  /// Get current access token from centralized auth manager
  Future<String?> getAccessKey() async {
    try {
      final accessKey = await _authManager.getValidAccessKey();
      if (accessKey == null || accessKey.isEmpty) {
        _logger.warning('No valid access key available');
        return null;
      }
      return accessKey;
    } catch (e) {
      _logger.error('Error getting access key: $e');
      return null;
    }
  }

  /// Check if user has a valid access token
  Future<bool> hasValidAccessKey() async {
    final accessKey = await getAccessKey();
    return accessKey != null && accessKey.isNotEmpty;
  }

  /// Get current user mobile number
  Future<String?> getUserMobile() async {
    try {
      return await _authManager.getUserMobile();
    } catch (e) {
      _logger.error('Error getting user mobile: $e');
      return null;
    }
  }

  /// Check if user is logged in
  Future<bool> isUserLoggedIn() async {
    try {
      return await _authManager.isLoggedIn();
    } catch (e) {
      _logger.error('Error checking login status: $e');
      return false;
    }
  }

  /// Make authenticated POST request using centralized token management
  Future<dynamic> postWithAuth(String url, {Map<String, dynamic>? body}) async {
    try {
      return await _apiClient.postWithAuth(url, body: body);
    } catch (e) {
      _logger.error('Error in authenticated POST request: $e');
      rethrow;
    }
  }

  /// Make authenticated GET request using centralized token management
  Future<dynamic> getWithAuth(String url, {Map<String, String>? additionalParams}) async {
    try {
      return await _apiClient.getWithAuth(url, additionalParams: additionalParams);
    } catch (e) {
      _logger.error('Error in authenticated GET request: $e');
      rethrow;
    }
  }

  /// Make regular POST request (no authentication)
  Future<dynamic> post(String url, {Map<String, dynamic>? body}) async {
    try {
      return await _apiClient.post(url, body: body);
    } catch (e) {
      _logger.error('Error in POST request: $e');
      rethrow;
    }
  }

  /// Make regular GET request (no authentication)
  Future<dynamic> get(String url) async {
    try {
      return await _apiClient.get(url);
    } catch (e) {
      _logger.error('Error in GET request: $e');
      rethrow;
    }
  }

  /// Handle authentication-related errors
  /// Override this method in child repositories for custom error handling
  void handleAuthError(dynamic error) {
    _logger.error('Authentication error in $runtimeType: $error');
    // Clear cached credentials if authentication fails
    // This forces a fresh token retrieval on next request
    _authManager.refreshValidation();
  }

  /// Validate response for authentication errors
  /// Returns true if response is valid, false if auth error occurred
  bool validateAuthResponse(dynamic response) {
    if (response is Map<String, dynamic>) {
      // Check for common authentication error indicators
      final message = response['message']?.toString().toLowerCase() ?? '';
      final status = response['status']?.toString().toLowerCase() ?? '';
      
      if (message.contains('unauthorized') || 
          message.contains('invalid access key') ||
          message.contains('access denied') ||
          status.contains('unauthorized')) {
        handleAuthError('Authentication failed: $message');
        return false;
      }
    }
    return true;
  }

  /// Make authenticated request with automatic error handling
  Future<T?> makeAuthenticatedRequest<T>(
    Future<T> Function() request, {
    T? Function()? onAuthError,
  }) async {
    try {
      // Check if user is logged in first
      if (!await isUserLoggedIn()) {
        _logger.error('User not logged in for authenticated request');
        return onAuthError?.call();
      }

      final result = await request();
      
      // Validate response for auth errors if it's a Map
      if (result is Map<String, dynamic>) {
        if (!validateAuthResponse(result)) {
          return onAuthError?.call();
        }
      }
      
      return result;
    } catch (e) {
      _logger.error('Error in authenticated request: $e');
      handleAuthError(e);
      return onAuthError?.call();
    }
  }

  /// Log repository activity for debugging
  void logActivity(String activity, {Map<String, dynamic>? details}) {
    final repositoryName = runtimeType.toString();
    final message = details != null 
        ? '$repositoryName: $activity - Details: $details'
        : '$repositoryName: $activity';
    _logger.log(message);
  }
}

// Local providers to avoid circular dependencies
final _secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final _loggerProvider = Provider((ref) => Logger());

final _apiClientProvider = Provider<ApiClient>((ref) {
  final logger = ref.watch(_loggerProvider);
  final authManager = ref.watch(_centralizedAuthManagerProvider);
  return ApiClient(logger: logger, authManager: authManager);
});

// Use the same centralized auth manager provider defined in centralized_auth_manager.dart
// to ensure consistency across the app
final _centralizedAuthManagerProvider = centralizedAuthManagerProvider;

/// Provider for base repository dependencies
final baseRepositoryDependenciesProvider = Provider<BaseRepositoryDependencies>((ref) {
  return BaseRepositoryDependencies(
    authManager: ref.watch(_centralizedAuthManagerProvider),
    apiClient: ref.watch(_apiClientProvider),
    logger: ref.watch(_loggerProvider),
  );
});

/// Dependencies container for base repository
class BaseRepositoryDependencies {
  final CentralizedAuthManager authManager;
  final ApiClient apiClient;
  final Logger logger;

  BaseRepositoryDependencies({
    required this.authManager,
    required this.apiClient,  
    required this.logger,
  });
}

/// Enhanced API client provider
final apiClientProvider = Provider<ApiClient>((ref) {
  final logger = ref.watch(_loggerProvider);
  final authManager = ref.watch(_centralizedAuthManagerProvider);
  
  return ApiClient(
    logger: logger,
    authManager: authManager,
  );
});