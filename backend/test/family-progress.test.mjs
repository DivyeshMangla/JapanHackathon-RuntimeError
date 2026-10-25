import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { createApp } from '../src/server.mjs';
import { newSession } from '../src/auth.mjs';
import { familyProgress, weeklyTrend } from '../src/family-progress.mjs';

function fixture(overrides = {}) {
  const users = new Map([
    ['child', { id: 'child', role: 'patient', parent_id: 'parent', therapist_id: 'therapist' }],
    ['parent', { id: 'parent', role: 'parent', status: 'active' }],
    ['therapist', { id: 'therapist', role: 'therapist', status: 'active', name: 'Dr Meera' }],
    ['previous', { id: 'previous', role: 'therapist', status: 'active', name: 'Dr Previous' }],
  ]);
  let response;
  const route = familyProgress({
    findUser: id => users.get(id),
    fail: (status, message) => { throw Object.assign(new Error(message), { status }); },
    json: (_, status, value) => { response = { status, value }; },
    ...overrides,
  });
  return {
    users, route,
    get: async (user = users.get('parent'), method = 'GET', path = '/api/patients/child/family-progress') => {
      await route({ method }, {}, path, user);
      return response;
    },
  };
}

test('family progress permits only the child, their parent and current active therapist', async () => {
  let reads = 0;
  const f = fixture({ wordSnapshot: () => { reads++; return []; } });
  for (const id of ['parent', 'child', 'therapist']) assert.equal((await f.get(f.users.get(id))).status, 200);
  for (const user of [
    { id: 'another-parent', role: 'parent' },
    { id: 'another-child', role: 'patient' },
    f.users.get('previous'),
    { ...f.users.get('therapist'), status: 'disabled' },
    { id: 'admin', role: 'admin' },
  ]) await assert.rejects(f.get(user), { status: 403 });
  assert.equal(reads, 3, 'denied callers must not read clinical snapshots');
  f.users.get('child').therapist_id = 'previous';
  await assert.rejects(f.get(f.users.get('therapist')), { status: 403 });
  assert.equal((await f.get(f.users.get('previous'))).status, 200);
  assert.equal((await f.get()).status, 200, 'a reassignment does not remove parent access');
  await assert.rejects(f.get(undefined, 'POST'), { status: 405 });
  await assert.rejects(f.get(undefined, 'GET', '/api/patients/unknown/family-progress'), { status: 404 });
  assert.equal(await f.route({ method: 'GET' }, {}, '/api/config', {}), false);
});

test('families receive published therapist guidance and observed counts, without private model or raw recording data', async () => {
  const f = fixture({
    wordSnapshot: () => [
      { id: 'word-1', word: 'help', date: '2026-10-24T10:00:00Z', reviewed: true,
        feedback: 'Try the first sound slowly.', hasFeedbackAudio: true, therapistOutcome: 'needs_practice',
        reviewedAt: '2026-10-25T10:00:00Z', reviewedBy: 'previous',
        audio: 'PRIVATE_RECORDING', transcript: 'PRIVATE_TRANSCRIPT', analysisReport: 'PRIVATE_AI', analysisCorrection: 'PRIVATE_CORRECTION' },
      { id: 'draft-word', word: 'water', date: '2026-10-25T09:00:00Z', reviewed: false,
        feedback: 'UNPUBLISHED_FEEDBACK', hasFeedbackAudio: true, therapistOutcome: 'correct' },
      { id: 'outcome-only', word: 'yes', date: '2026-10-25T08:00:00Z', reviewed: true,
        feedback: '', hasFeedbackAudio: false, therapistOutcome: 'correct', reviewedBy: 'therapist', reviewedAt: '2026-10-25T11:00:00Z' },
    ],
    motorSnapshot: () => [
      { id: 'draw-1', exercise_id: 'motor-lines', created_at: '2026-10-24T12:00:00Z',
        review_note: 'Use a relaxed grip.', reviewed_at: '2026-10-25T12:00:00Z', reviewed_by: 'therapist',
        filename: 'PRIVATE_FILENAME', report: 'PRIVATE_DRAWING_AI' },
    ],
    expressionSnapshot: () => [
      { id: 'expression-1', createdAt: '2026-10-24T14:00:00Z', correct: 3, total: 4,
        assistance: 'independent', reviewNote: 'Compare the eyes as well as the mouth.', reviewedAt: '2026-10-25T13:00:00Z', reviewedBy: 'therapist', items: ['PRIVATE_ITEMS'] },
      { id: 'expression-2', createdAt: '2026-10-25T14:00:00Z', correct: 4, total: 4, assistance: 'with_help', reviewNote: null, reviewedAt: null },
    ],
  });
  const { value } = await f.get();
  const word = value.activities.find(activity => activity.kind === 'words');
  assert.equal(word.attempts, 3); assert.equal(word.reviewed, 2);
  assert.equal(word.clinicianCorrect, 1); assert.equal(word.clinicianNeedsPractice, 1);
  assert.equal(word.lastPracticedAt, '2026-10-25T09:00:00Z');
  const expressions = value.activities.find(activity => activity.kind === 'expressions');
  assert.equal(expressions.quizCorrect, 7); assert.equal(expressions.quizTotal, 8);
  assert.equal(expressions.quizIndependentCorrect, 3); assert.equal(expressions.quizIndependentTotal, 4);
  assert.equal(expressions.quizAssistedCorrect, 4); assert.equal(expressions.quizAssistedTotal, 4);
  assert.equal(value.feedback.length, 4);
  assert.equal(value.feedback[0].kind, 'expressions');
  const wordFeedback = value.feedback.find(feedback => feedback.id === 'words-word-1');
  assert.equal(wordFeedback.therapistName, 'Dr Previous', 'attribute feedback to its author, not the current therapist');
  assert.equal(wordFeedback.audioPath, '/useful-words/patients/child/attempts/word-1/feedback');
  const serialized = JSON.stringify(value);
  assert.ok(!serialized.includes('PRIVATE_'));
  assert.ok(!serialized.includes('UNPUBLISHED_FEEDBACK'));
  assert.ok(!serialized.includes('accuracy'), 'no ASR or drawing model accuracy is invented');
});

