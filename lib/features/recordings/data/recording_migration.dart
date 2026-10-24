import 'dart:io';

import '../domain/recording_repository.dart';
import 'recording_vault.dart';

/// Encrypts any recording still stored as plain WAV, from installs made
/// before encryption at rest, and points its record at the encrypted file.
/// Safe to run on every launch: encrypted recordings are skipped.
Future<int> encryptLegacyRecordings(
  RecordingRepository repository,
  RecordingVault vault,
) async {
  var migrated = 0;
  for (final recording in await repository.all()) {
    if (RecordingVault.isEncrypted(recording.filePath)) continue;
    if (!await File(recording.filePath).exists()) continue;

    final target = '${recording.filePath}${RecordingVault.extension}';
    await vault.encryptFile(recording.filePath, target);
    await repository.save(recording.withFilePath(target));
    migrated++;
  }
  return migrated;
}
