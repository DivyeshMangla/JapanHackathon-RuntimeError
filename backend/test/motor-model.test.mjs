import test from 'node:test';
import assert from 'node:assert/strict';
import { createServer } from 'node:http';
import { createMotorAnalyzer, motorExercises, photoType, assessMotorPhoto } from '../src/motor.mjs';
import { motorReference } from '../src/motor-reference.mjs';
import { prepareMotorImage } from '../src/motor-image.mjs';
import { drawingPhoto } from './fixtures/motor-photos.mjs';

// Exercises the vision model's own count, used when no clear ink is measured.
const withoutMeasuredCount = async (...args) => ({ ...await prepareMotorImage(...args), markCount: null });

test('vision adapter sends image and task, validates model JSON and does not expose extra fields', async t => {
  let request, blindCount = 3;
  let answer = {
    imageQuality: 'usable',
    qualityFlags: [],
    observedCount: 3,
    evidence: {alignment:'The three lines slope slightly relative to the paper edge.',formation:'All three lines are visibly continuous.',spacing:''},
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
    const quality = { imageQuality: 'usable', relevance: 'drawing_attempt', qualityFlags: [], explanation: 'Marks are visible on paper.', countEvidence: 'Lines at the top, middle and bottom.', observedCount: blindCount };
    res.end(JSON.stringify({ message: { content: JSON.stringify(request.format.properties.relevance ? quality : answer) } }));
  });
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  t.after(() => {
    server.closeAllConnections();
    server.close();
  });
  const analyze = createMotorAnalyzer({
    provider: 'ollama',
    endpoint: `http://127.0.0.1:${server.address().port}/api/chat`,
    model: 'vision-test',
    prepareImage: withoutMeasuredCount,
  });
  const photo = motorReference(motorExercises[0]);
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
  assert.ok(request.messages[1].content.includes('found 3 marks'));
  blindCount = 2;
  answer = { ...answer, observedCount: 2 };
  const mismatch = await analyze(photo,motorExercises[0]);
  assert.equal(mismatch.formation,'developing');
  assert.equal(mismatch.observedCount,2);
  blindCount = 0;
  answer = { ...answer, observedCount: 0 };
  const wrongDrawing = await analyze(photo,motorExercises[0]);
  assert.equal(wrongDrawing.imageQuality,'usable');
  assert.equal(wrongDrawing.formation,'emerging');
  blindCount = 3;
  answer = { ...answer, observedCount: 3 };
  answer = { ...answer, evidence:{...answer.evidence,formation:''} };
  const unsupported = await analyze(photo,motorExercises[0]);
  assert.equal(unsupported.formation,'not_assessable');
  answer = { ...answer, imageQuality: 'usable',qualityFlags:['blurred'] };
  const blurred = await analyze(photo,motorExercises[0]);
  assert.equal(blurred.imageQuality,'retake');
  assert.equal(blurred.alignment,'not_assessable');
  answer = { ...answer, imageQuality: 'retake' };
  const retake = await analyze(photo, motorExercises[0]);
  assert.equal(retake.formation, 'not_assessable');
  assert.equal(retake.comparison, 'Unable to compare from this image.');
  answer = { ...answer, alignment: 'diagnosed' };
  await assert.rejects(() => analyze(photo, motorExercises[0]), /Invalid model report/);
});

