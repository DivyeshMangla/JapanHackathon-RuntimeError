import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/errors/app_failure.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../settings/domain/study_settings.dart';
import '../../settings/presentation/controllers/study_settings_controller.dart';
import 'controllers/admin_controllers.dart';

class StudySettingsScreen extends ConsumerWidget {
  const StudySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(studySettingsProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: AsyncView(
        value: settings,
        data: (settings) => PageList(
          children: [
            _SettingsForm(initial: settings),
            const SizedBox(height: AppSpacing.xl),
            const _ExportSection(),
            const SizedBox(height: AppSpacing.lg),
            SectionLabel(l10n.auditSection),
            InkCard(
              onTap: () => context.go(AppRoutes.adminAccessLog),
              child: Row(
                children: [
                  const Icon(LucideIcons.scrollText, size: 20),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      l10n.accessLogTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const Icon(LucideIcons.chevronRight, size: 20),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.xl),
            SecondaryButton(
              label: l10n.signOut,
              icon: LucideIcons.logOut,
              onPressed: () => runWithFailureMessage(
                context,
                () => ref.read(authControllerProvider.notifier).signOut(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExportSection extends ConsumerStatefulWidget {
  const _ExportSection();

  @override
  ConsumerState<_ExportSection> createState() => _ExportSectionState();
}

class _ExportSectionState extends ConsumerState<_ExportSection> {
  ExportKind? _running;

  Future<void> _export(ExportKind kind) async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _running = kind);
    try {
      final saved = await ref
          .read(exportActionsProvider)
          .export(kind, saveDialogTitle: l10n.exportSaveTitle);
      if (saved != null) {
        messenger.showSnackBar(
          SnackBar(content: Text(l10n.exportSaved(saved))),
        );
      }
    } on AppFailure catch (failure) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.failureMessage(failure))),
      );
    } finally {
      if (mounted) setState(() => _running = null);
    }
  }

  static String _exportLabel(AppLocalizations l10n, ExportKind kind) =>
      switch (kind) {
        ExportKind.recordings => l10n.exportRecordings,
        ExportKind.usageLog => l10n.exportUsageLog,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.exportSection),
        Text(l10n.exportHelp, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: AppSpacing.md),
        for (final kind in ExportKind.values)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: SecondaryButton(
              label: _running == kind ? l10n.saving : _exportLabel(l10n, kind),
              icon: LucideIcons.fileDown,
              onPressed: _running == null ? () => _export(kind) : null,
            ),
          ),
      ],
    );
  }
}

class _SettingsForm extends ConsumerStatefulWidget {
  const _SettingsForm({required this.initial});

  final StudySettings initial;

  @override
  ConsumerState<_SettingsForm> createState() => _SettingsFormState();
}

class _SettingsFormState extends ConsumerState<_SettingsForm> {
  late StudySettings _draft = widget.initial;
  bool _saving = false;

  bool get _changed =>
      _draft.probeIntervalDays != widget.initial.probeIntervalDays ||
      _draft.studyWeeks != widget.initial.studyWeeks;

  Future<void> _save() async {
    setState(() => _saving = true);
    final succeeded = await runWithFailureMessage(
      context,
      () => ref.read(studySettingsProvider.notifier).save(_draft),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (succeeded) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(context.l10n.settingsSaved)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ProbeScheduleFields(
          draft: _draft,
          onChanged: (draft) => setState(() => _draft = draft),
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: _saving ? l10n.saving : l10n.saveSettings,
          icon: LucideIcons.check,
          onPressed: _saving || !_changed ? null : _save,
        ),
      ],
    );
  }
}

class _ProbeScheduleFields extends StatelessWidget {
  const _ProbeScheduleFields({required this.draft, required this.onChanged});

  final StudySettings draft;
  final ValueChanged<StudySettings> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.probeScheduleSection),
        Text(l10n.probeEvery, style: text.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        ChoicePills<int>(
          options: const [7, 14],
          selected: draft.probeIntervalDays,
          labelOf: (d) => d == 7 ? l10n.probeWeekly : l10n.probeFortnightly,
          onSelected: (d) => onChanged(draft.copyWith(probeIntervalDays: d)),
        ),
        const SizedBox(height: AppSpacing.md),
        Text(l10n.studyLength, style: text.bodyMedium),
        const SizedBox(height: AppSpacing.sm),
        ChoicePills<int>(
          options: const [4, 6, 8],
          selected: draft.studyWeeks,
          labelOf: l10n.studyWeeksOption,
          onSelected: (w) => onChanged(draft.copyWith(studyWeeks: w)),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(l10n.probeScheduleHelp, style: text.bodySmall),
      ],
    );
  }
}
