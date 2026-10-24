import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';

/// Short-lived plaintext copies of recordings fetched for playback. The
/// player needs a file, so a copy exists only while a recording is loaded.
class PlaybackFiles {
  const PlaybackFiles();

  Future<String> write(String name, Uint8List wav) => guard(() async {
    final dir = await _directory();
    final file = File('${dir.path}${Platform.pathSeparator}$name.wav');
    await file.writeAsBytes(wav, flush: true);
    return file.path;
  }, PlaybackFailure.new);

  Future<void> delete(String path) => guard(() async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }, PlaybackFailure.new);

  /// Removes any copies left behind, e.g. after a crash.
  Future<void> clearAll() => guard(() async {
    final dir = await _directory();
    if (await dir.exists()) await dir.delete(recursive: true);
  }, PlaybackFailure.new);

  Future<Directory> _directory() async {
    final temp = await getTemporaryDirectory();
    return Directory(
      '${temp.path}${Platform.pathSeparator}playback',
    ).create(recursive: true);
  }
}
