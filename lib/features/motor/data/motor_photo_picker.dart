import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../../../core/logging/app_logger.dart';

const _maxPhotoBytes = 20 * 1024 * 1024;

/// Keeps the original capture bytes for preview and delivery to the therapist.
class MotorPhotoPicker {
  const MotorPhotoPicker({ImagePicker? imagePicker})
    : _imagePicker = imagePicker;

  final ImagePicker? _imagePicker;

  Future<Uint8List?> pick() => guard(() async {
    try {
      final selected = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png'],
      );
      if (selected == null) return null;
      final path = selected.path;
      if (path == null) throw const MediaFailure(MediaProblem.unavailable);
      return await _readOriginal(XFile(path));
    } finally {
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (error) {
        AppLogger.warning('Photo picker cache cleanup failed', error);
      }
    }
  }, (error) => MediaFailure(MediaProblem.unavailable, error));

  Future<Uint8List?> capture() => guard(() async {
    XFile? captured;
    try {
      // Omitting quality/size options preserves the camera's original file.
      captured = await (_imagePicker ?? ImagePicker()).pickImage(
        source: ImageSource.camera,
      );
      return captured == null ? null : await _readOriginal(captured);
    } finally {
      // image_picker stages camera captures in the app's temporary cache.
      if (captured != null) {
        try {
          await File(captured.path).delete();
        } catch (error) {
          AppLogger.warning('Camera photo cache cleanup failed', error);
        }
      }
    }
  }, (error) => MediaFailure(MediaProblem.cameraUnavailable, error));

  Future<Uint8List> _readOriginal(XFile file) async {
    if (await file.length() > _maxPhotoBytes) {
      throw const MediaFailure(MediaProblem.tooLarge);
    }
    return file.readAsBytes();
  }
}
