import test from 'node:test';
import assert from 'node:assert/strict';
import { detectMotorLines, prepareMotorImage } from '../src/motor-image.mjs';
import { createMotorAnalyzer, motorExercises } from '../src/motor.mjs';
import { drawingPhoto } from './fixtures/motor-photos.mjs';

function drawing({ count = 3, slope = 0, faint = false, shadow = false } = {}) {
  const width = 320, height = 240, pixels = new Uint8Array(width * height);
  for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
    pixels[y * width + x] = 240 - (shadow ? Math.round(x / 4) : 0);
  }
  for (let n = 0; n < count; n++) for (let x = 40; x < 280; x++) {
    const y = Math.round(35 + n * 45 + slope * (x - 40));
    for (let dy = 0; dy < 2; dy++) pixels[(y + dy) * width + x] -= faint ? 20 : 140;
  }
  return { width, height, pixels };
}

test('line candidates track actual counts, including faint and slanted strokes in uneven lighting', () => {
  for (const count of [0, 1, 2, 3, 4]) for (const slope of [0, 0.15]) {
    const result = detectMotorLines(drawing({ count, slope, faint: true, shadow: true }));
    assert.equal(result.candidates.length, count);
    for (const candidate of result.candidates) assert.ok(Math.abs(candidate.angleDegrees - Math.atan(slope) * 180 / Math.PI) < 2);
  }
});

test('page boundaries, isolated specks and a rounded loop are not horizontal line candidates', () => {
  const input = drawing({ count: 0 });
  for (let x = 0; x < input.width; x++) input.pixels[x] = 0;
  for (let t = 0; t < 6.29; t += 0.005) {
    const x = Math.round(160 + 70 * Math.cos(t)), y = Math.round(120 + 70 * Math.sin(t));
    input.pixels[y * input.width + x] = 0;
  }
  input.pixels[30 * input.width + 30] = 0;
  assert.equal(detectMotorLines(input).candidates.length, 0);
});

test('bright paper with faint pencil gets contrast enhancement and line evidence', async () => {
  const photo = drawingPhoto({ background: 245, ink: 220 });
  const copy = Buffer.from(photo);
  const result = await prepareMotorImage(photo, 'image/png');
  assert.equal(result.enhancement.applied, true);
  assert.equal(result.lineDetection.candidates.length, 3);
  assert.deepEqual(photo, copy);
});

test('disagreeing stages cannot publish contradictory prose or confident ratings', async () => {
  const requests = [];
  const quality = { imageQuality: 'usable', relevance: 'drawing_attempt', qualityFlags: [], explanation: 'Readable paper.', countEvidence: 'One upper line and one lower line.', observedCount: 2 };
  const comparison = { imageQuality: 'usable', qualityFlags: [], observedCount: 3, observations: 'Three perfect lines.', comparison: 'Matches all three.', alignment: 'consistent', formation: 'consistent', spacing: 'consistent', evidence: { alignment: 'Parallel.', formation: 'Three continuous lines.', spacing: 'Equal gaps.' }, suggestion: 'Move on.' };
  const analyze = createMotorAnalyzer({ provider: 'ollama', fetchImpl: async (_url, options) => {
    requests.push(JSON.parse(options.body));
    return new Response(JSON.stringify({ message: { content: JSON.stringify(requests.length === 1 ? quality : comparison) } }));
  } });
  const report = await analyze(drawingPhoto(), motorExercises[0]);
  assert.match(requests[0].messages[1].content, /candidate line regions/);
  assert.match(requests[1].messages[1].content, /One upper line and one lower line/);
  assert.equal(report.observedCount, 2);
  assert.equal(report.observations, quality.countEvidence);
  assert.match(report.comparison, /disagreed/);
  for (const key of ['alignment', 'formation', 'spacing']) {
    assert.equal(report[key], 'not_assessable');
    assert.equal(report.evidence[key], '');
  }
});
