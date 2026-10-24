import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/rendering.dart';

import '../../domain/exercise_demo.dart';
import 'character/character_painter.dart';
import 'character/character_pose.dart';
import 'character/demo_props.dart';
import 'demo_canvas.dart';

/// Lying on a mat with knees bent, one hand on the chest and one on the
/// belly: the usual teaching position. The belly hand rises and falls while
/// the chest hand stays put.
class DiaphragmaticBreathingPainter extends CustomPainter {
  DiaphragmaticBreathingPainter({
    required this.position,
    required this.running,
  });

  final DemoPosition position;
  final bool running;

  static const _hip = Offset(112, 100);
  static const _frame = Rect.fromLTRB(22, 50, 182, 126);

  /// Share of the body's full belly travel used at the top of a breath.
  /// A relaxed breath is a gentle rise, and a large one reads as forced.
  static const _breathDepth = 0.45;

  /// 0 at rest after a full exhale, [_breathDepth] at the top of the
  /// inhale.
  double get _breath {
    final eased = Curves.easeInOut.transform(position.progress);
    return switch (position.phase.cue) {
      DemoCue.breatheIn => eased * _breathDepth,
      DemoCue.breatheOut => (1 - eased) * _breathDepth,
    };
  }

  static const _nearLeg = LimbPose(0.79, 2.74, math.pi / 2);

  static final _nearAnkle =
      CharacterBody.hipJoint +
      Offset.fromDirection(_nearLeg.upper, CharacterBody.thigh) +
      Offset.fromDirection(_nearLeg.lower, CharacterBody.shin);

  static CharacterPose _pose(double breath) {
    final belly = CharacterBody.bellyFront(breath);
    return CharacterPose(
      hip: _hip,
      torsoAngle: -math.pi / 2,
      belly: breath,
      eyesClosed: true,
      nearArm: LimbPose.reach(
        from: CharacterBody.shoulder,
        target: belly + const Offset(1.4, -3),
        upperLength: CharacterBody.upperArm,
        lowerLength: CharacterBody.forearm,
        end: math.pi / 2,
      ),
      farArm: LimbPose.reach(
        from: CharacterBody.shoulder,
        target: CharacterBody.chestFront + const Offset(1.4, -4),
        upperLength: CharacterBody.upperArm,
        lowerLength: CharacterBody.forearm,
        end: math.pi / 2,
      ),
      nearLeg: _nearLeg,
      // The far foot sits a little nearer the hips on the same mat line,
      // so both legs show instead of one shoe stacked on the other.
      farLeg: LimbPose.reach(
        from: CharacterBody.hipJoint,
        target: _nearAnkle + const Offset(0, -6),
        upperLength: CharacterBody.thigh,
        lowerLength: CharacterBody.shin,
        end: math.pi / 2,
        jointBack: false,
      ),
    );
  }

  /// Torso-frame point to design space for the lying pose.
  static Offset _world(Offset local) =>
      Offset(_hip.dx + local.dy, _hip.dy - local.dx);

  @override
  void paint(Canvas canvas, Size size) {
    final breath = _breath;
    canvas.save();
    DemoCanvas(size, frame: _frame).apply(canvas);

    DemoProps.backdrop(canvas, const Rect.fromLTRB(35, 54, 168, 117));
    DemoProps.mat(canvas, left: 26, right: 172, front: 118);
    DemoProps.shadow(canvas, const Rect.fromLTRB(68, 110, 110, 112.5));
    CharacterPainter.paint(canvas, _pose(breath));

    if (running && !position.finished) {
      final belly = _world(CharacterBody.bellyFront(breath));
      DemoProps.riseMarks(canvas, belly + const Offset(2, -9));
      _paintAirflow(canvas);
    }
    canvas.restore();
  }

  /// Chevrons stream down into the nose on the inhale and up away from
  /// the face on the exhale, looping twice per phase.
  void _paintAirflow(Canvas canvas) {
    const nose = Offset(52, 82);
    final inhale = position.phase.cue == DemoCue.breatheIn;
    for (var i = 0; i < 3; i++) {
      final travel = (position.progress * 2 + i / 3) % 1;
      final opacity = math.sin(math.pi * travel);
      final distance = 4 + 20 * (inhale ? 1 - travel : travel);
      DemoProps.chevron(
        canvas,
        nose - Offset(0, distance),
        inhale ? math.pi / 2 : -math.pi / 2,
        opacity,
      );
    }
  }

  @override
  bool shouldRepaint(DiaphragmaticBreathingPainter oldDelegate) =>
      oldDelegate.position.progress != position.progress ||
      oldDelegate.position.phase != position.phase ||
      oldDelegate.position.finished != position.finished ||
      oldDelegate.running != running;
}
