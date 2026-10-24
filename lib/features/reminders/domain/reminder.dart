/// A daily reminder time in the device's local time zone.
class ReminderTime implements Comparable<ReminderTime> {
  const ReminderTime(this.hour, this.minute);

  factory ReminderTime.fromMinutes(int minutes) =>
      ReminderTime(minutes ~/ 60, minutes % 60);

  final int hour;
  final int minute;

  int get minutes => hour * 60 + minute;

  /// The next moment at or after [now] when this reminder fires.
  DateTime nextAfter(DateTime now) {
    final today = DateTime(now.year, now.month, now.day, hour, minute);
    return today.isBefore(now)
        ? DateTime(now.year, now.month, now.day + 1, hour, minute)
        : today;
  }

  @override
  int compareTo(ReminderTime other) => minutes.compareTo(other.minutes);

  @override
  bool operator ==(Object other) =>
      other is ReminderTime && other.minutes == minutes;

  @override
  int get hashCode => minutes;
}

abstract interface class ReminderRepository {
  /// Sorted earliest first.
  Future<List<ReminderTime>> forUser(String userId);

  Future<void> save(String userId, List<ReminderTime> times);
}
