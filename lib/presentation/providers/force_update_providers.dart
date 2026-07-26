// lib/presentation/providers/force_update_providers.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:patelmart/data/services/force_update_service.dart';
import '../../di/service_providers.dart';

/// Provider for the force update service

/// Provider to check for app updates
final updateCheckProvider = FutureProvider<UpdateCheckResponse>((ref) async {
  debugPrint('🎯 UPDATE CHECK PROVIDER CALLED');
  try {
    final service = ref.read(forceUpdateServiceProvider);
    final result = await service.checkForUpdate();
    debugPrint('🎯 UPDATE CHECK PROVIDER SUCCESS');
    debugPrint('🎯 Platform-specific URLs retrieved:');
    debugPrint('   └─ Android: ${result.androidDownloadUrl}');
    debugPrint('   └─ iOS: ${result.iosDownloadUrl}');
    debugPrint('   └─ Selected: ${result.downloadUrl}');
    return result;
  } catch (e) {
    debugPrint('🎯 UPDATE CHECK PROVIDER ERROR: $e');
    rethrow;
  }
});

/// State provider to track if force update check has been completed
final forceUpdateCheckedProvider = StateProvider<bool>((ref) {
  debugPrint('🎯 FORCE UPDATE CHECKED PROVIDER INITIALIZED');
  return false;
});