import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/labeled_text_field.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/questionnaire.dart';
import 'controllers/questionnaire_controllers.dart';
import 'likert_question.dart';

/// Structured participant feedback (user satisfaction) with open comments
/// for thematic analysis.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _ratings = <SatisfactionItem, int>{};
  final _liked = TextEditingController();
  final _difficult = TextEditingController();
  final _suggestions = TextEditingController();
  bool _attempted = false;
  bool _saving = false;

  @override
  void dispose() {
    _liked.dispose();
    _difficult.dispose();
    _suggestions.dispose();
    super.dispose();
  }

  int get _unanswered => SatisfactionItem.values.length - _ratings.length;

  Future<void> _submit() async {
    if (_unanswered > 0) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _saving = true);
    final l10n = context.l10n;
    final saved = await runWithFailureMessage(
      context,
      () => ref
          .read(questionnaireActionsProvider)
          .submitFeedback(
            patientId: ref.read(currentUserProvider).id,
            ratings: _ratings,
            likedMost: _liked.text,
            difficulties: _difficult.text,
            suggestions: _suggestions.text,
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
    return Scaffold(
      appBar: AppBar(title: Text(l10n.taskFeedback)),
      body: PageList(
        children: [
          Text(l10n.feedbackIntro, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          for (final (index, item) in SatisfactionItem.values.indexed)
            LikertQuestion(
              number: index + 1,
              statement: l10n.satisfactionStatement(item),
              value: _ratings[item],
              showMissing: _attempted,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _ratings[item] = v),
            ),
          _OpenQuestions(
            liked: _liked,
            difficult: _difficult,
            suggestions: _suggestions,
            enabled: !_saving,
          ),
          const SizedBox(height: AppSpacing.xl),
          if (_attempted && _unanswered > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                l10n.questionsUnanswered(_unanswered),
                style: text.bodyMedium?.copyWith(color: AppColors.error),
              ),
            ),
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

class _OpenQuestions extends StatelessWidget {
  const _OpenQuestions({
    required this.liked,
    required this.difficult,
    required this.suggestions,
    required this.enabled,
  });

  final TextEditingController liked;
  final TextEditingController difficult;
  final TextEditingController suggestions;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionLabel(l10n.feedbackOpenSection),
        for (final (label, controller) in [
          (l10n.feedbackLikedLabel, liked),
          (l10n.feedbackDifficultLabel, difficult),
          (l10n.feedbackSuggestLabel, suggestions),
        ]) ...[
          LabeledTextField(
            label: label,
            controller: controller,
            maxLines: 4,
            enabled: enabled,
          ),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }
}
