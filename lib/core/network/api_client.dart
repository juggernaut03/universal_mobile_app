// lib/core/network/api_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import '../widgets/error_widgets.dart';
import '../constants/app_constants.dart';
import '../auth/centralized_auth_manager.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final ErrorType type;

  ApiException({
    required this.message, 
    this.statusCode, 
    this.type = ErrorType.generic
  });

  @override
  String toString() => 'ApiException: $message';
}

class ApiClient {
  final http.Client _client;
  final Logger _logger;
  final CentralizedAuthManager? _authManager;

  ApiClient({
    http.Client? client, 
    Logger? logger,
    CentralizedAuthManager? authManager,
  }) : _client = client ?? http.Client(),
       _logger = logger ?? Logger(),
       _authManager = authManager;

  Future<dynamic> get(String url) async {
    try {
      // Add project code as a query parameter
      final Uri uri = Uri.parse(url).replace(
        queryParameters: {
          'project_code': ApiConstants.projectCode,
          ...Uri.parse(url).queryParameters,
        },
      );
      
      _logger.log('GET request to: $uri');
      
      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'No Internet connection',
        type: ErrorType.network
      );
    } on http.ClientException {
      throw ApiException(
        message: 'Failed to connect to server',
        type: ErrorType.network
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Connection timed out',
        type: ErrorType.network
      );
    } catch (e) {
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
        type: ErrorType.generic
      );
    }
  }

  Future<dynamic> post(String url, {Map<String, dynamic>? body}) async {
    try {
      // Create a new map that includes the project code
      final Map<String, dynamic> requestBody = {
        'project_code': ApiConstants.projectCode,
        ...body ?? {},
      };
      
      _logger.log('POST request to: $url, body: $requestBody');
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'No Internet connection',
        type: ErrorType.network
      );
    } on http.ClientException {
      throw ApiException(
        message: 'Failed to connect to server',
        type: ErrorType.network
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Connection timed out',
        type: ErrorType.network
      );
    } catch (e) {
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
        type: ErrorType.generic
      );
    }
  }

  /// POST request with automatic access token inclusion
  Future<dynamic> postWithAuth(String url, {Map<String, dynamic>? body}) async {
    try {
      // Get access token from auth manager with retry logic for new user login
      String? accessKey;
      if (_authManager != null) {
        // Try multiple times to get access key to handle race conditions
        for (int attempt = 0; attempt < 3; attempt++) {
          accessKey = await _authManager.getValidAccessKey();
          if (accessKey != null && accessKey.isNotEmpty) {
            break;
          }
          // Wait before retrying to allow auth state to propagate
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
            _logger.log('Retrying access key retrieval, attempt ${attempt + 2}');
          }
        }
      }

      // Create request body with project code and access key
      final Map<String, dynamic> requestBody = {
        'project_code': ApiConstants.projectCode,
        ...body ?? {},
      };

      // Add access key if available
      if (accessKey != null && accessKey.isNotEmpty) {
        requestBody['access_key'] = accessKey;
        _logger.log('POST with auth request to: $url (access key: ${accessKey.substring(0, 8)}...)');
      } else {
        _logger.warning('POST with auth request to: $url (NO ACCESS KEY AVAILABLE)');
      }
      
      final response = await _client.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(requestBody),
      ).timeout(const Duration(seconds: 15));
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'No Internet connection',
        type: ErrorType.network
      );
    } on http.ClientException {
      throw ApiException(
        message: 'Failed to connect to server',
        type: ErrorType.network
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Connection timed out',
        type: ErrorType.network
      );
    } catch (e) {
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
        type: ErrorType.generic
      );
    }
  }

  /// GET request with automatic access token inclusion
  Future<dynamic> getWithAuth(String url, {Map<String, String>? additionalParams}) async {
    try {
      // Get access token from auth manager with retry logic for new user login
      String? accessKey;
      if (_authManager != null) {
        // Try multiple times to get access key to handle race conditions
        for (int attempt = 0; attempt < 3; attempt++) {
          accessKey = await _authManager.getValidAccessKey();
          if (accessKey != null && accessKey.isNotEmpty) {
            break;
          }
          // Wait before retrying to allow auth state to propagate
          if (attempt < 2) {
            await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
            _logger.log('Retrying access key retrieval for GET, attempt ${attempt + 2}');
          }
        }
      }

      // Build query parameters
      final Map<String, String> queryParams = {
        'project_code': ApiConstants.projectCode,
        ...Uri.parse(url).queryParameters,
        ...additionalParams ?? {},
      };

      // Add access key if available
      if (accessKey != null && accessKey.isNotEmpty) {
        queryParams['access_key'] = accessKey;
      }

      final Uri uri = Uri.parse(url).replace(queryParameters: queryParams);
      
      if (accessKey != null && accessKey.isNotEmpty) {
        _logger.log('GET with auth request to: $uri (access key: ${accessKey.substring(0, 8)}...)');
      } else {
        _logger.warning('GET with auth request to: $uri (NO ACCESS KEY AVAILABLE)');
      }
      
      final response = await _client.get(
        uri,
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 15));
      
      return _handleResponse(response);
    } on SocketException {
      throw ApiException(
        message: 'No Internet connection',
        type: ErrorType.network
      );
    } on http.ClientException {
      throw ApiException(
        message: 'Failed to connect to server',
        type: ErrorType.network
      );
    } on TimeoutException {
      throw ApiException(
        message: 'Connection timed out',
        type: ErrorType.network
      );
    } catch (e) {
      throw ApiException(
        message: 'Unexpected error: ${e.toString()}',
        type: ErrorType.generic
      );
    }
  }

 // lib/core/network/api_client.dart (check the _handleResponse method)

dynamic _handleResponse(http.Response response) {
  _logger.log('Response status: ${response.statusCode}, body: ${response.body}');
  
  if (response.statusCode >= 200 && response.statusCode < 300) {
    if (response.body.isEmpty) return null;
    
    try {
      return json.decode(response.body);
    } catch (e) {
      _logger.error('Error decoding JSON response: $e. Raw response: ${response.body}');
      throw ApiException(
        message: 'Failed to decode API response',
        statusCode: response.statusCode,
        type: ErrorType.generic,
      );
    }
  } else {
    // Categorize errors
    final errorType = _getErrorType(response.statusCode);
    throw ApiException(
      message: _getErrorMessage(response),
      statusCode: response.statusCode,
      type: errorType,
    );
  }
}

  ErrorType _getErrorType(int statusCode) {
    if (statusCode == 0 || statusCode == -1) {
      return ErrorType.network;
    } else if (statusCode >= 500) {
      return ErrorType.server;
    } else if (statusCode == 404) {
      return ErrorType.dataNotFound;
    } else {
      return ErrorType.generic;
    }
  }

  String _getErrorMessage(http.Response response) {
    try {
      final body = json.decode(response.body);
      if (body is Map && body.containsKey('message')) {
        return body['message'] as String;
      }
    } catch (_) {}
    
    switch (response.statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Resource not found';
      case 500:
        return 'Server error';
      default:
        return 'Something went wrong (${response.statusCode})';
    }
  }
}