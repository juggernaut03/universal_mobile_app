// lib/core/utils/logger.dart

import 'dart:developer' as developer;

class Logger {
  final bool enableLogs;
  final String tag;

  Logger({this.enableLogs = true, this.tag = 'APP'});

  void log(String message) {
    if (enableLogs) {
      developer.log(message, name: tag);
    }
  }

  void error(String message, [dynamic error, StackTrace? stackTrace]) {
    if (enableLogs) {
      developer.log(
        'ERROR: $message',
        name: tag,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  void info(String message) {
    if (enableLogs) {
      developer.log('INFO: $message', name: tag);
    }
  }

  void warning(String message) {
    if (enableLogs) {
      developer.log('WARNING: $message', name: tag);
    }
  }
}