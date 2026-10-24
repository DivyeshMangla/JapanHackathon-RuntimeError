import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../domain/questionnaire.dart';
import 'controllers/questionnaire_controllers.dart';
import 'likert_question.dart';

/// Post-intervention usability questionnaire (System Usability Scale).
class UsabilityScreen extends ConsumerStatefulWidget {
  const UsabilityScreen({super.key});

  @override
  ConsumerState<UsabilityScreen> createState() => _UsabilityScreenState();
}

class _UsabilityScreenState extends ConsumerState<UsabilityScreen> {
  final _answers = List<int?>.filled(UsabilityResponse.itemCount, null);
  bool _attempted = false;
  bool _saving = false;

  Future<void> _submit() async {
    if (_answers.contains(null)) {
      setState(() => _attempted = true);
      return;
    }
    setState(() => _saving = true);
    final l10n = context.l10n;
    final saved = await runWithFailureMessage(
      context,
      () => ref
          .read(questionnaireActionsProvider)
          .submitUsability(
            patientId: ref.read(currentUserProvider).id,
            answers: _answers.cast<int>(),
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
    final unanswered = _answers.where((a) => a == null).length;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.taskUsability)),
      body: PageList(
        children: [
          Text(l10n.usabilityIntro, style: text.bodyLarge),
          const SizedBox(height: AppSpacing.lg),
          for (final (index, statement) in l10n.susItems.indexed)
            LikertQuestion(
              number: index + 1,
              statement: statement,
              value: _answers[index],
              showMissing: _attempted,
              onChanged: _saving
                  ? null
                  : (v) => setState(() => _answers[index] = v),
            ),
          if (_attempted && unanswered > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                l10n.questionsUnanswered(unanswered),
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
