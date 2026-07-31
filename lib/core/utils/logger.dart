// lib/core/utils/logger.dart

import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';

class Logger {
  final bool enableLogs;
  final String tag;

  Logger({this.enableLogs = true, this.tag = 'APP'});

  /// `developer.log` goes to the VM service, which DevTools reads but
  /// `flutter run` does not print — so every API status, response body and
  /// failure reason logged through here was invisible in the terminal, and
  /// checkout failures looked like they had no diagnostics at all. Debug
  /// builds echo to stdout as well; release builds keep the VM-service-only
  /// behaviour, since these lines include full response bodies.
  void _echo(String message) {
    if (kDebugMode) debugPrint('[$tag] $message');
  }

  void log(String message) {
    if (enableLogs) {
      developer.log(message, name: tag);
      _echo(message);
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
      _echo('ERROR: $message${error == null ? '' : ' ($error)'}');
    }
  }

  void info(String message) {
    if (enableLogs) {
      developer.log('INFO: $message', name: tag);
      _echo('INFO: $message');
    }
  }

  void warning(String message) {
    if (enableLogs) {
      developer.log('WARNING: $message', name: tag);
      _echo('WARNING: $message');
    }
  }
}
