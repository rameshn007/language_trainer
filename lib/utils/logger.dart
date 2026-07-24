import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

class AppLogger {
  static void log(String message, {String name = 'App'}) {
    debugPrint('[$name] $message');
  }

  static void error(
    String message, {
    String name = 'App',
    Object? error,
    StackTrace? stackTrace,
  }) {
    developer.log(
      message,
      name: name,
      error: error,
      stackTrace: stackTrace,
      level: 1000, // Severe level
    );
  }
}
