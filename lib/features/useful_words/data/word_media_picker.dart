import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';

class WordMedia {
  const WordMedia(this.bytes, this.mime);
  final Uint8List bytes;
  final String mime;
}

class WordMediaPicker {
  Future<WordMedia?> choose({required bool picture}) => guard(() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: picture ? ['png', 'jpg', 'jpeg'] : ['wav'],
    );
    if (file == null) return null;
    final limit = picture ? 1500000 : 12 * 1024 * 1024;
    final size = await file.length();
    if (size == null || size > limit) {
      throw const MediaFailure(MediaProblem.tooLarge);
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > limit) throw const MediaFailure(MediaProblem.tooLarge);
    return WordMedia(
      bytes,
      picture
          ? (file.extension?.toLowerCase() == 'png'
                ? 'image/png'
                : 'image/jpeg')
          : 'audio/wav',
    );
  }, (error) => MediaFailure(MediaProblem.unavailable, error));
}
