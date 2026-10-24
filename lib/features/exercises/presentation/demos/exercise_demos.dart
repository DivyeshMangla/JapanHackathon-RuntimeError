import 'package:flutter/material.dart';

import '../../../../core/utils/l10n.dart';
import '../../domain/exercise_demo.dart';
import 'diaphragmatic_breathing_painter.dart';

typedef DemoPainterBuilder =
    CustomPainter Function(
      BuildContext context,
      DemoPosition position,
      bool running,
    );

/// An animated demonstration: its timing, its figure, and a description of
/// the figure for screen readers.
class ExerciseDemo {
  const ExerciseDemo({
    required this.script,
    required this.painter,
    required this.description,
  });

  final DemoScript script;
  final DemoPainterBuilder painter;
  final String Function(AppLocalizations l10n) description;
}

/// The demonstration for an exercise, or null when it has none yet.
ExerciseDemo? exerciseDemoFor(String exerciseId) => switch (exerciseId) {
  'ex-breathing' => ExerciseDemo(
    script: diaphragmaticBreathingScript,
    painter: (context, position, running) =>
        DiaphragmaticBreathingPainter(position: position, running: running),
    description: (l10n) => l10n.demoBreathingFigure,
  ),
  _ => null,
};
