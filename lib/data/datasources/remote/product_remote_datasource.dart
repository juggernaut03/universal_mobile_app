// lib/data/datasources/remote/product_remote_datasource.dart
//
// HTTP only. Knows nothing about caching, image prefetching or cache
// scheduling — the old ProductRepository did all four in one class.
//
// Throws typed AppExceptions; never returns null and never returns a Result.
// Converting exceptions to failures is the repository's job.

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../../core/constants/app_constants.dart';
import '../../../core/error/exceptions.dart';
import '../../models/product_model.dart';

/// Backend access for the product catalogue.
abstract interface class IProductRemoteDataSource {
  /// POST /products/get-products
  Future<List<ProductModel>> fetchProducts({
    required String storeCode,
    required String departmentId,
    required String categoryId,
    required String subCategoryId,
  });

  /// POST /products/productdetails
  ///
  /// Throws [NotFoundException] when the backend has no such product.
  Future<ProductModel> fetchProductByCode({
    required String code,
    required String storeCode,
  });
}

final class ProductRemoteDataSource implements IProductRemoteDataSource {
  final http.Client _client;
  final String _baseUrl;

  ProductRemoteDataSource({
    required http.Client client,
    String? baseUrl,
  })  : _client = client,
        _baseUrl = baseUrl ?? ApiConstants.baseUrl;

  static const Duration _timeout = Duration(seconds: 15);

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'X-Project-Code': ApiConstants.projectCode,
      };

  @override
  Future<List<ProductModel>> fetchProducts({
    required String storeCode,
    required String departmentId,
    required String categoryId,
    required String subCategoryId,
  }) async {
    final body = await _post('/products/get-products', {
      'dept_id': departmentId,
      'category_id': categoryId,
      'sub_category_id': subCategoryId,
      'store_code': storeCode,
      'project_code': ApiConstants.projectCode,
    });

    final list = _asList(body);
    return _parseList(list);
  }

  @override
  Future<ProductModel> fetchProductByCode({
    required String code,
    required String storeCode,
  }) async {
    final body = await _post('/products/productdetails', {
      'p_code': code,
      'store_code': storeCode,
      'project_code': ApiConstants.projectCode,
    });

    // Universal backend returns {success, data: {...}}; some routes still
    // return a bare object or a single-element list.
    final data = body is Map<String, dynamic> ? body['data'] : body;

    if (data is Map<String, dynamic>) {
      return _parseOne(data);
    }
    if (data is List && data.isNotEmpty) {
      return _parseOne(data.first);
    }
    throw NotFoundException('No product for code "$code" at store "$storeCode"');
  }

  /// Issues the request and decodes the envelope, mapping transport and status
  /// problems onto typed exceptions.
  Future<dynamic> _post(String path, Map<String, dynamic> payload) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            Uri.parse('$_baseUrl$path'),
            headers: _headers,
            body: jsonEncode(payload),
          )
          .timeout(_timeout);
    } on Exception catch (e, st) {
      // Socket errors, DNS failures and timeouts. Mapped centrally by
      // mapErrorToFailure, but wrapped here so the layer contract holds:
      // datasources throw AppException, nothing else.
      throw NetworkException(
        'POST $path failed before a response was received',
        cause: e,
        stackTrace: st,
      );
    }

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw AuthException('POST $path rejected (${response.statusCode})');
    }
    if (response.statusCode == 404) {
      throw NotFoundException('POST $path returned 404');
    }
    if (response.statusCode != 200) {
      throw ServerException(
        'POST $path failed',
        statusCode: response.statusCode,
        body: response.body,
      );
    }

    try {
      return jsonDecode(response.body);
    } on FormatException catch (e, st) {
      throw ParsingException(
        'POST $path returned a body that is not valid JSON',
        targetType: 'ProductModel',
        cause: e,
        stackTrace: st,
      );
    }
  }

  /// Unwraps `{data: [...]}` or a bare `[...]`.
  List<dynamic> _asList(dynamic body) {
    if (body is Map<String, dynamic>) return body['data'] as List? ?? const [];
    if (body is List) return body;
    throw ParsingException(
      'Expected a list of products, got ${body.runtimeType}',
      targetType: 'List<ProductModel>',
    );
  }

  List<ProductModel> _parseList(List<dynamic> raw) {
    try {
      return raw
          .whereType<Map<String, dynamic>>()
          .map(ProductModel.fromJson)
          .toList(growable: false);
    } on Object catch (e, st) {
      throw ParsingException(
        'Could not parse product list',
        targetType: 'List<ProductModel>',
        cause: e,
        stackTrace: st,
      );
    }
  }

  ProductModel _parseOne(dynamic raw) {
    if (raw is! Map<String, dynamic>) {
      throw ParsingException(
        'Expected a product object, got ${raw.runtimeType}',
        targetType: 'ProductModel',
      );
    }
    try {
      return ProductModel.fromJson(raw);
    } on Object catch (e, st) {
      throw ParsingException(
        'Could not parse product',
        targetType: 'ProductModel',
        cause: e,
        stackTrace: st,
      );
    }
  }
}