test('model stays local and photo validation rejects fake images', () => {
  assert.throws(
    () => createMotorAnalyzer({ provider: 'ollama', endpoint: 'https://hosted.example/api/chat' }),
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

test('uniform and undersized PNGs abstain before any vision-model request', async () => {
  const blank = motorReference({id:'motor-lines',strokes:[]});
  assert.equal(assessMotorPhoto(blank).status,'retake');
  const checked = assessMotorPhoto(motorReference(motorExercises[0]));
  assert.equal(checked.status,'checked');assert.equal(checked.pixelRange,255);
  const analyze = createMotorAnalyzer({provider:'ollama',endpoint:'http://127.0.0.1:1/api/chat'});
  const report = await analyze(blank,motorExercises[0]);
  assert.equal(report.model,'not_called');assert.equal(report.formation,'not_assessable');
  assert.equal(report.observedCount,null);
  assert.equal(report.imageQuality,'retake');
});

test('dark visible drawings get a tonal analysis copy and retain original bytes', async () => {
  const photo = drawingPhoto({ background: 40, ink: 10 });
  const original = Buffer.from(photo);
  const checked = assessMotorPhoto(photo);
  assert.equal(checked.status, 'checked');
  assert.ok(checked.meanLuminance < 110);
  const prepared = await prepareMotorImage(photo, 'image/png');
  assert.equal(prepared.enhancement.applied, true);
  assert.equal(prepared.enhancement.originalPreserved, true);
  assert.equal(assessMotorPhoto(prepared.enhanced).pixelRange, 255);
  assert.deepEqual(photo, original);
});

test('Groq vision uses a fixed HTTPS endpoint, quality-first gate and original/reference/enhanced evidence', async () => {
  const requests = [];
  const quality = { imageQuality: 'usable', relevance: 'drawing_attempt', qualityFlags: [], explanation: 'Dim ink is readable in both copies.', countEvidence: 'Three marks stacked vertically.', observedCount: 3 };
  const comparison = { imageQuality: 'usable', qualityFlags: [], observedCount: 3, observations: 'Three horizontal marks.', comparison: 'Three marks match the target count.', alignment: 'developing', formation: 'consistent', spacing: 'developing', evidence: { alignment: 'The bottom mark slopes.', formation: 'Three continuous lines.', spacing: 'The upper gap is larger.' }, suggestion: 'Practise one line with a rest.' };
  const analyze = createMotorAnalyzer({ provider: 'groq', apiKey: 'test-key', fetchImpl: async (url, options) => {
    const body = JSON.parse(options.body);
    requests.push({ url: String(url), options, body });
    return new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify(requests.length === 1 ? quality : comparison) } }] }));
  } });
  assert.equal(analyze.externalProvider, 'groq');
  const photo = drawingPhoto({ background: 40, ink: 10 });
  const report = await analyze(photo, motorExercises[0], { canUseHosted: async () => true });
  assert.equal(requests.length, 2);
  assert.equal(requests[0].url, 'https://api.groq.com/openai/v1/chat/completions');
  assert.equal(requests[0].options.headers.Authorization, 'Bearer test-key');
  assert.equal(requests[0].body.model, 'qwen/qwen3.8-27b');
  assert.equal(requests[0].body.response_format.type, 'json_object');
  const firstImages = requests[0].body.messages[1].content.filter(item => item.type === 'image_url');
  assert.equal(firstImages.length, 2);
  assert.equal(firstImages[0].image_url.url, `data:image/png;base64,${photo.toString('base64')}`);
  const compareImages = requests[1].body.messages[1].content.filter(item => item.type === 'image_url');
  assert.equal(compareImages.length, 3);
  assert.equal(compareImages[1].image_url.url, `data:image/png;base64,${motorReference(motorExercises[0]).toString('base64')}`);
  assert.equal(report.provider, 'groq');
  assert.equal(report.enhancement.applied, true);
  assert.equal(report.formation, 'consistent');
});

test('unrelated and unreadable photographs request replacement before any comparison call', async () => {
  for (const relevance of ['unrelated_photo', 'uncertain']) {
    let calls = 0;
    const analyze = createMotorAnalyzer({ provider: 'groq', apiKey: 'test-key', fetchImpl: async () => {
      calls++;
      return new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify({ imageQuality: 'retake', relevance, qualityFlags: relevance === 'uncertain' ? ['too_dark'] : ['unrelated'], explanation: 'Cannot read drawing marks.', countEvidence: '', observedCount: null }) } }] }));
    } });
    const report = await analyze(drawingPhoto(), motorExercises[0], { canUseHosted: () => true });
    assert.equal(calls, 1);
    assert.equal(report.retakeReason, relevance === 'unrelated_photo' ? 'unrelated_photo' : 'unreadable_photo');
    assert.equal(report.observedCount, null);
    assert.equal(report.formation, 'not_assessable');
  }
});

