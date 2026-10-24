import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/questionnaire.dart';
import 'controllers/questionnaire_controllers.dart';

/// The participant self-report record: the baseline adherence assessment
/// (week 0) or one study week's practice.
class SelfReportScreen extends ConsumerStatefulWidget {
  const SelfReportScreen({super.key, required this.week});

  final int week;

  @override
  ConsumerState<SelfReportScreen> createState() => _SelfReportScreenState();
}

class _SelfReportScreenState extends ConsumerState<SelfReportScreen> {
  static const _dayOptions = [0, 1, 2, 3, 4, 5, 6, 7];

  final _note = TextEditingController();
  int? _days;
  PracticeBarrier? _barrier;
  bool _attempted = false;
  bool _saving = false;

  bool get _isBaseline => widget.week == AdherenceSelfReport.baselineWeek;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final days = _days;
    final barrier = _barrier;
    if (days == null || barrier == null) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _saving = true);
    final l10n = context.l10n;
    final saved = await runWithFailureMessage(
      context,
      () => ref
          .read(questionnaireActionsProvider)
          .submitSelfReport(
            patientId: ref.read(currentUserProvider).id,
            week: widget.week,
            daysPractised: days,
            barrier: barrier,
            note: _note.text,
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.questionnaireThanks)));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final error = text.bodySmall?.copyWith(color: AppColors.error);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _isBaseline
              ? l10n.taskBaselineReport
              : l10n.taskWeeklyReport(widget.week),
        ),
      ),
      body: PageList(
        children: [
          Text(
            _isBaseline
                ? l10n.selfReportBaselineIntro
                : l10n.selfReportWeeklyIntro,
            style: text.bodyLarge,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.selfReportDaysQuestion, style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ChoicePills<int?>(
            options: _dayOptions,
            selected: _days,
            labelOf: (d) => '$d',
            semanticLabelOf: (d) => l10n.dayCount(d!),
            onSelected: _saving ? null : (d) => setState(() => _days = d),
          ),
          if (_attempted && _days == null)
            Text(l10n.answerRequired, style: error),
          const SizedBox(height: AppSpacing.lg),
          Text(l10n.selfReportBarrierQuestion, style: text.titleMedium),
          const SizedBox(height: AppSpacing.sm),
          ChoicePills<PracticeBarrier?>(
            options: PracticeBarrier.values,
            selected: _barrier,
            labelOf: (b) => l10n.barrierLabel(b!),
            onSelected: _saving ? null : (b) => setState(() => _barrier = b),
          ),
          if (_attempted && _barrier == null)
            Text(l10n.answerRequired, style: error),
          const SizedBox(height: AppSpacing.lg),
          LabeledTextField(
            label: l10n.selfReportNoteLabel,
            controller: _note,
            maxLines: 3,
            enabled: !_saving,
          ),
          const SizedBox(height: AppSpacing.xl),
          PrimaryButton(
            label: _saving ? l10n.submitting : l10n.submitAnswers,
            icon: LucideIcons.check,
            onPressed: _saving ? null : _submit,
          ),
        ],
      ),
    );
  }
}
