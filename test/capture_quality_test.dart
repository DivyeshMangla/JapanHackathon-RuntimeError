import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/features/capture_quality/data/wav_decoder.dart';
import 'package:melo/features/capture_quality/domain/audio_analyzer.dart';
import 'package:melo/features/capture_quality/domain/fft.dart';
import 'package:melo/features/capture_quality/domain/motion_analyzer.dart';
import 'package:melo/features/capture_quality/domain/noise_profiler.dart';
import 'package:melo/features/capture_quality/domain/spectral_denoiser.dart';
import 'package:melo/features/capture_quality/domain/take_quality.dart';

const rate = 16000;

int samplesFor(double seconds, int sampleRate) =>
    // Whole 1024-sample blocks, so every stage sees complete hops.
    (seconds * sampleRate / 1024).round() * 1024;

Float32List tone(
  double hz,
  double seconds,
  double amplitude, {
  int sampleRate = rate,
}) => Float32List.fromList([
  for (var i = 0; i < samplesFor(seconds, sampleRate); i++)
    amplitude * sin(2 * pi * hz * i / sampleRate),
]);

Float32List noise(
  double seconds,
  double amplitude, {
  int seed = 1,
  int sampleRate = rate,
}) {
  final random = Random(seed);
  return Float32List.fromList([
    for (var i = 0; i < samplesFor(seconds, sampleRate); i++)
      amplitude * (random.nextDouble() * 2 - 1),
  ]);
}

Float32List mix(List<Float32List> signals) => Float32List.fromList([
  for (var i = 0; i < signals.first.length; i++)
    signals.fold(0.0, (sum, s) => sum + s[i]),
]);

Float32List join(List<Float32List> parts) =>
    Float32List.fromList([for (final p in parts) ...p]);

Float32List tail(
  Float32List samples,
  double seconds, {
  int sampleRate = rate,
}) => Float32List.sublistView(
  samples,
  samples.length - samplesFor(seconds, sampleRate),
);

