import 'dart:developer' as developer;

/// The single logging entry point. Writes to the platform log only, never to
/// a network service. Callers must not pass patient data (names, emails,
/// recordings); log failure types and technical details instead.
abstract final class AppLogger {
  static const _name = 'melo';

  static void info(String message) =>
      developer.log(message, name: _name, level: 800);

  static void warning(String message, [Object? error]) =>
      developer.log(message, name: _name, level: 900, error: error);

  static void error(String message, Object error, [StackTrace? stack]) =>
      developer.log(
        message,
        name: _name,
        level: 1000,
        error: error,
        stackTrace: stack,
      );
}
