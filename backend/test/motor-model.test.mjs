import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createMotorAnalyzer, motorExercises, photoType } from '../src/motor.mjs';
import { motorReference } from '../src/motor-reference.mjs';

test('vision adapter sends image and task, validates model JSON and does not expose extra fields', async t => {
  let request;
  let answer = {
    imageQuality: 'usable',
    observations: 'Visible lines.',
    comparison: 'Three lines match the requested count; the gaps vary.',
    alignment: 'developing',
    formation: 'consistent',
    spacing: 'not_assessable',
    suggestion: 'Rest after each line.',
    unexpected: 'discard',
  };
  const server = createServer(async (req, res) => {
    let raw = '';
    for await (const chunk of req) raw += chunk;
    request = JSON.parse(raw);
    res.setHeader('Content-Type', 'application/json');
    res.end(JSON.stringify({ message: { content: JSON.stringify(answer) } }));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => {
    server.closeAllConnections();
    server.close();
  });
  const analyze = createMotorAnalyzer({
    endpoint: `http://127.0.0.1:${server.address().port}/api/chat`,
    model: 'vision-test',
  });
  const photo = Buffer.from('synthetic image for protocol test');
  const report = await analyze(photo, motorExercises[0]);
  assert.equal(report.model, 'vision-test');
  assert.equal(report.unexpected, undefined);
  assert.equal(report.expectedResult, motorExercises[0].target);
  assert.equal(report.comparison, answer.comparison);
  assert.equal(request.messages[1].images[0], photo.toString('base64'));
  assert.equal(request.messages[1].images[1], motorReference(motorExercises[0]).toString('base64'));
  assert.equal(photoType(Buffer.from(request.messages[1].images[1], 'base64')), 'image/png');
  assert.ok(request.messages[1].content.includes('Three horizontal lines'));
  assert.equal(request.stream, false);
  assert.equal(request.format.type, 'object');
  answer = { ...answer, imageQuality: 'retake' };
  const retake = await analyze(photo, motorExercises[0]);
  assert.equal(retake.formation, 'not_assessable');
  assert.equal(retake.comparison, 'Unable to compare from this image.');
  answer = { ...answer, alignment: 'diagnosed' };
  await assert.rejects(() => analyze(photo, motorExercises[0]), /Invalid model report/);
});

test('model stays local and photo validation rejects fake images', () => {
  assert.throws(
    () => createMotorAnalyzer({ endpoint: 'https://hosted.example/api/chat' }),
    /loopback/,
  );
  assert.equal(photoType(Buffer.from([255, 216, 255, 217])), null);
  assert.equal(photoType(Buffer.alloc(24)), null);
  for (const exercise of motorExercises) {
    assert.equal(photoType(motorReference(exercise)), 'image/png');
  }
});

test('original camera JPEG trailers are retained, while truncated scans are rejected', () => {
  const header = Buffer.from([
    255,216, 255,192,0,11,8,0,128,0,128,1,1,17,0,
    255,218,0,8,1,1,0,0,63,0,
  ]);
  const jpeg = Buffer.concat([header, Buffer.from([1,2,3,255,217])]);
  assert.equal(photoType(jpeg), 'image/jpeg');
  assert.equal(photoType(Buffer.concat([jpeg, Buffer.from('camera motion-photo trailer')])), 'image/jpeg');
  assert.equal(photoType(jpeg.subarray(0, jpeg.length - 2)), null);
});
