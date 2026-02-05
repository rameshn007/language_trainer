import 'dart:developer' as developer;

class AppLogger {
  static void log(String message, {String name = 'App'}) {
    developer.log(message, name: name);
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
