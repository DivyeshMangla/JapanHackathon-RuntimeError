import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:file_picker/file_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../../../core/logging/app_logger.dart';

/// Camera photos are scaled down before sending, so a larger original is
/// still usable.
const _maxPickedBytes = 20 * 1024 * 1024;

/// Longest side of the photo sent to the care service: enough to read a
/// child's lines, and small enough that the PNG stays under the service's
/// 6 MB limit.
const _maxSentSide = 1280;

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
      if (await file.length() > _maxPickedBytes) {
        throw const MediaFailure(MediaProblem.tooLarge);
      }
      return await _reencode(await file.readAsBytes());
    } finally {
      // Mobile pickers may cache an unencrypted copy.
      try {
        await FilePicker.clearTemporaryFiles();
      } catch (error) {
        AppLogger.warning('Photo picker cache cleanup failed', error);
      }
    }
  }, (error) => MediaFailure(MediaProblem.unavailable, error));

  /// Camera JPEGs often carry data after the image (motion photos, maker
  /// trailers) that the care service rejects, plus location metadata. A
  /// freshly encoded PNG has neither.
  Future<Uint8List> _reencode(Uint8List original) async {
    final buffer = await ui.ImmutableBuffer.fromUint8List(original);
    final codec = await ui.instantiateImageCodecWithSize(
      buffer,
      getTargetSize: (width, height) {
        final scale = _maxSentSide / math.max(width, height);
        return scale >= 1
            ? ui.TargetImageSize(width: width, height: height)
            : ui.TargetImageSize(
                width: (width * scale).round(),
                height: (height * scale).round(),
              );
      },
    );
    final frame = await codec.getNextFrame();
    codec.dispose();
    try {
      final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
      if (png == null) throw const MediaFailure(MediaProblem.unavailable);
      return png.buffer.asUint8List();
    } finally {
      frame.image.dispose();
    }
  }
}
