import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:melo/core/errors/app_failure.dart';
import 'package:melo/features/motor/data/motor_photo_picker.dart';

class _Camera extends ImagePicker {
  XFile? result;
  bool fail = false;
  ImageSource? source;

  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
    CameraDevice preferredCameraDevice = CameraDevice.rear,
    bool requestFullMetadata = true,
  }) async {
    this.source = source;
    expect(maxWidth, isNull);
    expect(maxHeight, isNull);
    expect(imageQuality, isNull);
    if (fail) throw const FileSystemException('Camera unavailable');
    return result;
  }
}

void main() {
  late Directory directory;
  late _Camera camera;
  late MotorPhotoPicker picker;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('motor-camera-');
    camera = _Camera();
    picker = MotorPhotoPicker(imagePicker: camera);
  });

  tearDown(() => directory.delete(recursive: true));

  test(
    'camera returns exact original bytes and removes its cached file',
    () async {
      final original = List<int>.generate(4096, (i) => i % 256);
      final file = await File(
        '${directory.path}/capture.jpg',
      ).writeAsBytes(original);
      camera.result = XFile(file.path);
      expect(await picker.capture(), original);
      expect(camera.source, ImageSource.camera);
      expect(await file.exists(), isFalse);
    },
  );

  test('cancelling the camera leaves no photo to upload', () async {
    expect(await picker.capture(), isNull);
  });

  test(
    'oversized original is rejected without recompression and cleaned up',
    () async {
      final file = File('${directory.path}/large.jpg');
      final handle = await file.open(mode: FileMode.write);
      await handle.truncate(20 * 1024 * 1024 + 1);
      await handle.close();
      camera.result = XFile(file.path);
      await expectLater(
        picker.capture(),
        throwsA(
          isA<MediaFailure>().having(
            (failure) => failure.problem,
            'problem',
            MediaProblem.tooLarge,
          ),
        ),
      );
      expect(await file.exists(), isFalse);
    },
  );

  test('camera errors become a clear camera failure', () async {
    camera.fail = true;
    await expectLater(
      picker.capture(),
      throwsA(
        isA<MediaFailure>().having(
          (failure) => failure.problem,
          'problem',
          MediaProblem.cameraUnavailable,
        ),
      ),
    );
  });
}
