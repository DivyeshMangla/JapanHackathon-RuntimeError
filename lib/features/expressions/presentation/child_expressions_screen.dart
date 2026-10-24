import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/buttons.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/page_list.dart';
import '../../auth/presentation/controllers/auth_controller.dart';
import '../data/expression_providers.dart';
import '../domain/expression.dart';
import 'expression_face.dart';
import 'expression_progress_panel.dart';
import 'expression_strings.dart';

class ChildExpressionsScreen extends ConsumerStatefulWidget {
  const ChildExpressionsScreen({super.key});

  @override
  ConsumerState<ChildExpressionsScreen> createState() =>
      _ChildExpressionsScreenState();
}

class _ChildExpressionsScreenState
    extends ConsumerState<ChildExpressionsScreen> {
  ExpressionAssignment? _round;
  ExpressionAssistance _assistance = ExpressionAssistance.independent;

  @override
  Widget build(BuildContext context) {
    final childId = ref.watch(currentUserProvider).id;
    if (_round != null) {
      return _ExpressionRound(
        assignment: _round!,
        childId: childId,
        assistance: _assistance,
        onFinished: () => setState(() => _round = null),
      );
    }
    return Scaffold(
      backgroundColor: AppColors.paper,
      appBar: AppBar(title: const Text(ExpressionStrings.title)),
      body: AsyncView(
        value: ref.watch(expressionRecordProvider(childId)),
        data: (record) => RefreshIndicator(
          onRefresh: () =>
              ref.refresh(expressionRecordProvider(childId).future),
          child: PageList(
            children: [
              const Text(ExpressionStrings.introduction),
              const SizedBox(height: AppSpacing.md),
              const Text(ExpressionStrings.parentGuidance),
              const SizedBox(height: AppSpacing.lg),
              if (!record.consented)
                const Text(ExpressionStrings.consentNeeded)
              else if (record.assignment?.enabled != true)
                const Text(ExpressionStrings.waiting)
              else ...[
                const Text(ExpressionStrings.adultHelp),
                const SizedBox(height: AppSpacing.sm),
                DropdownButtonFormField<ExpressionAssistance>(
                  initialValue: _assistance,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: ExpressionStrings.adultHelp,
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: ExpressionAssistance.independent,
                      child: Text(ExpressionStrings.independent),
                    ),
                    DropdownMenuItem(
                      value: ExpressionAssistance.withHelp,
                      child: Text(ExpressionStrings.withHelp),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _assistance = value);
                  },
                ),
                const SizedBox(height: AppSpacing.md),
                PrimaryButton(
                  label: ExpressionStrings.start,
                  onPressed: () => setState(() => _round = record.assignment),
                ),
              ],
              const SizedBox(height: AppSpacing.xl),
              ExpressionHistory(sessions: record.sessions),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExpressionRound extends ConsumerStatefulWidget {
  const _ExpressionRound({
    required this.assignment,
    required this.childId,
    required this.assistance,
    required this.onFinished,
  });
  final ExpressionAssignment assignment;
  final String childId;
  final ExpressionAssistance assistance;
  final VoidCallback onFinished;

  @override
  ConsumerState<_ExpressionRound> createState() => _ExpressionRoundState();
}

class _ExpressionRoundState extends ConsumerState<_ExpressionRound> {
  late final _pictures = widget.assignment.pictures..shuffle(Random.secure());
  late final _options = [...widget.assignment.feelings]
    ..shuffle(Random.secure());
  final _sessionId = const Uuid().v4();
  final List<ExpressionAnswer> _answers = [];
  Feeling? _selected;
  bool _sending = false;
  bool _sendFailed = false;
  bool _sent = false;

  Future<void> _leave() async {
    if (_sending) return;
    if (_sent) {
      widget.onFinished();
      return;
    }
    final leave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(ExpressionStrings.leaveTitle),
        content: const Text(ExpressionStrings.leaveMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(ExpressionStrings.stay),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(ExpressionStrings.leave),
          ),
        ],
      ),
    );
    if (leave == true && mounted) widget.onFinished();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _sendFailed = false;
    });
    final sent = await runWithFailureMessage(context, () async {
      await ref
          .read(expressionRepositoryProvider)
          .submit(
            childId: widget.childId,
            assignmentId: widget.assignment.id,
            sessionId: _sessionId,
            answers: _answers,
            assistance: widget.assistance,
          );
      ref.invalidate(expressionRecordProvider(widget.childId));
    });
    if (!mounted) return;
    setState(() {
      _sending = false;
      _sent = sent;
      _sendFailed = !sent;
    });
  }

  void _next() {
    final selected = _selected;
    if (selected == null) return;
    setState(() {
      _answers.add(
        ExpressionAnswer(
          pictureId: _pictures[_answers.length].id,
          selected: selected,
        ),
      );
      _selected = null;
      _options.shuffle(Random.secure());
    });
  }

  @override
  Widget build(BuildContext context) {
    final finished = _answers.length == _pictures.length;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _leave();
      },
      child: Scaffold(
        backgroundColor: AppColors.paper,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: BackButton(onPressed: _sending ? null : _leave),
          title: const Text(ExpressionStrings.title),
        ),
        body: PageList(
          children: [
            if (!finished)
              _PictureQuestion(
                picture: _pictures[_answers.length],
                index: _answers.length + 1,
                total: _pictures.length,
                choices: _options,
                selected: _selected,
                onSelected: (value) => setState(() => _selected = value),
                onNext: _selected == null ? null : _next,
              )
            else ...[
              Text(
                _sent ? ExpressionStrings.sent : ExpressionStrings.finish,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              if (_sent)
                PrimaryButton(
                  label: ExpressionStrings.history,
                  onPressed: widget.onFinished,
                )
              else
                PrimaryButton(
                  label: _sending
                      ? ExpressionStrings.sending
                      : _sendFailed
                      ? ExpressionStrings.retry
                      : ExpressionStrings.send,
                  onPressed: _sending ? null : _send,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _PictureQuestion extends StatelessWidget {
  const _PictureQuestion({
    required this.picture,
    required this.index,
    required this.total,
    required this.choices,
    required this.selected,
    required this.onSelected,
    required this.onNext,
  });
  final ExpressionPicture picture;
  final int index;
  final int total;
  final List<Feeling> choices;
  final Feeling? selected;
  final ValueChanged<Feeling> onSelected;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        ExpressionStrings.question(index, total),
        style: Theme.of(context).textTheme.titleLarge,
      ),
      const SizedBox(height: AppSpacing.md),
      LinearProgressIndicator(value: (index - 1) / total),
      const SizedBox(height: AppSpacing.lg),
      Center(
        child: ExpressionFace(
          picture: picture,
          semanticLabel: ExpressionStrings.pictureLabel(index),
        ),
      ),
      const SizedBox(height: AppSpacing.lg),
      for (final feeling in choices)
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
          child: Semantics(
            selected: selected == feeling,
            child: SizedBox(
              height: AppSizes.valueColumn,
              child: selected == feeling
                  ? FilledButton(
                      onPressed: () => onSelected(feeling),
                      child: Text(ExpressionStrings.label(feeling)),
                    )
                  : OutlinedButton(
                      onPressed: () => onSelected(feeling),
                      child: Text(ExpressionStrings.label(feeling)),
                    ),
            ),
          ),
        ),
      const SizedBox(height: AppSpacing.md),
      PrimaryButton(label: ExpressionStrings.next, onPressed: onNext),
    ],
  );
}