void main() {
  group('AudioAnalyzer', () {
    test('decodes little-endian 16-bit PCM', () {
      final bytes = Uint8List.fromList([0x00, 0x40, 0x00, 0xC0]);
      expect(pcm16ToSamples(bytes), [0.5, -0.5]);
    });

    test('a full-scale sine is about -3 dBFS', () {
      expect(levelDb(tone(440, 0.1, 1)), closeTo(-3.01, 0.05));
    });

    test('the high-pass filter removes rumble but keeps voice', () {
      final filter = HighPassFilter(cutoffHz: 80, sampleRate: rate.toDouble());
      final rumble = filter.process(tone(20, 1, 0.5));
      final voice = HighPassFilter(
        cutoffHz: 80,
        sampleRate: rate.toDouble(),
      ).process(tone(200, 1, 0.5));

      expect(levelDb(rumble), lessThan(levelDb(tone(20, 1, 0.5)) - 20));
      expect(levelDb(voice), closeTo(levelDb(tone(200, 1, 0.5)), 1));
    });

    test('estimates noise floor, SNR and phonation length', () {
      final analyzer = AudioAnalyzer(sampleRate: rate, blockSize: 512);
      analyzer.add(noise(2, 0.003));
      final blocks = analyzer.add(tone(200, 3.5, 0.3));

      final quality = analyzer.quality;
      expect(quality.noiseFloorDb, lessThan(-50));
      expect(quality.snrDb, greaterThan(30));
      expect(quality.longestPhonationSec, closeTo(3.5, 0.1));
      expect(blocks.last.voiced, isTrue);
      expect(quality.clippedFraction, 0);
    });

    test('SNR clears once the sound has ended', () {
      final analyzer = AudioAnalyzer(sampleRate: rate, blockSize: 512)
        ..add(noise(2, 0.003))
        ..add(tone(200, 1, 0.3));
      expect(analyzer.quality.snrDb, isNotNull);

      analyzer.add(noise(1, 0.003, seed: 2));
      expect(analyzer.quality.snrDb, isNull);
      expect(analyzer.quality.phonationSec, 0);
    });

    test('steady background is not mistaken for voice', () {
      final analyzer = AudioAnalyzer(sampleRate: rate, blockSize: 512);
      final blocks = analyzer.add(noise(1, 0.01));
      expect(blocks.skip(5).any((b) => b.voiced), isFalse);
    });

    test('counts clipped samples', () {
      final analyzer = AudioAnalyzer(sampleRate: rate, blockSize: 512)
        ..add(Float32List.fromList(List.filled(512, 1.0)));
      expect(analyzer.quality.clippedFraction, 1);
    });
  });

  group('Fft', () {
    test('round trip returns the input', () {
      final fft = Fft(256);
      final input = noise(0.1, 1).sublist(0, 256);
      final real = Float64List.fromList(input);
      final imag = Float64List(256);
      fft
        ..forward(real, imag)
        ..inverse(real, imag);
      for (var i = 0; i < 256; i++) {
        expect(real[i], closeTo(input[i], 1e-6));
      }
    });

    test('a sine lands in its own bin', () {
      final fft = Fft(1024);
      final binHz = rate / 1024;
      final real = Float64List.fromList(
        tone(binHz * 40, 0.1, 1).sublist(0, 1024),
      );
      final imag = Float64List(1024);
      fft.forward(real, imag);
      final power = [
        for (var k = 0; k <= 512; k++) real[k] * real[k] + imag[k] * imag[k],
      ];
      expect(power.indexOf(power.reduce(max)), 40);
    });

    test('exponential integral matches reference values', () {
      expect(exponentialIntegral(0.1), closeTo(1.822923958, 1e-7));
      expect(exponentialIntegral(1), closeTo(0.219383934, 1e-7));
      expect(exponentialIntegral(5), closeTo(0.001148296, 1e-8));
    });
  });

  group('SpectralDenoiser', () {
    test('lowers steady noise and keeps the voice', () {
      final denoiser = SpectralDenoiser(sampleRate: rate);
      denoiser.process(noise(2, 0.01), speech: false);

      final background = noise(1, 0.01, seed: 2);
      final cleanedNoise = denoiser.process(background, speech: false);
      expect(
        levelDb(tail(cleanedNoise, 0.5)),
        lessThan(levelDb(tail(background, 0.5)) - 12),
      );

      final voice = tone(1000, 1, 0.3);
      final cleanedVoice = denoiser.process(
        mix([voice, noise(1, 0.01, seed: 3)]),
        speech: true,
      );
      expect(
        levelDb(tail(cleanedVoice, 0.5)),
        closeTo(levelDb(tail(voice, 0.5)), 2),
      );
    });

    test('does not learn a held vowel as noise', () {
      final denoiser = SpectralDenoiser(sampleRate: rate);
      denoiser.process(noise(1, 0.01), speech: false);
      final vowel = tone(220, 10, 0.3);
      final cleaned = denoiser.process(
        mix([vowel, noise(10, 0.01, seed: 4)]),
        speech: true,
      );
      expect(
        levelDb(tail(cleaned, 0.5)),
        closeTo(levelDb(tail(vowel, 0.5)), 2),
      );
    });
  });

  group('NoiseProfiler', () {
    const sampleRate = 44100;

    NoiseReport profile(Float32List samples, {double? levelOverride}) {
      final profiler = NoiseProfiler(
        sampleRate: sampleRate,
        blockSec: 1024 / sampleRate,
      );
      for (var start = 0; start + 1024 <= samples.length; start += 1024) {
        final block = Float32List.sublistView(samples, start, start + 1024);
        final level = levelOverride ?? levelDb(block);
        profiler.add(block, background: true, levelDb: level, floorDb: level);
      }
      return profiler.report;
    }

    Float32List background(double seconds) =>
        noise(seconds, 0.003, sampleRate: sampleRate);

    test('is not ready before it has heard the background', () {
      expect(profile(background(0.3)).ready, isFalse);
    });

    test('finds 50 Hz mains hum', () {
      final hum = mix([
        background(4),
        for (final hz in [50.0, 100.0, 150.0, 200.0])
          tone(hz, 4, 0.02, sampleRate: sampleRate),
      ]);
      final report = profile(hum);
      expect(report.hasHum, isTrue);
      expect(report.hum!.frequencyHz, 50);
    });

    test('finds 60 Hz mains hum', () {
      final hum = mix([
        background(4),
        for (final hz in [60.0, 120.0, 180.0])
          tone(hz, 4, 0.02, sampleRate: sampleRate),
      ]);
      expect(profile(hum).hum?.frequencyHz, 60);
    });

    test('finds a steady whine and reports its pitch', () {
      final whine = mix([
        background(4),
        tone(3000, 4, 0.01, sampleRate: sampleRate),
      ]);
      final report = profile(whine);
      expect(report.hasTone, isTrue);
      expect(report.tone!.frequencyHz, closeTo(3000, 15));
      expect(report.hasHum, isFalse);
    });

    test('calls white noise broadband and low hum rumble', () {
      expect(profile(background(4)).isBroadband, isTrue);
      final rumble = mix([
        background(4),
        tone(40, 4, 0.2, sampleRate: sampleRate),
      ]);
      expect(profile(rumble).hasRumble, isTrue);
      expect(profile(background(4)).hasRumble, isFalse);
    });

    test('counts short bursts but not held sounds or start-up pops', () {
      final profiler = NoiseProfiler(sampleRate: rate, blockSec: 1024 / rate);
      final block = Float32List(1024);
      void feed(double level, int blocks) {
        for (var i = 0; i < blocks; i++) {
          profiler.add(block, background: true, levelDb: level, floorDb: -60);
        }
      }

      // A pop while the microphone settles is ignored.
      feed(-30, 1);
      feed(-60, 20);
      feed(-30, 1);
      feed(-60, 5);
      feed(-30, 40);
      feed(-60, 5);
      expect(profiler.report.transients, 1);
    });

    test('reports nothing for digital silence', () {
      final report = profile(Float32List(samplesFor(4, sampleRate)));
      expect(report.ready, isTrue);
      expect(report.isBroadband, isFalse);
      expect(report.hasRumble, isFalse);
    });

    test('flags a fluctuating background', () {
      final profiler = NoiseProfiler(sampleRate: rate, blockSec: 1024 / rate);
      final block = Float32List(1024);
      for (var i = 0; i < 60; i++) {
        final level = i.isEven ? -60.0 : -50.0;
        profiler.add(block, background: true, levelDb: level, floorDb: -65);
      }
      expect(profiler.report.fluctuationDb, closeTo(5, 0.01));
      expect(profiler.report.isFluctuating, isTrue);
    });
  });

  group('TakeQuality', () {
    Float32List take(double noiseAmplitude, double voiceAmplitude) => join([
      noise(0.5, noiseAmplitude),
      mix([tone(200, 2, voiceAmplitude), noise(2, noiseAmplitude, seed: 2)]),
    ]);

    test('a quiet room gives a good take', () {
      final quality = assessTake(take(0.001, 0.3), rate);
      expect(quality.snrDb, greaterThan(TakeQuality.goodSnrDb));
      expect(quality.voicedSec, closeTo(2, 0.1));
      expect(quality.rating, TakeRating.good);
    });

    test('a noisy room makes the take poor', () {
      final quality = assessTake(take(0.03, 0.3), rate);
      expect(quality.issues, contains(TakeIssue.noisy));
      expect(quality.rating, TakeRating.poor);
    });

    test('flags clipping, silence and movement', () {
      final loud = Float32List.fromList([
        for (final s in take(0.001, 1.2)) s.clamp(-1.0, 1.0),
      ]);
      expect(assessTake(loud, rate).issues, contains(TakeIssue.clipped));
      expect(
        assessTake(noise(2, 0.001), rate).issues,
        contains(TakeIssue.noVoice),
      );
      expect(assessTake(take(0.001, 0.3), rate).withMotion(0.5).issues, [
        TakeIssue.moved,
      ]);
    });
  });

  group('decodeWav', () {
    Uint8List wav() {
      final bytes = BytesBuilder();
      void tag(String t) => bytes.add(t.codeUnits);
      void u32(int v) => bytes.add(
        (ByteData(4)..setUint32(0, v, Endian.little)).buffer.asUint8List(),
      );
      void u16(int v) => bytes.add(
        (ByteData(2)..setUint16(0, v, Endian.little)).buffer.asUint8List(),
      );

      tag('RIFF');
      u32(4 + 12 + 24 + 12);
      tag('WAVE');
      tag('LIST');
      u32(4);
      tag('INFO');
      tag('fmt ');
      u32(16);
      u16(1);
      u16(1);
      u32(44100);
      u32(88200);
      u16(2);
      u16(16);
      tag('data');
      u32(4);
      bytes.add([0x00, 0x40, 0x00, 0xC0]);
      return bytes.toBytes();
    }

    test('reads samples past extra chunks', () {
      final decoded = decodeWav(wav());
      expect(decoded.sampleRate, 44100);
      expect(decoded.samples, [0.5, -0.5]);
    });

    test('rejects files that are not WAV', () {
      expect(
        () => decodeWav(Uint8List.fromList(List.filled(16, 0))),
        throwsFormatException,
      );
    });
  });

  group('MotionAnalyzer', () {
    test('tilt reads flat and upright phones correctly', () {
      final flat = Tilt.fromGravity(const Vector3(0, 0, 9.81));
      expect(flat.pitchDeg, closeTo(0, 0.01));
      expect(flat.rollDeg, closeTo(0, 0.01));

      final upright = Tilt.fromGravity(const Vector3(0, 9.81, 0));
      expect(upright.rollDeg, closeTo(90, 0.01));
      expect(upright.deviationFrom(flat), closeTo(90, 0.01));
    });

    test('motion is flagged when rotation exceeds the threshold', () {
      final still = MotionAnalyzer(windowSamples: 10);
      for (var i = 0; i < 10; i++) {
        still.addGyro(const Vector3(0.01, 0, 0));
      }
      expect(still.reading.moving, isFalse);

      final moving = MotionAnalyzer(windowSamples: 10);
      for (var i = 0; i < 10; i++) {
        moving.addGyro(const Vector3(0.5, 0.2, 0));
      }
      expect(moving.reading.moving, isTrue);
    });
  });
}
