import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/backend_client.dart';
import '../domain/motor_repository.dart';
import 'backend_motor_repository.dart';
import 'motor_photo_picker.dart';

final motorRepositoryProvider = Provider<MotorRepository>(
  (ref) => BackendMotorRepository(ref.watch(backendClientProvider)),
);

final motorPhotoPickerProvider = Provider<MotorPhotoPicker>(
  (ref) => const MotorPhotoPicker(),
);
