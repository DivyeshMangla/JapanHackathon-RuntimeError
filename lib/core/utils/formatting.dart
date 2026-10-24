import 'package:intl/intl.dart';

final _clock = DateFormat.jm();
final _weekdayInitial = DateFormat('EEEEE');
final _weekdayShort = DateFormat.E();
final _dayMonth = DateFormat('EEE d MMM');
final _longDate = DateFormat('EEEE d MMMM');
final _shortDate = DateFormat('d MMM');
final _fullDate = DateFormat('d MMM yyyy');
final _dateTime = DateFormat('d MMM yyyy, HH:mm');

String formatClock(DateTime time) => _clock.format(time);

/// One-letter weekday, e.g. "M" for Monday.
String formatWeekdayInitial(DateTime day) => _weekdayInitial.format(day);

/// Abbreviated weekday, e.g. "Mon".
String formatWeekdayShort(DateTime day) => _weekdayShort.format(day);

String formatDayMonth(DateTime day) => _dayMonth.format(day);

String formatLongDate(DateTime day) => _longDate.format(day);

String formatShortDate(DateTime day) => _shortDate.format(day);

String formatFullDate(DateTime day) => _fullDate.format(day);

String formatDateTime(DateTime value) => _dateTime.format(value);

/// Seconds as m:ss, e.g. 75.4 -> "1:15".
String formatSeconds(double seconds) {
  final total = seconds.round();
  return '${total ~/ 60}:${(total % 60).toString().padLeft(2, '0')}';
}

/// A 0..1 rate as a whole percentage, or an en dash when there is no rate.
String formatPercent(double? rate) =>
    rate == null ? '–' : '${(rate * 100).round()}%';

/// A number with a fixed count of decimal places, in the device locale.
String formatDecimal(double value, int digits) =>
    NumberFormat.decimalPatternDigits(decimalDigits: digits).format(value);

/// A p-value to three decimals, or "< 0.001" below that.
String formatPValue(double p) =>
    p < 0.001 ? '< ${formatDecimal(0.001, 3)}' : formatDecimal(p, 3);
