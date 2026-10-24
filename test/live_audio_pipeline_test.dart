import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:melo/features/diagnostics/domain/live_audio_pipeline.dart';

void main() {
  test('produces aligned frames and reports noise removed', () {
    final random = Random(1);
    final background = Float32List.fromList([
      for (var i = 0; i < 48 * 1024; i++) 0.01 * (random.nextDouble() * 2 - 1),
    ]);
    final pipeline = LiveAudioPipeline(sampleRate: 16000);
    final frames = pipeline.add(background);

    expect(frames, hasLength(48));
    expect(
      frames.last.rawColumns,
      hasLength(LiveAudioPipeline.columnsPerBlock),
    );
    expect(frames.last.cleanLevelDb, lessThan(frames.last.levelDb - 10));
    expect(pipeline.cleaning.noiseRemovedDb, greaterThan(10));
    expect(pipeline.cleaning.cleanSnrDb, isNull);

    final spectrum = pipeline.spectrum;
    expect(spectrum.input, hasLength(SpectrumView.points));
    expect(spectrum.noise, hasLength(SpectrumView.points));
  });

  test('log spectrum keeps narrow peaks', () {
    final density = Float64List(513)..[100] = 1;
    final points = logSpectrum(density, 20);
    expect(points.where((db) => db > -1), hasLength(1));
  });

  test('wave columns hold each slice min and max', () {
    final samples = Float32List.fromList([0.5, -0.25, 0.125, -0.75]);
    expect(waveColumns(samples, 2), [
      (min: -0.25, max: 0.5),
      (min: -0.75, max: 0.125),
    ]);
  });
}
