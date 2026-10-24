import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../settings/presentation/controllers/study_settings_controller.dart';
import '../../domain/study_period.dart';

/// The probe window runs from the patient's account creation, since no
/// separate intervention start is recorded.
final studyPeriodProvider = FutureProvider.family<StudyPeriod, String>((
  ref,
  patientId,
) async {
  final patient = await ref.watch(userByIdProvider(patientId).future);
  final settings = await ref.watch(studySettingsProvider.future);
  return StudyPeriod(
    start: patient?.createdAt ?? DateTime.now(),
    weeks: settings.studyWeeks,
  );
});
