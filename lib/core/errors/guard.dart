import 'dart:async';

import '../logging/app_logger.dart';
import 'app_failure.dart';

/// Runs [body], logging and converting any unexpected error into the failure
/// built by [toFailure]. Failures that are already typed pass through.
Future<T> guard<T>(
  FutureOr<T> Function() body,
  AppFailure Function(Object error) toFailure,
) async {
  try {
    return await body();
  } on AppFailure {
    rethrow;
  } catch (error, stack) {
    final failure = toFailure(error);
    AppLogger.error(failure.runtimeType.toString(), error, stack);
    throw failure;
  }
}

/// [guard] for local storage access.
Future<T> guardStorage<T>(FutureOr<T> Function() body) =>
    guard(body, StorageFailure.new);
