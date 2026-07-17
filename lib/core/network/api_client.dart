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

/// Single choke point for all backend traffic against the universal
/// multi-tenant API:
/// - X-Project-Code header on every request (plus project_code in body/query,
///   which several routes still validate explicitly)
/// - `Authorization: Bearer` JWT header on the *WithAuth variants
/// - 401 on an authenticated call forces logout (stale/invalid session)
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

  Map<String, String> _headers({String? token}) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'X-Project-Code': ApiConstants.projectCode,
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      };

  /// Fetch the JWT with retries — new-login flows can race storage writes.
  Future<String?> _getToken() async {
    if (_authManager == null) return null;
    String? token;
    for (int attempt = 0; attempt < 3; attempt++) {
      token = await _authManager.getValidAccessKey();
      if (token != null && token.isNotEmpty) break;
      if (attempt < 2) {
        await Future.delayed(Duration(milliseconds: 200 * (attempt + 1)));
        _logger.log('Retrying token retrieval, attempt ${attempt + 2}');
      }
    }
    return token;
  }

  Future<dynamic> get(String url, {bool includeProjectCode = true}) async {
    return _run(() async {
      final Map<String, String> queryParams = {
        if (includeProjectCode) 'project_code': ApiConstants.projectCode,
        ...Uri.parse(url).queryParameters,
      };
      final Uri uri = Uri.parse(url)
          .replace(queryParameters: queryParams.isEmpty ? null : queryParams);

      _logger.log('GET request to: $uri');

      final response = await _client
          .get(uri, headers: _headers())
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response, authed: false);
    });
  }

  Future<dynamic> post(String url, {Map<String, dynamic>? body}) async {
    return _run(() async {
      final Map<String, dynamic> requestBody = {
        'project_code': ApiConstants.projectCode,
        ...body ?? {},
      };

      _logger.log('POST request to: $url');

      final response = await _client
          .post(Uri.parse(url),
              headers: _headers(), body: json.encode(requestBody))
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response, authed: false);
    });
  }

  /// POST with Authorization: Bearer header
  Future<dynamic> postWithAuth(String url, {Map<String, dynamic>? body}) async {
    return _run(() async {
      final token = await _getToken();

      final Map<String, dynamic> requestBody = {
        'project_code': ApiConstants.projectCode,
        ...body ?? {},
      };

      if (token == null || token.isEmpty) {
        _logger.warning('POST with auth request to: $url (NO TOKEN AVAILABLE)');
      } else {
        _logger.log('POST with auth request to: $url');
      }

      final response = await _client
          .post(Uri.parse(url),
              headers: _headers(token: token), body: json.encode(requestBody))
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response, authed: true);
    });
  }

  /// GET with Authorization: Bearer header
  Future<dynamic> getWithAuth(String url, {Map<String, String>? additionalParams}) async {
    return _run(() async {
      final token = await _getToken();

      final Map<String, String> queryParams = {
        'project_code': ApiConstants.projectCode,
        ...Uri.parse(url).queryParameters,
        ...additionalParams ?? {},
      };

      final Uri uri = Uri.parse(url).replace(queryParameters: queryParams);

      if (token == null || token.isEmpty) {
        _logger.warning('GET with auth request to: $uri (NO TOKEN AVAILABLE)');
      } else {
        _logger.log('GET with auth request to: $uri');
      }

      final response = await _client
          .get(uri, headers: _headers(token: token))
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response, authed: true);
    });
  }

  /// PUT with Authorization: Bearer header
  Future<dynamic> putWithAuth(String url, {Map<String, dynamic>? body}) async {
    return _run(() async {
      final token = await _getToken();

      final Map<String, dynamic> requestBody = {
        'project_code': ApiConstants.projectCode,
        ...body ?? {},
      };

      _logger.log('PUT with auth request to: $url');

      final response = await _client
          .put(Uri.parse(url),
              headers: _headers(token: token), body: json.encode(requestBody))
          .timeout(const Duration(seconds: 15));

      return _handleResponse(response, authed: true);
    });
  }

  /// DELETE with Authorization: Bearer header and optional JSON body
  Future<dynamic> deleteWithAuth(String url, {Map<String, dynamic>? body}) async {
    return _run(() async {
      final token = await _getToken();

      _logger.log('DELETE with auth request to: $url');

      final request = http.Request('DELETE', Uri.parse(url));
      request.headers.addAll(_headers(token: token));
      request.body = json.encode({
        'project_code': ApiConstants.projectCode,
        ...body ?? {},
      });

      final streamed = await _client
          .send(request)
          .timeout(const Duration(seconds: 15));
      final response = await http.Response.fromStream(streamed);

      return _handleResponse(response, authed: true);
    });
  }

  /// Shared network-error mapping so every verb behaves identically.
  Future<dynamic> _run(Future<dynamic> Function() request) async {
    try {
      return await request();
    } on ApiException {
      rethrow;
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

  dynamic _handleResponse(http.Response response, {required bool authed}) {
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
      // A 401 on an authenticated call means the stored session is invalid
      // (expired JWT, legacy access_key, deleted user) — force logout so the
      // UI drops back to the login flow.
      if (authed && response.statusCode == 401 && _authManager != null) {
        _logger.warning('401 on authenticated call — forcing logout');
        unawaited(_authManager.logout().catchError((e) {
          _logger.error('Forced logout failed: $e');
        }));
      }

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
    } else if (statusCode == 401) {
      return ErrorType.auth;
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
      if (body is Map && body.containsKey('error') && body['error'] is String) {
        return body['error'] as String;
      }
    } catch (_) {}

    switch (response.statusCode) {
      case 400:
        return 'Bad request';
      case 401:
        return 'Session expired. Please log in again.';
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
