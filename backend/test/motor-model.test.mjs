import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createMotorAnalyzer, motorExercises, photoType } from '../src/motor.mjs';

test('vision adapter sends image and task, validates model JSON and does not expose extra fields', async t => {
  let request;
  let answer = {
    imageQuality: 'usable',
    observations: 'Visible lines.',
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
  assert.equal(request.messages[1].images[0], photo.toString('base64'));
  assert.ok(request.messages[1].content.includes('Three horizontal lines'));
  assert.equal(request.stream, false);
  assert.equal(request.format.type, 'object');
  answer = { ...answer, imageQuality: 'retake' };
  const retake = await analyze(photo, motorExercises[0]);
  assert.equal(retake.formation, 'not_assessable');
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
});
