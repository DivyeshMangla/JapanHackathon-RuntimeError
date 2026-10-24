import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/domain/user.dart';
import 'controllers/admin_controllers.dart';

class PeopleScreen extends ConsumerStatefulWidget {
  const PeopleScreen({super.key});

  @override
  ConsumerState<PeopleScreen> createState() => _PeopleScreenState();
}

class _PeopleScreenState extends ConsumerState<PeopleScreen> {
  UserRole _role = UserRole.patient;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final people = ref.watch(usersByRoleProvider(_role));
    final therapists =
        ref.watch(usersByRoleProvider(UserRole.therapist)).value ?? const [];
    final patients =
        ref.watch(usersByRoleProvider(UserRole.patient)).value ?? const [];
    final isPatients = _role == UserRole.patient;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.peopleTitle)),
      body: PageList(
        children: [
          ChoicePills<UserRole>(
            options: const [UserRole.patient, UserRole.therapist],
            selected: _role,
            labelOf: (r) => r == UserRole.patient
                ? l10n.patientsFilter
                : l10n.therapistsFilter,
            onSelected: (r) => setState(() => _role = r),
          ),
          const SizedBox(height: AppSpacing.lg),
          PrimaryButton(
            label: isPatients ? l10n.addPatient : l10n.addTherapist,
            icon: LucideIcons.userPlus,
            onPressed: () => context.go(AppRoutes.adminNewUser(_role)),
          ),
          const SizedBox(height: AppSpacing.lg),
          AsyncView(
            value: people,
            data: (people) => people.isEmpty
                ? EmptyState(
                    icon: LucideIcons.users,
                    title: l10n.noPeopleTitle,
                    message: l10n.noPeopleBody,
                  )
                : Column(
                    children: [
                      for (final person in people)
                        Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: isPatients
                              ? _PatientCard(
                                  patient: person,
                                  therapists: therapists,
                                )
                              : _TherapistCard(
                                  therapist: person,
                                  caseload: patients
                                      .where((p) => p.therapistId == person.id)
                                      .length,
                                ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PatientCard extends ConsumerWidget {
  const _PatientCard({required this.patient, required this.therapists});

  final User patient;
  final List<User> therapists;

  Future<void> _reassign(BuildContext context, WidgetRef ref) async {
    final chosen = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) =>
          _TherapistChooser(patient: patient, therapists: therapists),
    );
    if (chosen == null || chosen == patient.therapistId || !context.mounted) {
      return;
    }
    await runWithFailureMessage(
      context,
      () => ref.read(adminActionsProvider).reassign(patient, chosen),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final therapist = therapists
        .where((t) => t.id == patient.therapistId)
        .firstOrNull;
    return InkCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.participantCode ?? '',
                  style: AppTypography.participantCode,
                ),
                Text(patient.name, style: text.titleMedium),
                Text(
                  therapist == null
                      ? l10n.noTherapistAssigned
                      : l10n.therapistNamed(therapist.name),
                  style: text.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => _reassign(context, ref),
            child: Text(l10n.reassign),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet listing therapists; pops with the chosen therapist's id.
class _TherapistChooser extends StatelessWidget {
  const _TherapistChooser({required this.patient, required this.therapists});

  final User patient;
  final List<User> therapists;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.gutter,
          0,
          AppSpacing.gutter,
          AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.assignPatientTo(patient.participantCode ?? ''),
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final t in therapists)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                child: InkCard(
                  onTap: () => Navigator.of(context).pop(t.id),
                  child: Row(
                    children: [
                      Expanded(child: Text(t.name)),
                      if (t.id == patient.therapistId)
                        const Icon(
                          LucideIcons.circleCheck,
                          size: 20,
                          color: AppColors.seal,
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TherapistCard extends StatelessWidget {
  const _TherapistCard({required this.therapist, required this.caseload});

  final User therapist;
  final int caseload;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(therapist.name, style: text.titleMedium),
                Text(therapist.email, style: text.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('$caseload', style: text.headlineSmall),
              Text(context.l10n.patientCount(caseload), style: text.bodySmall),
            ],
          ),
        ],
      ),
    );
  }
}
