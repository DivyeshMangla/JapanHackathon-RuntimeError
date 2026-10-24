import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'character_pose.dart';
import 'demo_style.dart';

/// Body proportions in design units, in the torso's frame: origin at the
/// hip joint, front toward +x, head toward -y.
abstract final class CharacterBody {
  static const shoulder = Offset(-1, -41);
  static const neckBase = Offset(3, -47);
  static const hipJoint = Offset(0, 2);
  static const neckLength = 6.0;
  static const upperArm = 22.0;
  static const forearm = 19.0;
  static const thigh = 32.0;
  static const shin = 30.0;

  /// How far the belly front moves forward at a full breath.
  static const bellyTravel = 9.0;

  /// Front of the belly at its most forward point, for placing a hand on it.
  static Offset bellyFront(double belly) =>
      Offset(13 + bellyTravel * belly, -8);

  static const chestFront = Offset(13.5, -34);
}

/// Draws a [CharacterPose] in the flat line-art style: ink outlines, white
/// skin, lime top, charcoal trousers. Paints in design space, so callers
/// apply [DemoCanvas] first.
abstract final class CharacterPainter {
  static void paint(Canvas canvas, CharacterPose pose) {
    canvas
      ..save()
      ..translate(pose.hip.dx, pose.hip.dy)
      ..rotate(pose.torsoAngle);
    _leg(canvas, pose.farLeg);
    _arm(canvas, pose.farArm, hand: false);
    _shape(canvas, _pelvis, DemoStyle.trousers);
    _neck(canvas);
    _shape(canvas, _torso(pose.belly), DemoStyle.top);
    _leg(canvas, pose.nearLeg);
    _head(canvas, pose.neckAngle, pose.eyesClosed);
    _arm(canvas, pose.farArm, limb: false);
    _arm(canvas, pose.nearArm);
    canvas.restore();
  }

  static void _shape(Canvas canvas, Path path, Paint fill) {
    canvas
      ..drawPath(path, fill)
      ..drawPath(path, DemoStyle.outline);
  }

  /// A limb segment along +y from the origin, rounded at both ends and
  /// narrowing from [top] to [bottom] width.
  static Path _segment(double length, double top, double bottom) => Path()
    ..moveTo(-top / 2, 0)
    ..lineTo(-bottom / 2, length)
    ..arcToPoint(
      Offset(bottom / 2, length),
      radius: Radius.circular(bottom / 2),
      clockwise: false,
    )
    ..lineTo(top / 2, 0)
    ..arcToPoint(
      Offset(-top / 2, 0),
      radius: Radius.circular(top / 2),
      clockwise: false,
    )
    ..close();

  /// Points the canvas +y axis along [direction].
  static void _aim(Canvas canvas, double direction) =>
      canvas.rotate(direction - math.pi / 2);

  static final _pelvis = Path()
    ..addRRect(RRect.fromLTRBR(-11.5, -3, 10.5, 7, const Radius.circular(4)));

  static Path _torso(double belly) {
    final bulge = CharacterBody.bellyTravel * belly;
    return Path()
      ..moveTo(-11, 4)
      ..cubicTo(-13, -8, -10, -18, -10, -24)
      ..cubicTo(-10, -32, -13, -40, -9, -46)
      ..cubicTo(-6, -50, 0, -50, 3, -49)
      ..cubicTo(8, -48, 13, -42, 13.5, -34)
      ..cubicTo(14, -28, 12, -25, 11.5, -22)
      ..cubicTo(12 + bulge * 0.5, -17, 13 + bulge, -13, 13 + bulge, -8)
      ..cubicTo(13 + bulge, -2, 12 + bulge * 0.4, 2, 10, 4)
      ..close();
  }

  static void _neck(Canvas canvas) {
    final neck = Path()
      ..addRRect(
        RRect.fromLTRBR(
          CharacterBody.neckBase.dx - 4,
          CharacterBody.neckBase.dy - CharacterBody.neckLength - 2,
          CharacterBody.neckBase.dx + 4,
          CharacterBody.neckBase.dy + 3,
          const Radius.circular(4),
        ),
      );
    _shape(canvas, neck, DemoStyle.skin);
  }

  /// Head in profile with a bun, facing +x. Origin is the top of the neck.
  static void _head(Canvas canvas, double neckAngle, bool eyesClosed) {
    canvas
      ..save()
      ..translate(
        CharacterBody.neckBase.dx,
        CharacterBody.neckBase.dy - CharacterBody.neckLength,
      )
      ..rotate(neckAngle);

    _shape(
      canvas,
      Path()..addOval(_circle(const Offset(-7, -21), 4.5)),
      DemoStyle.hair,
    );
    _shape(
      canvas,
      Path()..addOval(_circle(const Offset(0, -10), 11)),
      DemoStyle.skin,
    );
    final hair = Path()
      ..moveTo(8.5, -17)
      ..cubicTo(5, -23.5, -5, -24, -9.5, -16)
      ..cubicTo(-12, -11, -11, -5, -8, -2)
      ..cubicTo(-7, -7, -5, -12, -1, -14)
      ..cubicTo(3, -15, 6, -15, 8.5, -17)
      ..close();
    _shape(canvas, hair, DemoStyle.hair);

    // The nose is filled over the head outline so the bump reads as part
    // of the profile, then only its outer edge is stroked.
    final noseEdge = Path()
      ..moveTo(10.4, -12.5)
      ..cubicTo(12, -11, 14.6, -8.6, 11.2, -7.2);
    canvas
      ..drawPath(Path.from(noseEdge)..close(), DemoStyle.skin)
      ..drawPath(noseEdge, DemoStyle.outline);

    final smile = Path()
      ..moveTo(5.4, -4.8)
      ..quadraticBezierTo(7.6, -2.6, 9.4, -5.2);
    canvas.drawPath(smile, DemoStyle.detail);
    if (eyesClosed) {
      final lid = Path()
        ..moveTo(3.6, -12.6)
        ..quadraticBezierTo(5.4, -10.6, 7.4, -12.4);
      canvas.drawPath(lid, DemoStyle.detail);
    } else {
      canvas.drawCircle(const Offset(5.6, -11.6), 1.2, DemoStyle.ink);
    }
    canvas
      ..drawLine(
        const Offset(3.6, -15.4),
        const Offset(7, -15.8),
        DemoStyle.detail,
      )
      ..restore();
  }

