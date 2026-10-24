import 'dart:math';

import 'package:melo/core/utils/dates.dart';
import 'package:melo/features/exercises/domain/completion.dart';
import 'package:melo/features/exercises/domain/exercise.dart';
import 'package:melo/features/exercises/domain/schedule.dart';

const plainExercise = Exercise(
  id: 'ex-plain',
  title: 'Plain exercise',
  program: 'Fixture program A',
  summary: 'A single sentence description.',
  steps: ['A single sentence description.'],
  durationMinutes: 5,
  repetitions: 5,
);

const instructionsExercise = Exercise(
  id: 'ex-instructions',
  title: 'Exercise needing instructions',
  program: 'Fixture program B',
  summary: 'Do the first part. Then do the second part.',
  steps: ['Do the first part.', 'Then do the second part.'],
  durationMinutes: 5,
  repetitions: 5,
  needsInstructions: true,
  caution: 'Stop if this causes distress.',
);

const diaryExercise = Exercise(
  id: 'ex-diary',
  title: 'Diary exercise',
  program: 'Fixture program A',
  summary: 'Keep a diary through the day.',
  steps: ['Keep a diary through the day.'],
  durationMinutes: 1,
  repetitions: 1,
  verificationType: VerificationType.voiceDiary,
);

const fixtureExercises = [plainExercise, instructionsExercise, diaryExercise];

final fixtureLibrary = {for (final e in fixtureExercises) e.id: e};

/// Assignments for a participant who is on the program for 28 days.
List<Schedule> finishedParticipantSchedules(
  String patientId,
  DateTime start,
) => [
  for (final (exercise, weekdays) in const [
    (plainExercise, {1, 2, 3, 4, 5, 6, 7}),
    (instructionsExercise, {1, 2, 3, 4, 5, 6, 7}),
    (diaryExercise, {1, 2, 3, 4, 5}),
  ])
    Schedule(
      id: 'sched-$patientId-${exercise.id}',
      patientId: patientId,
      exerciseId: exercise.id,
      weekdays: weekdays,
      effectiveFrom: start,
      sessionsPerDay: exercise.sessionsPerDay,
      repetitions: exercise.repetitions,
      instructions: exercise.needsInstructions ? 'Fixture instructions.' : '',
    ),
];

/// About 85% of prescribed sessions over 28 days, from a fixed seed.
List<Completion> finishedParticipantCompletions(
  String patientId,
  List<Schedule> schedules,
  DateTime start,
) {
  final random = Random(606);
  return [
    for (var offset = 0; offset < 28; offset++)
      for (final schedule in schedules)
        if (schedule.isDueOn(addDays(start, offset)))
          for (var session = 1; session <= schedule.sessionsPerDay; session++)
            if (random.nextDouble() < 0.85)
              Completion(
                id: 'done-${schedule.id}-$offset-s$session',
                patientId: patientId,
                exerciseId: schedule.exerciseId,
                day: addDays(start, offset),
                completedAt: addDays(
                  start,
                  offset,
                ).add(Duration(hours: 7 + 5 * session, minutes: offset)),
              ),
  ];
}
