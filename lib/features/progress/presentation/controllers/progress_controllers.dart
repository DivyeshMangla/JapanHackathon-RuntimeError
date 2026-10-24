import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/backend_client.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../data/backend_family_progress_repository.dart';
import '../../domain/family_progress.dart';

final familyProgressRepositoryProvider = Provider<FamilyProgressRepository>(
  (ref) => BackendFamilyProgressRepository(ref.watch(backendClientProvider)),
);

final familyProgressProvider = FutureProvider.autoDispose
    .family<FamilyProgress, String>((ref, childId) {
      // Child mode replaces the parent's session. Never retain a family view
      // across that transition, even when the same child id is requested.
      ref.watch(authControllerProvider.select((session) => session.value?.id));
      return ref.watch(familyProgressRepositoryProvider).load(childId);
    }, retry: (_, _) => null);
