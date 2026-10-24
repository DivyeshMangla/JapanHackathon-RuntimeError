import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/settings_repository_providers.dart';
import '../../domain/study_settings.dart';

final studySettingsProvider =
    AsyncNotifierProvider<StudySettingsController, StudySettings>(
      StudySettingsController.new,
    );

class StudySettingsController extends AsyncNotifier<StudySettings> {
  @override
  Future<StudySettings> build() => ref.read(settingsRepositoryProvider).load();

  Future<void> save(StudySettings settings) async {
    await ref.read(settingsRepositoryProvider).save(settings);
    state = AsyncData(settings);
  }
}
