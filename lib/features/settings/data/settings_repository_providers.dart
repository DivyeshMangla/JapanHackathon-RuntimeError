import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/backend_client.dart';
import '../domain/study_settings.dart';
import 'backend_settings_repository.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>(
  (ref) => BackendSettingsRepository(ref.watch(backendClientProvider)),
);
