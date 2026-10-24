import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/features/exercises/domain/adherence.dart';
import 'package:melo/features/exercises/domain/completion.dart';
import 'package:melo/features/exercises/domain/schedule.dart';

// Monday 5 October 2026.
final monday = DateTime(2026, 10, 5);

Schedule _schedule(String exerciseId, Set<int> weekdays) => Schedule(
  id: 's-$exerciseId',
  patientId: 'p',
  exerciseId: exerciseId,
  weekdays: weekdays,
  effectiveFrom: monday,
);

Completion _done(String exerciseId, DateTime day) => Completion(
  id: '$exerciseId-$day',
  patientId: 'p',
  exerciseId: exerciseId,
  day: day,
  completedAt: day,
);

void main() {
  final schedules = [
    _schedule('a', {1, 2, 3, 4, 5, 6, 7}),
    _schedule('b', {1, 3, 5}),
  ];

  test('counts sessions, capped at the prescribed number per day', () {
    final twiceDaily = Schedule(
      id: 's-twice',
      patientId: 'p',
      exerciseId: 'a',
      weekdays: const {1, 2, 3, 4, 5, 6, 7},
      effectiveFrom: monday,
      sessionsPerDay: 2,
    );
    final days = Adherence.daily(
      schedules: [twiceDaily],
      completions: [
        _done('a', monday),
        _done('a', monday),
        _done('a', monday),
        _done('a', addDays(monday, 1)),
      ],
      from: monday,
      to: addDays(monday, 1),
    );

    expect((days[0].due, days[0].done), (2, 2));
    expect((days[1].due, days[1].done), (2, 1));
    expect(Adherence.rate(days), 0.75);
  });

  test('counts only exercises that were due, once per day', () {
    final days = Adherence.daily(
      schedules: schedules,
      completions: [
        _done('a', monday),
        _done('a', monday),
        _done('b', addDays(monday, 1)), // b is not due on Tuesday
      ],
      from: monday,
      to: addDays(monday, 1),
    );

    expect(days[0].due, 2);
    expect(days[0].done, 1);
    expect(days[1].due, 1);
    expect(days[1].done, 0);
  });

  test('rate is null when nothing is due', () {
    final days = Adherence.daily(
      schedules: [
        _schedule('b', {1}),
      ],
      completions: const [],
      from: addDays(monday, 1),
      to: addDays(monday, 1),
    );
    expect(days.single.rate, isNull);
    expect(Adherence.rate(days), isNull);
  });

  test('streak skips rest days and ignores an unfinished today', () {
    final rest = AdherencePeriod(start: monday, due: 0, done: 0);
    AdherencePeriod day(int done) =>
        AdherencePeriod(start: monday, due: 2, done: done);

    expect(Adherence.streak([day(2), rest, day(2), day(1)]), 2);
    expect(Adherence.streak([day(2), day(1), day(2), day(2)]), 2);
    expect(Adherence.streak([day(0)]), 0);
  });

  test('weekly groups days into Monday-start weeks', () {
    final days = Adherence.daily(
      schedules: schedules,
      completions: [_done('a', addDays(monday, 7))],
      from: addDays(monday, 5),
      to: addDays(monday, 8),
    );
    final weeks = Adherence.weekly(days);

    expect(weeks.map((w) => w.start), [monday, addDays(monday, 7)]);
    expect(weeks[1].due, 3);
    expect(weeks[1].done, 1);
  });
}
