import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../../../core/logging/app_logger.dart';

/// The care service accepts photos up to this size.
const _maxPhotoBytes = 6 * 1024 * 1024;

/// Lets the parent pick a photo of the child's drawing. Only the in-memory
/// copy is kept.
class MotorPhotoPicker {
  const MotorPhotoPicker();

  Future<Uint8List?> pick() => guard(() async {
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (selected == null) return null;
      final path = selected.path;
      if (path == null) throw const MediaFailure(MediaProblem.unavailable);
      final file = File(path);
      if (await file.length() > _maxPhotoBytes) {
        throw const MediaFailure(MediaProblem.tooLarge);
      }
      return await file.readAsBytes();
    } finally {
      // Mobile pickers may cache an unencrypted copy.
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (error) {
        AppLogger.warning('Photo picker cache cleanup failed', error);
      }
    }
  }, (error) => MediaFailure(MediaProblem.unavailable, error));
}
