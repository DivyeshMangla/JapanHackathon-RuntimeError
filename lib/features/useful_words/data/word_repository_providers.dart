import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/errors/guard.dart';
import '../../../core/network/backend_client.dart';
import '../../../core/storage/local_database.dart';
import 'word_repository.dart';

/// Word practice for one child, over the care service client, with the
/// unsent attempt in the device's encrypted word-draft box.
final wordRepositoryProvider = Provider.family<WordRepository, String>((
  ref,
  patientId,
) {
  final client = ref.watch(backendClientProvider);
  final drafts = ref.watch(localDatabaseProvider).wordDrafts;
  return WordRepository(
    patientId,
    (path, {method = 'GET', data}) => switch (method) {
      'POST' => client.post(path, body: data),
      'PUT' => client.put(path, body: data ?? const {}),
      _ => client.get(path),
    },
    () => drafts.get(patientId),
    (value) => guardStorage(
      () => value == null
          ? drafts.delete(patientId)
          : drafts.put(patientId, value),
    ),
  );
});
