/// Strips the time so dates compare as calendar days in local time.
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Calendar-safe day arithmetic (adding Durations breaks across DST changes).
DateTime addDays(DateTime day, int days) =>
    DateTime(day.year, day.month, day.day + days);

/// Monday of the week containing [day].
DateTime startOfWeek(DateTime day) => addDays(dateOnly(day), 1 - day.weekday);
