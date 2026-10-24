import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../core/errors/connected_failure.dart';
import '../../../core/logging/app_logger.dart';

class MotorPhotoPicker {
  const MotorPhotoPicker();

  Future<Uint8List?> pick() async {
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (selected == null) return null;
      final path = selected.path;
      if (path == null) {
        throw const ConnectedFailure(ConnectedFailureReason.photoUnavailable);
      }
      final file = File(path);
      if (await file.length() > 6 * 1024 * 1024) {
        throw const ConnectedFailure(ConnectedFailureReason.photoTooLarge);
      }
      return await file.readAsBytes();
    } on ConnectedFailure {
      rethrow;
    } catch (_) {
      throw const ConnectedFailure(ConnectedFailureReason.photoUnavailable);
    } finally {
      // Mobile pickers may cache an unencrypted copy. Keep only the in-memory preview.
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (_) {
        AppLogger.warning('Photo picker cache cleanup failed');
      }
    }
  }
}
