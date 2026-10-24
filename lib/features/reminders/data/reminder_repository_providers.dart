import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/storage/local_database.dart';
import '../domain/reminder.dart';
import 'hive_reminder_repository.dart';
import 'reminder_scheduler.dart';

final reminderRepositoryProvider = Provider<ReminderRepository>(
  (ref) => HiveReminderRepository(ref.watch(localDatabaseProvider).reminders),
);

final reminderSchedulerProvider = Provider<ReminderScheduler>(
  (ref) => ReminderScheduler(),
);
