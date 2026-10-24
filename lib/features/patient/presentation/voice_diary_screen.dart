import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/choice_pills.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../../exercises/domain/patient_activity.dart';
import '../../exercises/domain/voice_use_entry.dart';
import '../../exercises/presentation/controllers/exercise_controllers.dart';

/// The voice-use monitoring entry that completes one session of a
/// voice-diary exercise.
class VoiceDiaryScreen extends ConsumerWidget {
  const VoiceDiaryScreen({super.key, required this.exerciseId});

  final String exerciseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final user = ref.watch(currentUserProvider);
    final activity = ref.watch(patientActivityProvider(user.id));
    return Scaffold(
      appBar: AppBar(title: Text(l10n.voiceDiaryTitle)),
      body: AsyncView(
        value: activity,
        data: (activity) {
          final item = activity.todayItems
              .where((i) => i.exercise.id == exerciseId)
              .firstOrNull;
          if (item == null || item.isDone) {
            return EmptyState(
              icon: LucideIcons.notebookPen,
              title: l10n.voiceDiaryNothingDueTitle,
              message: l10n.voiceDiaryNothingDueBody,
            );
          }
          return _DiaryForm(patientId: user.id, item: item);
        },
      ),
    );
  }
}

class _DiaryForm extends ConsumerStatefulWidget {
  const _DiaryForm({required this.patientId, required this.item});

  final String patientId;
  final DayItem item;

  @override
  ConsumerState<_DiaryForm> createState() => _DiaryFormState();
}

class _DiaryFormState extends ConsumerState<_DiaryForm> {
  static final _fatigueScale = [
    for (var v = 0; v <= VoiceUseEntry.maxFatigue; v++) v,
  ];

  final _note = TextEditingController();
  SpeakingTime? _speakingTime;
  int? _fatigue;
  Set<VoiceSituation> _situations = const {};
  bool _attempted = false;
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final speakingTime = _speakingTime;
    final fatigue = _fatigue;
    if (speakingTime == null || fatigue == null) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _saving = true);
    final l10n = context.l10n;
    final saved = await runWithFailureMessage(
      context,
      () => ref
          .read(completionActionsProvider)
          .logVoiceUse(
            widget.patientId,
            widget.item,
            speakingTime: speakingTime,
            fatigue: fatigue,
            situations: _situations,
            note: _note.text,
          ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.voiceDiarySaved)));
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final error = text.bodySmall?.copyWith(color: AppColors.error);
    return PageList(
      children: [
        Text(l10n.voiceDiaryIntro, style: text.bodyLarge),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.voiceDiarySpeakingQuestion, style: text.titleMedium),
        const SizedBox(height: AppSpacing.sm),
        ChoicePills<SpeakingTime?>(
          options: SpeakingTime.values,
          selected: _speakingTime,
          labelOf: (t) => l10n.speakingTimeLabel(t!),
          onSelected: _saving ? null : (t) => setState(() => _speakingTime = t),
        ),
        if (_attempted && _speakingTime == null)
          Text(l10n.answerRequired, style: error),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.voiceDiaryFatigueQuestion, style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.voiceDiaryFatigueAnchors, style: text.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        ChoicePills<int?>(
          options: _fatigueScale,
          selected: _fatigue,
          labelOf: (v) => '$v',
          semanticLabelOf: (v) => l10n.fatigueSemantic(v!),
          onSelected: _saving ? null : (v) => setState(() => _fatigue = v),
        ),
        if (_attempted && _fatigue == null)
          Text(l10n.answerRequired, style: error),
        const SizedBox(height: AppSpacing.lg),
        Text(l10n.voiceDiarySituationsQuestion, style: text.titleMedium),
        const SizedBox(height: AppSpacing.xs),
        Text(l10n.chooseAllThatApply, style: text.bodySmall),
        const SizedBox(height: AppSpacing.sm),
        MultiChoicePills<VoiceSituation>(
          options: VoiceSituation.values,
          selected: _situations,
          labelOf: l10n.situationLabel,
          onChanged: _saving ? null : (v) => setState(() => _situations = v),
        ),
        const SizedBox(height: AppSpacing.lg),
        LabeledTextField(
          label: l10n.voiceDiaryNoteLabel,
          controller: _note,
          maxLines: 3,
          enabled: !_saving,
        ),
        const SizedBox(height: AppSpacing.xl),
        PrimaryButton(
          label: _saving ? l10n.saving : l10n.voiceDiarySave,
          icon: LucideIcons.check,
          onPressed: _saving ? null : _save,
        ),
      ],
    );
  }
}
