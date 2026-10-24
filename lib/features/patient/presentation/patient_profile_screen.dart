import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../../shared/widgets/seal_mark.dart';
import '../../auth/domain/user.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';
import '../../recordings/presentation/controllers/recording_controllers.dart';
import 'patient_recordings_screen.dart';
import 'profile_progress.dart';
import 'profile_reminders.dart';

class PatientProfileScreen extends ConsumerStatefulWidget {
  const PatientProfileScreen({super.key, this.initialSection});
  final String? initialSection;
  @override
  ConsumerState<PatientProfileScreen> createState() =>
      _PatientProfileScreenState();
}

class _PatientProfileScreenState extends ConsumerState<PatientProfileScreen> {
  final _progress = GlobalKey();
  final _reminders = GlobalKey();

  bool _anchored = false;

  void _openSection() {
    if (_anchored || widget.initialSection == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _anchored) return;
      final target = switch (widget.initialSection) {
        'progress' => _progress.currentContext,
        'reminders' => _reminders.currentContext,
        _ => null,
      };
      if (target != null) {
        Scrollable.ensureVisible(target);
        _anchored = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final l10n = context.l10n;
    // Wait for preceding sections to settle before positioning reminders.
    final activity = ref.watch(patientActivityProvider(user.id));
    final recordings = ref.watch(patientRecordingsProvider(user.id));
    if (widget.initialSection == 'progress' ||
        (!activity.isLoading && !recordings.isLoading)) {
      _openSection();
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.profileTitle),
        actions: [
          IconButton(
            tooltip: l10n.profileAccount,
            icon: const Icon(LucideIcons.settings),
            onPressed: () => _showAccount(context, user),
          ),
          const SizedBox(width: AppSpacing.md),
        ],
      ),
      body: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            maxWidth: AppSpacing.maxContentWidth,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.gutter),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Identity(user: user),
                const SizedBox(height: AppSpacing.xl),
                SectionLabel(l10n.profileProgress, key: _progress),
                ProfileProgress(userId: user.id),
                const SizedBox(height: AppSpacing.lg),
                SectionLabel(l10n.profileRecentRecordings),
                ProfileRecordings(userId: user.id, limit: 3),
                const SizedBox(height: AppSpacing.lg),
                SectionLabel(l10n.profileReminders, key: _reminders),
                ProfileReminders(userId: user.id),
                const SizedBox(height: AppSpacing.lg),
                InkCard(
                  child: Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(LucideIcons.bookOpen),
                        title: Text(l10n.profileLearnLink),
                        trailing: const Icon(LucideIcons.chevronRight),
                        onTap: () => context.go(AppRoutes.patientLearn),
                      ),
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(LucideIcons.settings),
                        title: Text(l10n.profileAccount),
                        trailing: const Icon(LucideIcons.chevronRight),
                        onTap: () => _showAccount(context, user),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton.icon(
                  label: Text(l10n.signOut),
                  icon: const Icon(LucideIcons.logOut),
                  onPressed: () => runWithFailureMessage(
                    context,
                    () => ref.read(authControllerProvider.notifier).signOut(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _showAccount(BuildContext context, User user) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionLabel(context.l10n.profileAccount),
              Text(user.name, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AppSpacing.md),
              Text(
                context.l10n.loginEmail,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              SelectableText(user.email),
              if (user.participantCode != null) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  context.l10n.profileParticipantCode,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                SelectableText(user.participantCode!),
              ],
            ],
          ),
        ),
      ),
    );

class _Identity extends ConsumerWidget {
  const _Identity({required this.user});
  final User user;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final therapist = user.therapistId == null
        ? null
        : ref.watch(userByIdProvider(user.therapistId!)).value;
    return Row(
      children: [
        const SealMark(size: 56, icon: LucideIcons.user),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(user.name, style: text.titleLarge),
              if (user.participantCode != null)
                Text(
                  '${context.l10n.profileParticipantCode}: ${user.participantCode}',
                  style: text.bodySmall,
                ),
              if (therapist != null)
                Text(
                  '${context.l10n.profileTherapist}: ${therapist.name}',
                  style: text.bodySmall,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
