// lib/data/repositories/category_repository.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../../core/constants/app_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/utils/logger.dart';
import '../models/department_model.dart';
import '../models/category_model.dart';

class CategoryRepository {
  final ApiClient _apiClient;
  final Logger _logger;
  final DefaultCacheManager _cacheManager;
  
  static const int _cacheDurationHours = 20; // Cache duration of 20 hours
  static const String _departmentsKey = 'departments_cache';
  static const String _categoriesKeyPrefix = 'categories_cache_dept_';
  static const String _timestampKeyPrefix = 'timestamp_';
  static const String _lastCacheClearKey = 'last_cache_clear_time';

  CategoryRepository({
    required ApiClient apiClient,
    Logger? logger,
    DefaultCacheManager? cacheManager,
  })  : _apiClient = apiClient,
        _logger = logger ?? Logger(),
        _cacheManager = cacheManager ?? DefaultCacheManager();

  // Fetch departments with caching
  Future<List<DepartmentModel>> getDepartments(String storeCode) async {
    try {
      // Check if cache should be cleared (2 AM daily)
      await _checkAndClearCacheIfNeeded();
      
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_departmentsKey);
      final cachedTimestamp = prefs.getInt('$_timestampKeyPrefix$_departmentsKey') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is valid (not older than cache duration)
      if (cachedData != null && (currentTime - cachedTimestamp < _cacheDurationHours * 3600000)) {
        _logger.log('Using cached departments data');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => DepartmentModel.fromJson(item)).toList();
      }

      _logger.log('Fetching departments from API');
      final response = await _apiClient.post(
        ApiConstants.getActiveDepartmentList,
        body: {
          'store_code': storeCode,
        },
      );

      List<dynamic> deptData =
          response is Map ? (response['data'] as List? ?? []) : (response as List);

      // Departments may be tenant-global (store_code null in the DB)
      if (deptData.isEmpty) {
        final fallback = await _apiClient.post(
          ApiConstants.getActiveDepartmentList,
          body: {'store_code': 'null'},
        );
        deptData =
            fallback is Map ? (fallback['data'] as List? ?? []) : (fallback as List);
      }
      final List<DepartmentModel> departments =
          deptData.map((item) => DepartmentModel.fromJson(item)).toList();

      // Cache the departments
      await prefs.setString(_departmentsKey, jsonEncode(deptData));
      await prefs.setInt('$_timestampKeyPrefix$_departmentsKey', currentTime);

      // Pre-cache department images for better user experience
      _preCacheDepartmentImages(departments);