test('hosted vision requires permission and rechecks it for every outgoing stage', async () => {
  let calls = 0, allowed = false;
  const analyze = createMotorAnalyzer({ provider: 'groq', apiKey: 'test-key', fetchImpl: async () => {
    calls++; allowed = false;
    return new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify({ imageQuality: 'usable', relevance: 'drawing_attempt', qualityFlags: [], explanation: 'Visible lines.', countEvidence: 'Three lines.', observedCount: 3 }) } }] }));
  } });
  const context = { canUseHosted: () => allowed };
  await assert.rejects(() => analyze(drawingPhoto(), motorExercises[0], context), /permission/);
  assert.equal(calls, 0);
  allowed = true;
  await assert.rejects(() => analyze(drawingPhoto(), motorExercises[0], context), /permission/);
  assert.equal(calls, 1);
  const unconfigured = createMotorAnalyzer({ provider: 'groq', apiKey: '', fetchImpl: async () => { throw new Error('Must not send'); } });
  await assert.rejects(() => unconfigured(drawingPhoto(), motorExercises[0], { canUseHosted: () => true }), /not configured/);
});

test('separate ink marks measured from pixels override counts the vision model gives', async () => {
  const requests = [];
  const quality = { imageQuality: 'usable', relevance: 'drawing_attempt', qualityFlags: [], explanation: 'Readable lines.', countEvidence: 'Two lines.', observedCount: 2 };
  const comparison = { imageQuality: 'usable', qualityFlags: [], observedCount: 2, observations: 'Two lines.', comparison: 'Two of three lines.', alignment: 'developing', formation: 'developing', spacing: 'developing', evidence: { alignment: 'Level.', formation: 'Continuous.', spacing: 'Even.' }, suggestion: 'Add a line.' };
  const analyze = createMotorAnalyzer({ provider: 'ollama', fetchImpl: async (_url, options) => {
    requests.push(JSON.parse(options.body));
    return new Response(JSON.stringify({ message: { content: JSON.stringify(requests.length === 1 ? quality : comparison) } }));
  } });
  const report = await analyze(drawingPhoto(), motorExercises[0]);
  assert.match(requests[1].messages[1].content, /Pixel analysis of the original found 3 separate drawn marks/);
  assert.equal(report.observedCount, 3);
  assert.equal(report.countMethod, 'separate_ink_marks_v2');
  assert.equal(report.markCount.marks.length, 3);
  assert.equal(report.observations, 'Pixel analysis found 3 separate drawn marks in the photo.');
  assert.equal(report.formation, 'not_assessable');
});

test('Gemini vision uses its fixed HTTPS endpoint with the server key and rechecks permission', async () => {
  const requests = [];
  const quality = { imageQuality: 'usable', relevance: 'drawing_attempt', qualityFlags: [], explanation: 'Readable.', countEvidence: 'Three lines.', observedCount: 3 };
  const comparison = { imageQuality: 'usable', qualityFlags: [], observedCount: 3, observations: 'Three lines.', comparison: 'Three of three.', alignment: 'developing', formation: 'consistent', spacing: 'developing', evidence: { alignment: 'Slight slope.', formation: 'Continuous.', spacing: 'Uneven.' }, suggestion: 'Rest between lines.' };
  let permissionChecks = 0;
  const analyze = createMotorAnalyzer({ provider: 'gemini', apiKey: 'gemini-test-key', fetchImpl: async (url, options) => {
    requests.push({ url: String(url), options, body: JSON.parse(options.body) });
    return new Response(JSON.stringify({ choices: [{ message: { content: JSON.stringify(requests.length === 1 ? quality : comparison) } }] }));
  } });
  assert.equal(analyze.externalProvider, 'gemini');
  const report = await analyze(drawingPhoto(), motorExercises[0], { canUseHosted: async () => { permissionChecks++; return true; } });
  assert.equal(report.provider, 'gemini');
  assert.equal(report.observedCount, 3);
  assert.equal(permissionChecks, 2);
  for (const request of requests) {
    assert.equal(request.url, 'https://generativelanguage.googleapis.com/v1beta/openai/chat/completions');
    assert.equal(request.options.headers.Authorization, 'Bearer gemini-test-key');
    assert.equal(request.options.redirect, 'error');
    assert.equal(request.body.model, 'gemini-3.8-flash');
    assert.equal(request.body.reasoning_effort, 'low');
  }
  const unconfigured = createMotorAnalyzer({ provider: 'gemini', apiKey: '', fetchImpl: async () => { throw new Error('Must not send'); } });
  await assert.rejects(() => unconfigured(drawingPhoto(), motorExercises[0], { canUseHosted: () => true }), /Gemini vision is not configured/);
});
