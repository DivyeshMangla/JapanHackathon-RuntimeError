import 'dart:math';
import 'dart:typed_data';

/// In-place radix-2 complex FFT of a fixed power-of-two size. Twiddles and
/// the bit-reversal table are computed once, since the live pipeline runs
/// dozens of transforms a second.
class Fft {
  Fft(this.size)
    : assert(size > 1 && size & (size - 1) == 0, 'size must be a power of 2'),
      _cos = Float64List(size ~/ 2),
      _sin = Float64List(size ~/ 2),
      _reversed = Int32List(size) {
    for (var i = 0; i < size ~/ 2; i++) {
      _cos[i] = cos(2 * pi * i / size);
      _sin[i] = sin(2 * pi * i / size);
    }
    final bits = (log(size) / ln2).round();
    for (var i = 0; i < size; i++) {
      var r = 0;
      for (var b = 0; b < bits; b++) {
        r = (r << 1) | ((i >> b) & 1);
      }
      _reversed[i] = r;
    }
  }

  final int size;
  final Float64List _cos;
  final Float64List _sin;
  final Int32List _reversed;

  /// Forward transform of ([real], [imag]), overwriting both.
  void forward(Float64List real, Float64List imag) =>
      _transform(real, imag, -1);

  /// Inverse transform, including the 1/size scaling.
  void inverse(Float64List real, Float64List imag) {
    _transform(real, imag, 1);
    for (var i = 0; i < size; i++) {
      real[i] /= size;
      imag[i] /= size;
    }
  }

  void _transform(Float64List real, Float64List imag, int sign) {
    for (var i = 0; i < size; i++) {
      final j = _reversed[i];
      if (j > i) {
        final tr = real[i];
        real[i] = real[j];
        real[j] = tr;
        final ti = imag[i];
        imag[i] = imag[j];
        imag[j] = ti;
      }
    }
    for (var length = 2; length <= size; length <<= 1) {
      final half = length >> 1;
      final stride = size ~/ length;
      for (var start = 0; start < size; start += length) {
        for (var k = 0; k < half; k++) {
          final wr = _cos[k * stride];
          final wi = sign * _sin[k * stride];
          final a = start + k;
          final b = a + half;
          final xr = real[b] * wr - imag[b] * wi;
          final xi = real[b] * wi + imag[b] * wr;
          real[b] = real[a] - xr;
          imag[b] = imag[a] - xi;
          real[a] += xr;
          imag[a] += xi;
        }
      }
    }
  }
}

/// Periodic Hann window, which sums to a constant at 50% overlap.
Float64List hannWindow(int size) => Float64List.fromList([
  for (var i = 0; i < size; i++) 0.5 - 0.5 * cos(2 * pi * i / size),
]);

/// Power spectral density in units per Hz, so spectra taken with different
/// frame sizes line up on one chart. [power] holds |X|² per bin and
/// [windowEnergy] the sum of the squared window.
double toDensity(double power, double windowEnergy, int sampleRate) =>
    power / (windowEnergy * sampleRate);

/// Decibels of a power value, floored so silence stays finite.
double powerDb(double power) => 10 * log(max(power, 1e-30)) / ln10;
