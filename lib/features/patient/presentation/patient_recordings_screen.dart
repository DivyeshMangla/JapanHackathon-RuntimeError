import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../recordings/presentation/controllers/recording_controllers.dart';
import '../../recordings/presentation/recording_tile.dart';

class PatientRecordingsScreen extends ConsumerWidget {
  const PatientRecordingsScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: Text(context.l10n.progressRecordings)),
    body: PageList(
      children: [ProfileRecordings(userId: ref.watch(currentUserProvider).id)],
    ),
  );
}

/// The overview stays short; the separate history retains every recording.
class ProfileRecordings extends ConsumerWidget {
  const ProfileRecordings({super.key, required this.userId, this.limit});
  final String userId;
  final int? limit;

  @override
  Widget build(BuildContext context, WidgetRef ref) => AsyncView(
    value: ref.watch(patientRecordingsProvider(userId)),
    loading: const Skeleton(height: 120),
    data: (recordings) {
      final l10n = context.l10n;
      if (recordings.isEmpty) {
        return EmptyState(
          icon: LucideIcons.micOff,
          title: l10n.progressNoRecordingsTitle,
          message: l10n.progressNoRecordingsBody,
          actionLabel: l10n.progressMakeRecording,
          onAction: () => context.go(AppRoutes.patientRecord),
        );
      }
      final sorted = [...recordings]
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final recording in sorted.take(limit ?? sorted.length))
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: RecordingTile(recording: recording),
            ),
          if (limit != null && sorted.length > limit!)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => context.push(AppRoutes.patientRecordings),
                child: Text(l10n.profileViewAll),
              ),
            ),
        ],
      );
    },
  );
}