  static Rect _circle(Offset center, double radius) =>
      Rect.fromCircle(center: center, radius: radius);

  /// Short sleeve over the upper arm, bare forearm, hand. The far arm is
  /// drawn in two passes, its [limb] behind the torso and its [hand] in
  /// front, so a hand can rest on the body while the arm stays behind it.
  static void _arm(
    Canvas canvas,
    LimbPose arm, {
    bool limb = true,
    bool hand = true,
  }) {
    canvas
      ..save()
      ..translate(CharacterBody.shoulder.dx, CharacterBody.shoulder.dy);
    _aim(canvas, arm.upper);
    if (limb) _upperArm(canvas);
    canvas.translate(0, CharacterBody.upperArm);
    _aim(canvas, arm.lower - arm.upper + math.pi / 2);
    if (limb) {
      _shape(canvas, _segment(CharacterBody.forearm, 6.5, 5.5), DemoStyle.skin);
    }

    canvas.translate(0, CharacterBody.forearm);
    _aim(canvas, arm.end - arm.lower + math.pi / 2);
    if (hand) _hand(canvas);
    canvas.restore();
  }

  static void _upperArm(Canvas canvas) {
    _shape(canvas, _segment(CharacterBody.upperArm, 8, 6.5), DemoStyle.skin);
    final sleeve = Path()
      ..moveTo(-5.2, 0)
      ..lineTo(-5, 11)
      ..lineTo(5, 11)
      ..lineTo(5.2, 0)
      ..arcToPoint(
        const Offset(-5.2, 0),
        radius: const Radius.circular(5.2),
        clockwise: false,
      )
      ..close();
    _shape(canvas, sleeve, DemoStyle.top);
  }

  /// A flat hand pointing along +y, palm on the -x side, so it can lie
  /// flush on the body.
  static void _hand(Canvas canvas) {
    final thumb = Path()
      ..addOval(
        Rect.fromCenter(
          center: const Offset(2.6, 3.5),
          width: 2.8,
          height: 5.5,
        ),
      );
    _shape(canvas, thumb, DemoStyle.skin);
    final hand = Path()
      ..moveTo(-2.2, -1)
      ..lineTo(-2.2, 10)
      ..quadraticBezierTo(-2, 12.6, 0.4, 12.4)
      ..quadraticBezierTo(2.4, 12, 2.2, 8.5)
      ..lineTo(2.2, 2)
      ..quadraticBezierTo(2.3, -1.4, 0, -1.5)
      ..close();
    _shape(canvas, hand, DemoStyle.skin);
    canvas.drawLine(
      const Offset(0.1, 7.5),
      const Offset(0.2, 11.6),
      DemoStyle.detail,
    );
  }

  /// Trouser leg with a lime side stripe, and a trainer.
  static void _leg(Canvas canvas, LimbPose leg) {
    canvas
      ..save()
      ..translate(CharacterBody.hipJoint.dx, CharacterBody.hipJoint.dy);
    _aim(canvas, leg.upper);
    _shape(canvas, _segment(CharacterBody.thigh, 13, 10), DemoStyle.trousers);
    canvas.drawLine(
      const Offset(3.5, 2),
      const Offset(2.5, CharacterBody.thigh - 2),
      DemoStyle.stripe,
    );

    canvas.translate(0, CharacterBody.thigh);
    _aim(canvas, leg.lower - leg.upper + math.pi / 2);
    _shape(canvas, _segment(CharacterBody.shin, 10, 7.5), DemoStyle.trousers);
    canvas.drawLine(
      const Offset(2.5, 2),
      const Offset(2, CharacterBody.shin - 3),
      DemoStyle.stripe,
    );

    canvas.translate(0, CharacterBody.shin);
    _aim(canvas, leg.end - leg.lower + math.pi / 2);
    _shoe(canvas);
    canvas.restore();
  }

  /// Trainer pointing along +y with its sole on the -x side, so a foot
  /// aimed forward sits flat with the sole down.
  static void _shoe(Canvas canvas) {
    final upper = Path()
      ..moveTo(-4, -3.5)
      ..lineTo(-4, 13)
      ..quadraticBezierTo(-4, 17, 0, 16.5)
      ..quadraticBezierTo(3.5, 15.5, 4, 8)
      ..quadraticBezierTo(5, 2, 4.5, -1)
      ..quadraticBezierTo(4, -5.5, 0, -5.5)
      ..quadraticBezierTo(-4, -5.5, -4, -3.5)
      ..close();
    _shape(canvas, upper, DemoStyle.shoe);
    canvas
      ..drawLine(const Offset(1, 4), const Offset(3.5, 5), DemoStyle.detail)
      ..drawLine(const Offset(0.5, 7), const Offset(3, 8), DemoStyle.detail);
  }
}
