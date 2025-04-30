// lib/core/network/api_client.dart

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../utils/logger.dart';
import '../widgets/error_widgets.dart';
import '../constants/app_constants.dart';

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

  ApiClient({http.Client? client, Logger? logger})
      : _client = client ?? http.Client(),
        _logger = logger ?? Logger();

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