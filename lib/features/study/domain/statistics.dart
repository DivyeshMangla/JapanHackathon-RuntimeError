import 'dart:math' as math;

/// Mean, standard deviation, median and n for one variable.
class Descriptive {
  const Descriptive({
    required this.n,
    required this.mean,
    required this.sd,
    required this.median,
  });

  /// Null when [values] is empty. The standard deviation is the sample
  /// (n - 1) estimate and is null for a single value.
  static Descriptive? of(Iterable<double> values) {
    final sorted = values.toList()..sort();
    final n = sorted.length;
    if (n == 0) return null;
    final mean = sorted.reduce((a, b) => a + b) / n;
    final median = n.isOdd
        ? sorted[n ~/ 2]
        : (sorted[n ~/ 2 - 1] + sorted[n ~/ 2]) / 2;
    double? sd;
    if (n > 1) {
      final squares = sorted.fold<double>(
        0,
        (sum, v) => sum + (v - mean) * (v - mean),
      );
      sd = math.sqrt(squares / (n - 1));
    }
    return Descriptive(n: n, mean: mean, sd: sd, median: median);
  }

  final int n;
  final double mean;
  final double? sd;
  final double median;
}

/// A count out of a total, reported as a percentage.
class Proportion {
  const Proportion(this.count, this.total);

  final int count;
  final int total;

  /// 0..1, or null when the total is zero.
  double? get rate => total == 0 ? null : count / total;
}

class PairedTTestResult {
  const PairedTTestResult({
    required this.n,
    required this.meanDifference,
    required this.sdDifference,
    required this.t,
    required this.df,
    required this.p,
  });

  final int n;

  /// Mean of after - before.
  final double meanDifference;
  final double sdDifference;
  final double t;
  final int df;

  /// Two-sided.
  final double p;
}

class WilcoxonResult {
  const WilcoxonResult({
    required this.n,
    required this.wPlus,
    required this.wMinus,
    required this.p,
    required this.exact,
  });

  /// Pairs with a non-zero difference; zero differences are dropped.
  final int n;

  /// Rank sums of positive (after > before) and negative differences.
  final double wPlus;
  final double wMinus;

  /// Two-sided.
  final double p;

  /// True when p comes from the exact null distribution (no ties, n <= 25);
  /// otherwise from the normal approximation with tie and continuity
  /// corrections.
  final bool exact;
}

/// Paired pre/post comparisons named in the protocol's analysis plan. Both
/// tests are reported so the analyst can choose by the distribution of the
/// differences; the app does not choose for them.
abstract final class PairedTests {
  /// Null with fewer than two pairs, or when every difference is identical
  /// (the statistic is undefined).
  static PairedTTestResult? tTest(List<double> before, List<double> after) {
    final diffs = _differences(before, after);
    final n = diffs.length;
    if (n < 2) return null;
    final summary = Descriptive.of(diffs)!;
    final sd = summary.sd!;
    if (sd == 0) return null;
    final t = summary.mean / (sd / math.sqrt(n));
    final df = n - 1;
    return PairedTTestResult(
      n: n,
      meanDifference: summary.mean,
      sdDifference: sd,
      t: t,
      df: df,
      p: _studentTwoSided(t, df),
    );
  }

  /// Null when no pair differs.
  static WilcoxonResult? wilcoxon(List<double> before, List<double> after) {
    final diffs = [
      for (final d in _differences(before, after))
        if (d != 0) d,
    ];
    final n = diffs.length;
    if (n == 0) return null;

    final order = List.generate(n, (i) => i)
      ..sort((a, b) => diffs[a].abs().compareTo(diffs[b].abs()));
    final ranks = List<double>.filled(n, 0);
    var tieCorrection = 0.0;
    var hasTies = false;
    for (var i = 0; i < n;) {
      var j = i;
      while (j + 1 < n && diffs[order[j + 1]].abs() == diffs[order[i]].abs()) {
        j++;
      }
      final size = j - i + 1;
      if (size > 1) {
        hasTies = true;
        tieCorrection += (size * size * size - size) / 48;
      }
      final averageRank = (i + j) / 2 + 1;
      for (var k = i; k <= j; k++) {
        ranks[order[k]] = averageRank;
      }
      i = j + 1;
    }

    var wPlus = 0.0;
    var wMinus = 0.0;
    for (var i = 0; i < n; i++) {
      if (diffs[i] > 0) {
        wPlus += ranks[i];
      } else {
        wMinus += ranks[i];
      }
    }

    final exact = !hasTies && n <= 25;
    final double p;
    if (exact) {
      p = _wilcoxonExactTwoSided(math.min(wPlus, wMinus).round(), n);
    } else {
      final mean = n * (n + 1) / 4;
      final variance = n * (n + 1) * (2 * n + 1) / 24 - tieCorrection;
      if (variance <= 0) {
        p = 1;
      } else {
        final deviation = (wPlus - mean).abs() - 0.5;
        final z = math.max(0, deviation) / math.sqrt(variance);
        p = math.min(1, 2 * (1 - _normalCdf(z.toDouble())));
      }
    }
    return WilcoxonResult(
      n: n,
      wPlus: wPlus,
      wMinus: wMinus,
      p: p,
      exact: exact,
    );
  }

