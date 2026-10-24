import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_failure.dart';
import '../../../../core/logging/app_logger.dart';
import '../../../../core/utils/l10n.dart';
import '../../../auth/domain/user.dart';
import '../../../auth/presentation/controllers/auth_controller.dart';
import '../../../usage/domain/usage_event.dart';
import '../../../usage/presentation/controllers/usage_controllers.dart';
import '../../data/reminder_repository_providers.dart';
import '../../data/reminder_scheduler.dart';
import '../../domain/reminder.dart';

final reminderTimesProvider = FutureProvider.family<List<ReminderTime>, String>(
  (ref, userId) => ref.watch(reminderRepositoryProvider).forUser(userId),
);

final reminderActionsProvider = Provider<ReminderActions>(ReminderActions.new);

class ReminderActions {
  ReminderActions(this._ref);

  final Ref _ref;

  Future<void> save(String userId, List<ReminderTime> times) async {
    await _ref.read(reminderRepositoryProvider).save(userId, times);
    _ref.invalidate(reminderTimesProvider(userId));
    await _ref
        .read(reminderSchedulerProvider)
        .scheduleDaily(times, reminderText());
    await _ref
        .read(usageLoggerProvider)
        .record(UsageAction.remindersChanged, detail: '${times.length}');
  }
}

/// Keeps device notifications in step with whoever is signed in: a child's
/// or parent's practice reminders are scheduled at sign-in, and cleared at
/// sign-out. Watched once from the app root.
const _remindedRoles = {UserRole.patient, UserRole.parent};

final reminderSyncProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<User?>>(authControllerProvider, (previous, next) async {
    try {
      final user = next.value;
      if (user?.id == previous?.value?.id) return;

      final scheduler = ref.read(reminderSchedulerProvider);
      if (user == null || !_remindedRoles.contains(user.role)) {
        await scheduler.cancelAll();
        return;
      }
      final times = await ref.read(reminderRepositoryProvider).forUser(user.id);
      if (times.isNotEmpty && await scheduler.requestPermission()) {
        await scheduler.scheduleDaily(times, reminderText());
      }
    } on AppFailure catch (failure) {
      // Sign-in and sign-out must not fail because of reminders; a parent
      // can retry from Settings.
      AppLogger.warning('Reminder sync failed', failure);
    }
  }, fireImmediately: true);
});

/// Notification text in the device language when the app supports it,
/// otherwise English.
ReminderText reminderText() {
  final device = PlatformDispatcher.instance.locale;
  final l10n = lookupAppLocalizations(
    AppLocalizations.delegate.isSupported(device) ? device : const Locale('en'),
  );
  return (
    title: l10n.reminderNotificationTitle,
    body: l10n.reminderNotificationBody,
    channelName: l10n.reminderChannelName,
    channelDescription: l10n.reminderChannelDescription,
  );
}
