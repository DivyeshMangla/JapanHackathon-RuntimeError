import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/page_list.dart';
import '../../therapist/presentation/controllers/caseload_controllers.dart';
import '../../therapist/presentation/participant_detail_screen.dart';
import '../data/expression_providers.dart';
import '../domain/expression.dart';
import 'expression_progress_panel.dart';
import 'expression_strings.dart';

class TherapistExpressionsScreen extends ConsumerWidget {
  const TherapistExpressionsScreen({super.key, required this.patientId});
  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text(ExpressionStrings.title)),
    body: AsyncView(
      value: ref.watch(caseloadParticipantProvider(patientId)),
      data: (participant) {
        if (participant == null) return const ParticipantNotFound();
        return AsyncView(
          value: ref.watch(expressionRecordProvider(patientId)),
          data: (record) => RefreshIndicator(
            onRefresh: () =>
                ref.refresh(expressionRecordProvider(patientId).future),
            child: PageList(
              children: [
                if (record.consented)
                  _ExpressionPlan(
                    key: ValueKey(record.assignment?.id),
                    patientId: patientId,
                    assignment: record.assignment,
                  )
                else
                  const Text(ExpressionStrings.consentNeeded),
                const SizedBox(height: AppSpacing.xl),
                const SectionLabel(ExpressionStrings.history),
                const Text(ExpressionStrings.caution),
                const SizedBox(height: AppSpacing.md),
                if (record.sessions.isEmpty)
                  const Text(ExpressionStrings.noSessions),
                for (final session in record.sessions) ...[
                  ExpressionResultCard(
                    key: ValueKey('${session.id}-${session.reviewedAt}'),
                    session: session,
                    actions: _ReviewForm(
                      patientId: patientId,
                      session: session,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}

class _ExpressionPlan extends ConsumerStatefulWidget {
  const _ExpressionPlan({
    super.key,
    required this.patientId,
    required this.assignment,
  });
  final String patientId;
  final ExpressionAssignment? assignment;

  @override
  ConsumerState<_ExpressionPlan> createState() => _ExpressionPlanState();
}

class _ExpressionPlanState extends ConsumerState<_ExpressionPlan> {
  late final _selected = {
    ...?widget.assignment?.feelings,
    if (widget.assignment == null) ...[Feeling.happy, Feeling.sad],
  };
  late bool _enabled = widget.assignment?.enabled ?? true;
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final saved = await runWithFailureMessage(context, () async {
      await ref.read(expressionRepositoryProvider).assign(widget.patientId, [
        for (final feeling in Feeling.values)
          if (_selected.contains(feeling)) feeling,
      ], enabled: _enabled);
      ref.invalidate(expressionRecordProvider(widget.patientId));
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(ExpressionStrings.saved)));
    }
  }

  @override
  Widget build(BuildContext context) => InkCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel(ExpressionStrings.choose),
        const Text(ExpressionStrings.chooseHelp),
        for (final feeling in Feeling.values)
          CheckboxListTile(
            title: Text(ExpressionStrings.label(feeling)),
            value: _selected.contains(feeling),
            onChanged: _saving
                ? null
                : (value) => setState(() {
                    if (value == true) {
                      _selected.add(feeling);
                    } else {
                      _selected.remove(feeling);
                    }
                  }),
          ),
        SwitchListTile(
          title: const Text(ExpressionStrings.enabled),
          value: _enabled,
          onChanged: _saving
              ? null
              : (value) => setState(() => _enabled = value),
        ),
        const SizedBox(height: AppSpacing.md),
        PrimaryButton(
          label: _saving ? ExpressionStrings.saving : ExpressionStrings.save,
          onPressed: _saving || _selected.length < 2 ? null : _save,
        ),
      ],
    ),
  );
}

class _ReviewForm extends ConsumerStatefulWidget {
  const _ReviewForm({required this.patientId, required this.session});
  final String patientId;
  final ExpressionSession session;

  @override
  ConsumerState<_ReviewForm> createState() => _ReviewFormState();
}

class _ReviewFormState extends ConsumerState<_ReviewForm> {
  late final _note = TextEditingController(
    text: widget.session.reviewNote ?? '',
  );
  final _form = GlobalKey<FormState>();
  bool _saving = false;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final saved = await runWithFailureMessage(context, () async {
      await ref
          .read(expressionRepositoryProvider)
          .review(widget.session.id, _note.text.trim());
      ref.invalidate(expressionRecordProvider(widget.patientId));
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text(ExpressionStrings.reviewed)));
    }
  }

  @override
  Widget build(BuildContext context) => Form(
    key: _form,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AppSpacing.md),
        TextFormField(
          controller: _note,
          enabled: !_saving,
          minLines: 2,
          maxLines: 5,
          maxLength: 2000,
          decoration: const InputDecoration(
            labelText: ExpressionStrings.feedbackLabel,
            hintText: ExpressionStrings.feedbackHint,
          ),
          validator: (value) => value == null || value.trim().isEmpty
              ? ExpressionStrings.feedbackRequired
              : null,
        ),
        const SizedBox(height: AppSpacing.sm),
        PrimaryButton(
          label: _saving
              ? ExpressionStrings.saving
              : ExpressionStrings.sendFeedback,
          onPressed: _saving ? null : _save,
        ),
      ],
    ),
  );
}
