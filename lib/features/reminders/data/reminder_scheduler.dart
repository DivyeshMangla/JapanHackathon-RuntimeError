import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../../../core/errors/app_failure.dart';
import '../../../core/errors/guard.dart';
import '../domain/reminder.dart';

/// Localized text for reminder notifications, supplied by the caller
/// because scheduling happens outside the widget tree.
typedef ReminderText = ({
  String title,
  String body,
  String channelName,
  String channelDescription,
});

class ReminderScheduler {
  ReminderScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _initialized = false;

  static NotificationDetails _details(ReminderText text) => NotificationDetails(
    android: AndroidNotificationDetails(
      'practice_reminders',
      text.channelName,
      channelDescription: text.channelDescription,
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    ),
    iOS: const DarwinNotificationDetails(),
  );

  Future<void> _ensureInitialized() async {
    if (_initialized) return;
    tz_data.initializeTimeZones();
    final zone = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(zone.identifier));

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
    );
    _initialized = true;
  }

  /// Asks for notification permission where the platform requires it.
  Future<bool> requestPermission() =>
      guard(_requestPermission, ReminderFailure.new);

  Future<bool> _requestPermission() async {
    await _ensureInitialized();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    final granted =
        await android?.requestNotificationsPermission() ??
        await ios?.requestPermissions(alert: true, sound: true);
    return granted ?? true;
  }

  /// Replaces every scheduled reminder with [times].
  Future<void> scheduleDaily(List<ReminderTime> times, ReminderText text) =>
      guard(() => _scheduleDaily(times, text), ReminderFailure.new);

  Future<void> _scheduleDaily(
    List<ReminderTime> times,
    ReminderText text,
  ) async {
    await _ensureInitialized();
    await _plugin.cancelAll();
    final now = tz.TZDateTime.now(tz.local);
    for (final (index, time) in times.indexed) {
      final next = time.nextAfter(now);
      await _plugin.zonedSchedule(
        id: index,
        title: text.title,
        body: text.body,
        scheduledDate: tz.TZDateTime(
          tz.local,
          next.year,
          next.month,
          next.day,
          next.hour,
          next.minute,
        ),
        notificationDetails: _details(text),
        // Inexact delivery avoids the exact-alarm permission; a few minutes
        // of drift is fine for a practice reminder.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
      );
    }
  }

  Future<void> cancelAll() => guard(() async {
    await _ensureInitialized();
    await _plugin.cancelAll();
  }, ReminderFailure.new);
}