  static List<double> _differences(List<double> before, List<double> after) {
    if (before.length != after.length) {
      throw ArgumentError('before and after must be paired');
    }
    return [for (var i = 0; i < before.length; i++) after[i] - before[i]];
  }

  /// P(W <= w) * 2 under H0, by counting the 2^n equally likely sign
  /// assignments that give each rank sum.
  static double _wilcoxonExactTwoSided(int w, int n) {
    final maxSum = n * (n + 1) ~/ 2;
    var counts = List<double>.filled(maxSum + 1, 0)..[0] = 1;
    for (var rank = 1; rank <= n; rank++) {
      final next = List<double>.from(counts);
      for (var s = rank; s <= maxSum; s++) {
        next[s] += counts[s - rank];
      }
      counts = next;
    }
    var tail = 0.0;
    for (var s = 0; s <= w; s++) {
      tail += counts[s];
    }
    return math.min(1, 2 * tail / math.pow(2, n));
  }

  static double _studentTwoSided(double t, int df) {
    final x = df / (df + t * t);
    return _regularizedBeta(x, df / 2, 0.5);
  }

  static double _normalCdf(double z) => 0.5 * (1 + _erf(z / math.sqrt2));

  /// Abramowitz and Stegun 7.1.26; absolute error below 1.5e-7.
  static double _erf(double x) {
    final sign = x < 0 ? -1 : 1;
    final ax = x.abs();
    final t = 1 / (1 + 0.3275911 * ax);
    final y =
        1 -
        (((((1.061405429 * t - 1.453152027) * t) + 1.421413741) * t -
                        0.284496736) *
                    t +
                0.254829592) *
            t *
            math.exp(-ax * ax);
    return sign * y;
  }

  /// Regularized incomplete beta I_x(a, b) by Lentz's continued fraction.
  static double _regularizedBeta(double x, double a, double b) {
    if (x <= 0) return 0;
    if (x >= 1) return 1;
    final front = math.exp(
      _logGamma(a + b) -
          _logGamma(a) -
          _logGamma(b) +
          a * math.log(x) +
          b * math.log(1 - x),
    );
    if (x < (a + 1) / (a + b + 2)) {
      return front * _betaFraction(x, a, b) / a;
    }
    return 1 - front * _betaFraction(1 - x, b, a) / b;
  }

  static double _betaFraction(double x, double a, double b) {
    const tiny = 1e-300;
    const epsilon = 1e-14;
    var c = 1.0;
    var d = 1 - (a + b) * x / (a + 1);
    if (d.abs() < tiny) d = tiny;
    d = 1 / d;
    var h = d;
    for (var m = 1; m <= 300; m++) {
      final m2 = 2 * m;
      var aa = m * (b - m) * x / ((a + m2 - 1) * (a + m2));
      d = 1 + aa * d;
      if (d.abs() < tiny) d = tiny;
      c = 1 + aa / c;
      if (c.abs() < tiny) c = tiny;
      d = 1 / d;
      h *= d * c;
      aa = -(a + m) * (a + b + m) * x / ((a + m2) * (a + m2 + 1));
      d = 1 + aa * d;
      if (d.abs() < tiny) d = tiny;
      c = 1 + aa / c;
      if (c.abs() < tiny) c = tiny;
      d = 1 / d;
      final delta = d * c;
      h *= delta;
      if ((delta - 1).abs() < epsilon) break;
    }
    return h;
  }

  /// Lanczos approximation (g = 7, n = 9).
  static double _logGamma(double x) {
    const coefficients = [
      0.99999999999980993,
      676.5203681218851,
      -1259.1392167224028,
      771.32342877765313,
      -176.61502916214059,
      12.507343278686905,
      -0.13857109526572012,
      9.9843695780195716e-6,
      1.5056327351493116e-7,
    ];
    if (x < 0.5) {
      return math.log(math.pi / math.sin(math.pi * x).abs()) - _logGamma(1 - x);
    }
    final z = x - 1;
    var sum = coefficients[0];
    for (var i = 1; i < coefficients.length; i++) {
      sum += coefficients[i] / (z + i);
    }
    final t = z + 7.5;
    return 0.5 * math.log(2 * math.pi) +
        (z + 0.5) * math.log(t) -
        t +
        math.log(sum);
  }
}