test('empty history has no accuracy and unknown historical reviewer is not attributed to current therapist', async () => {
  const f = fixture();
  const { value } = await f.get();
  assert.deepEqual(value.feedback, []);
  assert.ok(value.activities.every(activity => activity.attempts === 0 && activity.reviewed === 0));
  assert.ok(value.activities.every(activity => activity.lastPracticedAt === null));
  assert.equal(value.activities.find(activity => activity.kind === 'expressions').quizTotal, 0);
  const old = fixture({ wordSnapshot: () => [{ id: 'old', word: 'help', date: '2026-10-01T12:00:00Z', reviewed: true, feedback: 'Keep practising.' }] });
  assert.equal((await old.get()).value.feedback[0].therapistName, null);
});

test('parent and child can fetch published therapist audio but cannot fetch child recordings or another family', async t => {
  const dataDir = await mkdtemp(join(tmpdir(), 'melo-family-progress-'));
  const app = createApp({ dataDir });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await app.motor.waitForIdle();
    app.server.closeAllConnections();
    await new Promise(resolve => app.server.close(resolve));
    app.db.close();
    await rm(dataDir, { recursive: true, force: true });
  });
  const add = (id, role) => {
    app.db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,created_at) VALUES(?,?,?,?,?,?,?)')
      .run(id, id, `${id}@family.test`, 'unused-login-hash', role, 'active', new Date().toISOString());
    return newSession(app.db, id);
  };
  const therapist = add('therapist', 'therapist');
  const otherTherapist = add('other-therapist', 'therapist');
  const parent = add('parent', 'parent');
  const otherParent = add('other-parent', 'parent');
  const child = add('child', 'patient');
  const otherChild = add('other-child', 'patient');
  app.db.prepare('UPDATE users SET therapist_id=?,parent_id=? WHERE id=?').run('therapist', 'parent', 'child');
  app.db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at) VALUES(?,?,?,?,?,?,?,?)')
    .run('consent', 'child', 'test', 'Parent', '', JSON.stringify({ analysis: false }), 'approved', new Date().toISOString());
  const call = async (path, token, method = 'GET', body) => {
    const response = await fetch(`http://127.0.0.1:${app.server.address().port}/api${path}`, {
      method, headers: { Authorization: `Bearer ${token}`, ...(body ? { 'Content-Type': 'application/json' } : {}) },
      body: body ? JSON.stringify(body) : undefined,
    });
    return { status: response.status, value: await response.json() };
  };
  const wordsPath = '/useful-words/patients/child';
  const wav = Buffer.alloc(100); wav.write('RIFF'); wav.write('WAVE', 8);
  const recording = wav.toString('base64');
  const word = await call(`${wordsPath}/words`, therapist, 'POST', {
    word: 'help', picture: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl6o1sAAAAASUVORK5CYII=', exampleAudio: recording,
  });
  assert.equal(word.status, 201);
  assert.equal((await call(`${wordsPath}/attempts`, child, 'POST', { id: 'attempt', wordId: word.value.id, audio: recording })).status, 201);
  const review = { feedback: 'Try a slower first sound.', reviewed: false, feedbackAudio: recording };
  assert.equal((await call(`${wordsPath}/attempts/attempt/review`, therapist, 'PUT', review)).status, 200);
  assert.deepEqual((await call('/patients/child/family-progress', parent)).value.feedback, [], 'drafts are private until published');
  assert.equal((await call(`${wordsPath}/attempts/attempt/feedback`, parent)).value.audio, null);
  assert.equal((await call(`${wordsPath}/attempts/attempt/review`, therapist, 'PUT', { ...review, reviewed: true, therapistOutcome: 'needs_practice' })).status, 200);
  for (const token of [parent, child]) {
    const progress = await call('/patients/child/family-progress', token);
    assert.equal(progress.status, 200);
    assert.equal(progress.value.feedback[0].text, review.feedback);
    const audio = await call(progress.value.feedback[0].audioPath, token);
    assert.equal(audio.status, 200); assert.equal(audio.value.audio, recording);
    assert.equal((await call(`${wordsPath}/attempts/attempt/audio`, token)).status, 403);
  }
  for (const token of [otherParent, otherChild, otherTherapist]) {
    assert.equal((await call('/patients/child/family-progress', token)).status, 403);
    assert.equal((await call(`${wordsPath}/attempts/attempt/feedback`, token)).status, 403);
  }
  app.db.prepare('UPDATE users SET therapist_id=? WHERE id=?').run('other-therapist', 'child');
  assert.equal((await call('/patients/child/family-progress', therapist)).status, 403);
  const afterReassignment = await call('/patients/child/family-progress', parent);
  assert.equal(afterReassignment.value.feedback[0].therapistName, 'therapist', 'historical guidance retains its author');
  const publishedAudioPath = afterReassignment.value.feedback[0].audioPath;
  const assertHistoricalFeedback = async (tokens = [parent, child]) => {
    for (const token of tokens) {
      assert.equal((await call('/patients/child/family-progress', token)).value.feedback[0].text, review.feedback);
      const audio = await call(publishedAudioPath, token);
      assert.equal(audio.status, 200);
      assert.equal(audio.value.audio, recording);
      assert.equal((await call(`${wordsPath}/attempts/attempt/audio`, token)).status, 403);
    }
  };
  await assertHistoricalFeedback();
  assert.equal((await call(publishedAudioPath, therapist)).status, 403, 'former therapists cannot play a family message');
  app.db.prepare("UPDATE users SET status='disabled' WHERE id=?").run('other-therapist');
  await assertHistoricalFeedback();
  app.db.prepare('UPDATE users SET therapist_id=NULL WHERE id=?').run('child');
  await assertHistoricalFeedback();
  // Past eligibility for new practice must not prevent replaying guidance
  // already published to the family. Refresh tokens after advancing the clock.
  t.mock.timers.enable({ apis: ['Date'], now: new Date('2040-10-25T12:00:00Z').getTime() });
  await assertHistoricalFeedback([newSession(app.db, 'parent'), newSession(app.db, 'child')]);
});

test('weekly trend scores each week since the first practice and leaves unscored weeks empty', () => {
  const rows = [
    { at: '2026-10-06T09:00:00Z', score: [1, 4] },
    { at: '2026-10-08T09:00:00Z', score: [2, 4] },
    { at: '2026-10-14T09:00:00Z', score: null },
    { at: '2026-10-21T09:00:00Z', score: [4, 4] },
  ];
  assert.deepEqual(weeklyTrend(rows, row => row.at, row => row.score, new Date('2026-10-25T12:00:00Z')), [
    { weekStart: '2026-10-05', attempts: 2, score: 38 },
    { weekStart: '2026-10-12', attempts: 1, score: null },
    { weekStart: '2026-10-19', attempts: 1, score: 100 },
  ]);
  assert.deepEqual(weeklyTrend([], row => row.at, row => row.score), []);
  const old = [{ at: '2026-01-05T09:00:00Z', score: [1, 1] }];
  assert.equal(weeklyTrend(old, row => row.at, row => row.score, new Date('2026-10-25T12:00:00Z')).length, 8, 'only the last eight weeks are shown');
});
