import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/utils/l10n.dart';
import '../../../shared/widgets/async_view.dart';
import '../../../shared/widgets/failure_feedback.dart';
import '../../../shared/widgets/ink_card.dart';
import '../../../shared/widgets/skeleton.dart';
import '../../reminders/data/reminder_repository_providers.dart';
import '../../reminders/domain/reminder.dart';
import '../../reminders/presentation/controllers/reminder_controllers.dart';

class PracticeReminders extends ConsumerStatefulWidget {
  const PracticeReminders({super.key, required this.userId});
  final String userId;
  @override
  ConsumerState<PracticeReminders> createState() => _PracticeRemindersState();
}

class _PracticeRemindersState extends ConsumerState<PracticeReminders> {
  bool _saving = false;

  Future<void> _pick(List<ReminderTime> times, [ReminderTime? existing]) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: existing?.hour ?? 9,
        minute: existing?.minute ?? 0,
      ),
      helpText: existing == null
          ? context.l10n.profileRemindAt
          : context.l10n.profileEditReminder,
    );
    if (picked == null || !mounted) return;
    final next = {...times};
    if (existing != null) next.remove(existing);
    next.add(ReminderTime(picked.hour, picked.minute));
    await _save(next.toList()..sort(), requestPermission: true);
  }

  Future<void> _save(
    List<ReminderTime> times, {
    bool requestPermission = false,
  }) async {
    setState(() => _saving = true);
    var granted = true;
    final saved = await runWithFailureMessage(context, () async {
      if (requestPermission) {
        granted = await ref.read(reminderSchedulerProvider).requestPermission();
      }
      await ref.read(reminderActionsProvider).save(widget.userId, times);
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (saved && !granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.profileNotificationsOff)),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AsyncView(
    value: ref.watch(reminderTimesProvider(widget.userId)),
    loading: const Skeleton(height: 96),
    data: (times) => InkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (times.isEmpty) ...[
            Text(
              context.l10n.profileNoReminders,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final time in times)
                InputChip(
                  avatar: const Icon(LucideIcons.bell, size: 18),
                  label: Text(formatClock(time.nextAfter(DateTime.now()))),
                  tooltip: context.l10n.profileEditReminder,
                  onPressed: _saving ? null : () => _pick(times, time),
                  onDeleted: _saving
                      ? null
                      : () => _save([...times]..remove(time)),
                  deleteButtonTooltipMessage:
                      context.l10n.profileRemoveReminder,
                  materialTapTargetSize: MaterialTapTargetSize.padded,
                ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              icon: const Icon(LucideIcons.plus, size: 18),
              label: Text(context.l10n.profileAddReminder),
              onPressed: _saving ? null : () => _pick(times),
            ),
          ),
        ],
      ),
    ),
  );
}
