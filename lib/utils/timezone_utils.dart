import 'package:flutter/foundation.dart';

// lib/core/utils/timezone_utils.dart

class TimezoneUtils {
  /// Convert UTC datetime string to local datetime
  static DateTime? parseUtcToLocal(String? utcDateTimeString) {
    if (utcDateTimeString == null || utcDateTimeString.isEmpty) {
      return null;
    }
    
    try {
      // Parse the UTC datetime
      DateTime utcDateTime = DateTime.parse(utcDateTimeString);
      
      // Convert UTC to local timezone
      DateTime localDateTime = utcDateTime.toLocal();
      
      // Debug logging
      if (kDebugMode) print('TimezoneUtils: UTC input: $utcDateTimeString');
      if (kDebugMode) print('TimezoneUtils: Parsed UTC: $utcDateTime');
      if (kDebugMode) print('TimezoneUtils: Local output: $localDateTime');
      if (kDebugMode) print('TimezoneUtils: Local timezone: ${localDateTime.timeZoneName}');
      if (kDebugMode) print('TimezoneUtils: Timezone offset: ${localDateTime.timeZoneOffset}');
      
      return localDateTime;
    } catch (e) {
      if (kDebugMode) print('TimezoneUtils: Error parsing datetime: $e');
      return null;
    }
  }
  
  /// Get current local time for comparison
  static DateTime getCurrentLocalTime() {
    return DateTime.now();
  }
  
  /// Check if the server time matches expected local time
  static void debugTimezoneIssue(String serverTimeString) {
    final serverTime = parseUtcToLocal(serverTimeString);
    final currentTime = getCurrentLocalTime();
    
    if (kDebugMode) print('=== TIMEZONE DEBUG ===');
    if (kDebugMode) print('Server time (converted to local): $serverTime');
    if (kDebugMode) print('Current local time: $currentTime');
    
    if (serverTime != null) {
      final difference = currentTime.difference(serverTime);
      if (kDebugMode) print('Time difference: ${difference.inHours} hours, ${difference.inMinutes % 60} minutes');
      
      if (difference.inHours.abs() > 12) {
        if (kDebugMode) print('WARNING: Large time difference detected - possible timezone issue');
      }
    }
    if (kDebugMode) print('=== END DEBUG ===');
  }
  
  /// Format datetime for Indian locale (IST)
  static String formatForIndianLocale(DateTime dateTime) {
    // Ensure we're working with local time
    final localTime = dateTime.toLocal();
    
    final day = localTime.day.toString().padLeft(2, '0');
    final month = localTime.month.toString().padLeft(2, '0');
    final year = localTime.year.toString();
    
    final hour = localTime.hour > 12 
        ? localTime.hour - 12 
        : localTime.hour == 0 
            ? 12 
            : localTime.hour;
    final minute = localTime.minute.toString().padLeft(2, '0');
    final amPm = localTime.hour >= 12 ? 'PM' : 'AM';
    
    return '$day/$month/$year at ${hour.toString().padLeft(2, '0')}:$minute $amPm';
  }
}