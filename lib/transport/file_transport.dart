import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'sync_envelope.dart';
import 'sync_transport.dart';

class FileTransport implements SyncTransport {
  /// Only plugin-owned caches are removed; user-selected originals are retained.
  static Future<void> clearCachedTransfers() async {
    final directory = await getTemporaryDirectory();
    final export = File('${directory.path}/voice-setup-transfer.json');
    if (await export.exists()) await export.delete();
    final shared = Directory('${directory.path}/share_plus');
    if (await shared.exists()) await shared.delete(recursive: true);
    await FilePicker.clearTemporaryFiles();
  }

  @override
  Future<bool> send(SyncEnvelope envelope) async {
    final folder = await getTemporaryDirectory();
    final file = File('${folder.path}/voice-setup-transfer.json');
    await file.writeAsString(envelope.encode(), flush: true);
    try {
      final result = await SharePlus.instance.share(
        ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
      );
      return result.status == ShareResultStatus.success;
    } finally {
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<SyncEnvelope?> receive() async {
    final picked = await FilePicker.pickFile(type: FileType.any);
    if (picked == null) return null;
    try {
      final path = picked.path;
      if (path == null) throw const FormatException('Unable to open file');
      final file = File(path);
      if (await file.length() > 1024 * 1024) {
        throw const FormatException('Package too large');
      }
      return SyncEnvelope.decode(utf8.decode(await file.readAsBytes()));
    } finally {
      await FilePicker.clearTemporaryFiles();
    }
  }
}
