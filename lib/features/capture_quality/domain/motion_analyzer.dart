import 'dart:math';

class Vector3 {
  const Vector3(this.x, this.y, this.z);

  static const zero = Vector3(0, 0, 0);

  final double x;
  final double y;
  final double z;

  double get magnitude => sqrt(x * x + y * y + z * z);
}

/// Phone tilt from gravity, in degrees. Pitch tips the top edge toward or
/// away from the user; roll tips it left or right.
class Tilt {
  const Tilt({required this.pitchDeg, required this.rollDeg});

  factory Tilt.fromGravity(Vector3 g) => Tilt(
    pitchDeg: atan2(-g.x, sqrt(g.y * g.y + g.z * g.z)) * 180 / pi,
    rollDeg: atan2(g.y, g.z) * 180 / pi,
  );

  final double pitchDeg;
  final double rollDeg;

  /// Largest angle difference from [other], for "same angle as last time".
  double deviationFrom(Tilt other) =>
      max((pitchDeg - other.pitchDeg).abs(), (rollDeg - other.rollDeg).abs());
}

class MotionReading {
  const MotionReading({
    required this.gyro,
    required this.userAccel,
    required this.tilt,
    required this.gyroRms,
    required this.accelRms,
    required this.moving,
  });

  /// Angular velocity in rad/s.
  final Vector3 gyro;

  /// Acceleration without gravity, in m/s².
  final Vector3 userAccel;
  final Tilt tilt;

  /// RMS over the last second (research doc 3.3).
  final double gyroRms;
  final double accelRms;
  final bool moving;
}

/// Tracks recent motion and tilt. The thresholds are provisional; the
/// research doc calls for device-calibrated values.
class MotionAnalyzer {
  MotionAnalyzer({required this.windowSamples});

  static const gyroThreshold = 0.15;
  static const accelThreshold = 0.4;

  /// Low-pass weight for separating gravity from hand movement.
  static const _gravityWeight = 0.1;

  final int windowSamples;
  final _gyroSquares = <double>[];
  final _accelSquares = <double>[];
  Vector3 _gyro = Vector3.zero;
  Vector3 _userAccel = Vector3.zero;
  Vector3? _gravity;

  void addGyro(Vector3 v) {
    _gyro = v;
    _push(_gyroSquares, v.magnitude);
  }

  void addUserAccel(Vector3 v) {
    _userAccel = v;
    _push(_accelSquares, v.magnitude);
  }

  void addAccel(Vector3 v) {
    final g = _gravity;
    _gravity = g == null
        ? v
        : Vector3(
            g.x + _gravityWeight * (v.x - g.x),
            g.y + _gravityWeight * (v.y - g.y),
            g.z + _gravityWeight * (v.z - g.z),
          );
  }

  MotionReading get reading {
    final gyroRms = _rms(_gyroSquares);
    final accelRms = _rms(_accelSquares);
    return MotionReading(
      gyro: _gyro,
      userAccel: _userAccel,
      tilt: Tilt.fromGravity(_gravity ?? const Vector3(0, 0, 9.81)),
      gyroRms: gyroRms,
      accelRms: accelRms,
      moving: gyroRms > gyroThreshold || accelRms > accelThreshold,
    );
  }

  void _push(List<double> window, double magnitude) {
    window.add(magnitude * magnitude);
    if (window.length > windowSamples) window.removeAt(0);
  }

  static double _rms(List<double> squares) => squares.isEmpty
      ? 0
      : sqrt(squares.reduce((a, b) => a + b) / squares.length);
}
