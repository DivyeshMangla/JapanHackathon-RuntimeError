import 'dart:io';
import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../domain/recording.dart';
import 'recording_vault.dart';

/// Places recordings in app-private storage (never the shared gallery or
/// media store), named by participant code rather than patient name, and
/// encrypted through [RecordingVault].
class RecordingFiles {
  const RecordingFiles(this._vault);

  final RecordingVault _vault;

  static final _stamp = DateFormat("yyyyMMdd'T'HHmmss");

  Future<Directory> _directory() => guard(() async {
    final base = await getApplicationSupportDirectory();
    return Directory(
      '${base.path}${Platform.pathSeparator}recordings',
    ).create(recursive: true);
  }, RecordingFailure.new);

  /// Where a new take is captured before the patient decides to keep it.
  /// This is the only unencrypted recording file, and it is removed when the
  /// take is kept or discarded.
  Future<String> draftPath() async {
    final dir = await _directory();
    return '${dir.path}${Platform.pathSeparator}draft.wav';
  }

  /// Permanent encrypted location for a recording, e.g.
  /// `P001_baseline_sustained-a_t1_20261008T101500.wav.vpa`.
  Future<String> permanentPath({
    required String participantCode,
    required RecordingType type,
    required RecordingTask task,
    required DateTime createdAt,
    int trial = 1,
  }) async {
    final dir = await _directory();
    final name =
        '${participantCode}_${type.slug}_${task.slug}_t${trial}_'
        '${_stamp.format(createdAt)}.wav${RecordingVault.extension}';
    return '${dir.path}${Platform.pathSeparator}$name';
  }

  /// Encrypts a reviewed draft to its [permanentPath] and removes the draft.
  Future<String> keep(
    String draftPath, {
    required String participantCode,
    required RecordingType type,
    required RecordingTask task,
    required DateTime createdAt,
    int trial = 1,
  }) async {
    final target = await permanentPath(
      participantCode: participantCode,
      type: type,
      task: task,
      createdAt: createdAt,
      trial: trial,
    );
    await _vault.encryptFile(draftPath, target);
    return target;
  }

  /// Writes generated audio straight to encrypted storage.
  Future<void> writeEncrypted(Uint8List wav, String path) =>
      _vault.writeEncrypted(wav, path);

  Future<void> discard(String path) => guard(() async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }, RecordingFailure.new);
}
