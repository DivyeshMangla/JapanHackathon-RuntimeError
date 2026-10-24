import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';

/// Where a take is captured before the patient decides to keep it. Kept
/// takes go to the care service, so the draft is the only recording file the
/// phone ever holds.
class RecordingFiles {
  const RecordingFiles();

  Future<Directory> _directory() => guard(() async {
    final base = await getApplicationSupportDirectory();
    return Directory(
      '${base.path}${Platform.pathSeparator}recordings',
    ).create(recursive: true);
  }, RecordingFailure.new);

  /// The draft is the only plaintext recording file, and it is removed when
  /// the take is kept or discarded.
  Future<String> draftPath() async {
    final dir = await _directory();
    return '${dir.path}${Platform.pathSeparator}draft.wav';
  }

  Future<void> discard(String path) => guard(() async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }, RecordingFailure.new);
}
