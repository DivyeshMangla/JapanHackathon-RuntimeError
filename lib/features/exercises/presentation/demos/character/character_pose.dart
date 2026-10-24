import 'dart:math' as math;
import 'dart:ui';

/// Directions of a two-segment limb and its end piece (hand or foot), in
/// the torso's frame. Angles are canvas radians: 0 points to the front,
/// pi / 2 points down toward the hips.
class LimbPose {
  const LimbPose(this.upper, this.lower, this.end);

  /// Places the end of a limb at [target] by solving the two-segment chain,
  /// so a hand can rest on a moving belly without hand-tuned angles. Of the
  /// two possible joints, [jointBack] picks the one nearer the back (elbows)
  /// rather than the front (knees).
  factory LimbPose.reach({
    required Offset from,
    required Offset target,
    required double upperLength,
    required double lowerLength,
    required double end,
    bool jointBack = true,
  }) {
    final delta = target - from;
    final distance = delta.distance.clamp(
      (upperLength - lowerLength).abs() + 0.01,
      upperLength + lowerLength - 0.01,
    );
    final cosine =
        (upperLength * upperLength +
            distance * distance -
            lowerLength * lowerLength) /
        (2 * upperLength * distance);
    final spread = math.acos(cosine.clamp(-1.0, 1.0));
    final a = delta.direction + spread;
    final b = delta.direction - spread;
    final jointA = from + Offset.fromDirection(a, upperLength);
    final jointB = from + Offset.fromDirection(b, upperLength);
    final pickA = jointBack ? jointA.dx < jointB.dx : jointA.dx > jointB.dx;
    final upper = pickA ? a : b;
    final joint = pickA ? jointA : jointB;
    return LimbPose(upper, (target - joint).direction, end);
  }

  final double upper;
  final double lower;
  final double end;
}

/// Everything needed to draw the character once. Exercises describe their
/// movement as a function from time to pose, and the shared painter draws
/// it, so every exercise uses the same body and style.
class CharacterPose {
  const CharacterPose({
    required this.hip,
    required this.torsoAngle,
    required this.nearArm,
    required this.farArm,
    required this.nearLeg,
    required this.farLeg,
    this.neckAngle = 0,
    this.belly = 0,
    this.eyesClosed = false,
  });

  /// Hip joint in design space.
  final Offset hip;

  /// Rotation of the whole torso frame: 0 stands upright facing right,
  /// -pi / 2 lies on the back with the head to the left.
  final double torsoAngle;

  /// Head tilt relative to the torso.
  final double neckAngle;

  final LimbPose nearArm;
  final LimbPose farArm;
  final LimbPose nearLeg;
  final LimbPose farLeg;

  /// 0 relaxed, 1 fully expanded belly.
  final double belly;

  /// Relaxed closed eyes, for calm breathing and relaxation exercises.
  final bool eyesClosed;
}
