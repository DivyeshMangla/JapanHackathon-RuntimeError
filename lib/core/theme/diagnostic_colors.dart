import 'package:flutter/material.dart';

/// Oscilloscope palette for the developer sensor screen only. Kept apart
/// from [AppColors] because patient-facing screens follow design.md.
abstract final class DiagnosticColors {
  static const background = Color(0xFF050805);
  static const panel = Color(0xFF0A120B);
  static const border = Color(0xFF1C3D22);
  static const grid = Color(0xFF14291A);

  /// Primary trace and readouts.
  static const trace = Color(0xFF39E75F);

  /// Secondary trace, such as the raw signal behind the filtered one.
  static const traceDim = Color(0xFF1F7A39);

  /// The denoised signal, set apart from the raw input.
  static const clean = Color(0xFF4FD8EB);

  /// Reference lines such as the noise floor.
  static const amber = Color(0xFFFFB020);
  static const alert = Color(0xFFFF5A4D);

  static const text = Color(0xFFC4F5CF);
  static const textDim = Color(0xFF6FAF7D);

  /// Shading under the noise floor.
  static const noiseFill = Color(0x26FFB020);
}
