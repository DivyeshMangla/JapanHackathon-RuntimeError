import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/async_view.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../therapist/presentation/controllers/caseload_controllers.dart';
import '../../therapist/presentation/participant_detail_screen.dart';
import '../data/word_repository_providers.dart';
import 'child_word_page.dart';
import 'therapist_words_page.dart';

/// The signed-in child's word practice.
class ChildWordsScreen extends ConsumerWidget {
  const ChildWordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final child = ref.watch(currentUserProvider);
    return ChildWordPage(
      repository: ref.watch(wordRepositoryProvider(child.id)),
    );
  }
}

/// Word assignments and attempts for one child on the therapist's caseload.
class TherapistWordsScreen extends ConsumerWidget {
  const TherapistWordsScreen({super.key, required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final participant = ref.watch(caseloadParticipantProvider(patientId));
    final found = participant.value;
    if (found != null) {
      return TherapistWordsPage(
        repository: ref.watch(wordRepositoryProvider(patientId)),
        childName: found.patient.name,
      );
    }
    return Scaffold(
      appBar: AppBar(),
      body: AsyncView(
        value: participant,
        data: (_) => const ParticipantNotFound(),
      ),
    );
  }
}
