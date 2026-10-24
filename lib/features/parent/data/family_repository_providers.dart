import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/backend_client.dart';
import '../domain/family_repository.dart';
import 'backend_family_repository.dart';

final familyRepositoryProvider = Provider<FamilyRepository>(
  (ref) => BackendFamilyRepository(ref.watch(backendClientProvider)),
);