      return departments;
    } catch (e) {
      _logger.error('Error fetching departments: $e');
      // Try to get data from cache even if it's expired
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_departmentsKey);
      if (cachedData != null) {
        _logger.log('Using expired cached departments data due to error');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => DepartmentModel.fromJson(item)).toList();
      }
      rethrow;
    }
  }

  // Fetch categories for a department with caching
  Future<List<CategoryModel>> getCategoriesForDepartment(String departmentId, String storeCode) async {
    try {
      await _checkAndClearCacheIfNeeded();
      
      final cacheKey = '$_categoriesKeyPrefix$departmentId';
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(cacheKey);
      final cachedTimestamp = prefs.getInt('$_timestampKeyPrefix$cacheKey') ?? 0;
      final currentTime = DateTime.now().millisecondsSinceEpoch;
      
      // Check if cache is valid (not older than cache duration)
      if (cachedData != null && (currentTime - cachedTimestamp < _cacheDurationHours * 3600000)) {
        _logger.log('Using cached categories data for department $departmentId');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => CategoryModel.fromJson(item)).toList();
      }

      _logger.log('Fetching categories for department $departmentId from API');
      final response = await _apiClient.post(
        ApiConstants.getActiveCategoriesList,
        body: {
          'dept_id': departmentId,
          'store_code': storeCode,
        },
      );

      final List<dynamic> catData =
          response is Map ? (response['data'] as List? ?? []) : (response as List);
      final List<CategoryModel> categories =
          catData.map((item) => CategoryModel.fromJson(item)).toList();

      // Cache the categories
      await prefs.setString(cacheKey, jsonEncode(catData));
      await prefs.setInt('$_timestampKeyPrefix$cacheKey', currentTime);

      // Pre-cache category images for better user experience
      _preCacheCategoryImages(categories);

      return categories;
    } catch (e) {
      _logger.error('Error fetching categories for department $departmentId: $e');
      // Try to get data from cache even if it's expired
      final prefs = await SharedPreferences.getInstance();
      final cacheKey = '$_categoriesKeyPrefix$departmentId';
      final cachedData = prefs.getString(cacheKey);
      if (cachedData != null) {
        _logger.log('Using expired cached categories data due to error');
        final List<dynamic> decoded = jsonDecode(cachedData);
        return decoded.map((item) => CategoryModel.fromJson(item)).toList();
      }
      rethrow;
    }
  }

  // Pre-cache department images in the background
  Future<void> _preCacheDepartmentImages(List<DepartmentModel> departments) async {
    for (final department in departments) {
      if (department.imageLink.isNotEmpty) {
        try {
          await _cacheManager.downloadFile(
            department.imageLink,
            key: 'department_${department.departmentId}',
          );
          _logger.log('Cached department image: ${department.imageLink}');
        } catch (e) {
          _logger.error('Error caching department image: $e');
          // Continue with next image on error
        }
      }
    }
  }

  // Pre-cache category images in the background
  Future<void> _preCacheCategoryImages(List<CategoryModel> categories) async {
    for (final category in categories) {
      if (category.imageLink.isNotEmpty) {
        try {
          await _cacheManager.downloadFile(
            category.imageLink,
            key: 'category_${category.categoryId}',
          );
          _logger.log('Cached category image: ${category.imageLink}');
        } catch (e) {
          _logger.error('Error caching category image: $e');
          // Continue with next image on error
        }
      }
    }
  }

  // Check if it's time to clear cache (2 AM daily)
  Future<void> _checkAndClearCacheIfNeeded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastClearTime = prefs.getInt(_lastCacheClearKey) ?? 0;
      
      final now = DateTime.now();
      final lastClear = DateTime.fromMillisecondsSinceEpoch(lastClearTime);
      
      // Get today's 2 AM timestamp
      final todayTwoAm = DateTime(now.year, now.month, now.day, 2, 0, 0);
      
      // If current time is after 2 AM today and last clear was before 2 AM today
      if (now.isAfter(todayTwoAm) && lastClear.isBefore(todayTwoAm)) {
        _logger.log('Clearing cache at daily scheduled time (2 AM)');
        await clearCache();
        await prefs.setInt(_lastCacheClearKey, now.millisecondsSinceEpoch);
      }
    } catch (e) {
      _logger.error('Error checking cache clear schedule: $e');
      // Continue without clearing cache on error
    }
  }

  // Get a cached image if available
  Future<String> getCachedImageUrl(String originalUrl, String cacheKey) async {
    try {
      final fileInfo = await _cacheManager.getFileFromCache(cacheKey);
      if (fileInfo != null) {
        return fileInfo.file.path;
      }
      return originalUrl;
    } catch (e) {
      _logger.error('Error getting cached image: $e');
      return originalUrl;
    }
  }

  // Clear cache (for debugging or force refresh)
  Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key == _departmentsKey || 
            key.startsWith(_categoriesKeyPrefix) ||
            key.startsWith(_timestampKeyPrefix)) {
          await prefs.remove(key);
        }
      }
      
      // Also clear image cache
      await _cacheManager.emptyCache();
      
      _logger.log('Category cache cleared');
    } catch (e) {
      _logger.error('Error clearing cache: $e');
    }
  }
}