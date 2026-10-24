import 'package:flutter_test/flutter_test.dart';
import 'package:melo/core/utils/dates.dart';
import 'package:melo/features/exercises/domain/adherence.dart';
import 'package:melo/features/exercises/domain/completion.dart';
import 'package:melo/features/exercises/domain/schedule.dart';

// Monday 5 October 2026.
final start = DateTime(2026, 10, 5);

Completion _done(String id, DateTime day) => Completion(
  id: id,
  patientId: 'p',
  exerciseId: 'ex',
  day: day,
  completedAt: day,
);

List<Schedule> _apply(List<Schedule> current, ScheduleChange change) => [
  for (final s in current)
    if (!change.delete.contains(s.id) &&
        !change.save.any((saved) => saved.id == s.id))
      s,
  ...change.save,
];

void main() {
  final original = Schedule(
    id: 'v1',
    patientId: 'p',
    exerciseId: 'ex',
    weekdays: const {1, 2, 3, 4, 5, 6, 7},
    effectiveFrom: start,
    sessionsPerDay: 2,
  );
  // Ten days of history: one session done each day, two prescribed.
  final completions = [
    for (var i = 0; i < 10; i++) _done('c$i', addDays(start, i)),
  ];
  final today = addDays(start, 10);
  final history = (from: start, to: addDays(today, -1));

  List<AdherencePeriod> scorePast(List<Schedule> schedules) => Adherence.daily(
    schedules: schedules,
    completions: completions,
    from: history.from,
    to: history.to,
  );

  test('editing a schedule leaves past adherence unchanged', () {
    final before = scorePast([original]);

    final change = ScheduleVersioning.revise(
      current: original,
      revised: original.copyWith(weekdays: const {1, 3, 5}, sessionsPerDay: 1),
      today: today,
      newId: 'v2',
    );
    final after = scorePast(_apply([original], change));

    expect(
      after.map((d) => (d.due, d.done)),
      before.map((d) => (d.due, d.done)),
    );
    expect(Adherence.rate(after), 0.5);
  });

  test('the new version applies from today and closes the old one', () {
    final change = ScheduleVersioning.revise(
      current: original,
      revised: original.copyWith(sessionsPerDay: 1),
      today: today,
      newId: 'v2',
    );
    final closed = change.save.firstWhere((s) => s.id == 'v1');
    final next = change.save.firstWhere((s) => s.id == 'v2');

    expect(closed.effectiveTo, addDays(today, -1));
    expect(next.effectiveFrom, today);
    expect(next.isCurrent, isTrue);

    final todayScore = Adherence.daily(
      schedules: _apply([original], change),
      completions: const [],
      from: today,
      to: today,
    ).single;
    expect(todayScore.due, 1);
  });

  test('a version started today is replaced, not split', () {
    final fresh = original.copyWith(id: 'v1', effectiveFrom: today);
    final change = ScheduleVersioning.revise(
      current: fresh,
      revised: fresh.copyWith(sessionsPerDay: 1),
      today: today,
      newId: 'v2',
    );
    expect(change.save.single.id, 'v1');
    expect(change.save.single.sessionsPerDay, 1);
  });

  test('ending an assignment keeps its history', () {
    final before = scorePast([original]);
    final change = ScheduleVersioning.end(current: original, today: today);

    expect(change.delete, isEmpty);
    final schedules = _apply([original], change);
    expect(scorePast(schedules).map((d) => d.due), before.map((d) => d.due));
    expect(
      Adherence.daily(
        schedules: schedules,
        completions: const [],
        from: today,
        to: today,
      ).single.due,
      0,
    );
  });
}
