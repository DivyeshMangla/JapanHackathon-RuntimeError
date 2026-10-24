import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm, stat } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { createApp } from '../src/server.mjs';
import { newSession } from '../src/auth.mjs';
import { expressionPictures, scoreExpressionAnswers } from '../src/expressions.mjs';

async function fixture(t) {
  const dir = await mkdtemp(join(tmpdir(), 'melo-expressions-'));
  let app = createApp({ dataDir: dir });
  let base;
  async function listen() {
    await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
    base = `http://127.0.0.1:${app.server.address().port}/api`;
  }
  async function close() {
    await app.motor.waitForIdle();
    app.server.closeAllConnections();
    await new Promise(resolve => app.server.close(resolve));
    app.db.close();
  }
  await listen();
  t.after(async () => { await close(); await rm(dir, { recursive: true, force: true }); });
  const add = role => {
    const id = randomUUID();
    app.db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,created_at) VALUES (?,?,?,?,?,?,?)').run(id, 'Synthetic test', `${id}@test.example`, 'unused', role, 'active', new Date().toISOString());
    return { id, token: newSession(app.db, id) };
  };
  const therapist = add('therapist'), parent = add('parent'), child = add('patient');
  const otherTherapist = add('therapist'), otherParent = add('parent'), otherChild = add('patient');
  app.db.prepare('UPDATE users SET therapist_id=?,parent_id=? WHERE id=?').run(therapist.id, parent.id, child.id);
  const path = `/patients/${child.id}/expressions`;
  const sessionsPath = `/patients/${child.id}/expression-sessions`;
  const call = async (path, user, method = 'GET', input) => {
    const response = await fetch(base + path, { method, headers: { Authorization: `Bearer ${user.token}`, ...(input ? { 'Content-Type': 'application/json' } : {}) }, ...(input ? { body: JSON.stringify(input) } : {}) });
    return { status: response.status, body: await response.json() };
  };
  const consent = () => app.db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at) VALUES (?,?,?,?,?,?,?,?)').run(randomUUID(), child.id, 'test', 'Synthetic guardian', 'test', JSON.stringify({ analysis: false }), 'approved', new Date().toISOString());
  const assign = async (ids = ['happy', 'sad'], enabled = true) => (await call(path, therapist, 'PUT', { expressionIds: ids, enabled })).body.assignment;
  return { dir, therapist, parent, child, otherTherapist, otherParent, otherChild, path, sessionsPath, call, consent, assign, get db() { return app.db; }, async restart() { await close(); app = createApp({ dataDir: dir }); await listen(); } };
}

const answersFor = ids => expressionPictures(ids).map(pictureId => ({ pictureId, selected: pictureId.slice(0, pictureId.lastIndexOf('-')) }));

test('fixed expression answer key counts exact matches and confusions without clinical inference', () => {
  const report = scoreExpressionAnswers([{ pictureId: 'happy-1', selected: 'happy' }, { pictureId: 'happy-2', selected: 'sad' }, { pictureId: 'sad-1', selected: 'happy' }, { pictureId: 'sad-2', selected: 'sad' }]);
  assert.equal(report.correct, 2);
  assert.equal(report.total, 4);
  assert.equal(report.accuracy, 50);
  assert.deepEqual(report.perExpression, [{ expressionId: 'happy', correct: 1, total: 2 }, { expressionId: 'sad', correct: 1, total: 2 }]);
  assert.deepEqual(report.confusions, [{ expected: 'happy', selected: 'sad', count: 1 }, { expected: 'sad', selected: 'happy', count: 1 }]);
  assert.match(report.interpretation, /Not a diagnosis/);
});

test('expression routes enforce consent, role, caseload, full assignment and server scoring', async t => {
  const f = await fixture(t);
  assert.equal((await f.call(f.path, f.otherTherapist)).status, 403);
  assert.equal((await f.call(f.path, f.otherParent)).status, 403);
  assert.equal((await f.call(f.path, f.otherChild)).status, 403);
  assert.equal((await f.call(f.path, f.therapist, 'PUT', { expressionIds: ['happy', 'sad'], enabled: true })).status, 409);
  f.consent();
  for (const user of [f.parent, f.child]) assert.equal((await f.call(f.path, user, 'PUT', { expressionIds: ['happy', 'sad'], enabled: true })).status, 403);
  for (const ids of [['happy'], ['happy', 'happy'], ['happy', 'invented']]) assert.equal((await f.call(f.path, f.therapist, 'PUT', { expressionIds: ids, enabled: true })).status, 400);
  const assignment = await f.assign();
  const submission = { id: randomUUID(), assignmentId: assignment.id, assistance: 'independent', answers: answersFor(['happy', 'sad']) };
  assert.equal((await f.call(f.sessionsPath, f.parent, 'POST', submission)).status, 403);
  assert.equal((await f.call(f.sessionsPath, f.therapist, 'POST', submission)).status, 403);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, assignmentId: {} })).status, 400);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, assistance: 'unknown' })).status, 400);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, answers: submission.answers.slice(1) })).status, 400);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, answers: [...submission.answers.slice(1), submission.answers[1]] })).status, 400);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, answers: [...submission.answers.slice(1), { pictureId: 'angry-1', selected: 'happy' }] })).status, 400);
  submission.answers[0].selected = 'sad';
  const sent = await f.call(f.sessionsPath, f.child, 'POST', { ...submission, correct: 4, accuracy: 100 });
  assert.equal(sent.status, 201);
  assert.equal(sent.body.session.correct, 3);
  assert.equal(sent.body.session.accuracy, 75);
  assert.equal(sent.body.session.assistance, 'independent');
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, answers: [...submission.answers].reverse() })).status, 200);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, assistance: 'with_help' })).status, 409);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, answers: answersFor(['happy', 'sad']) })).status, 409);
  assert.equal((await f.call(f.path, f.parent)).body.sessions.length, 1);
  const reviewPath = `/expression-sessions/${submission.id}/review`;
  for (const user of [f.child, f.parent, f.otherTherapist]) assert.equal((await f.call(reviewPath, user, 'POST', { note: 'Synthetic next step' })).status, 403);
  assert.equal((await f.call(reviewPath, f.therapist, 'POST', { note: '' })).status, 400);
  assert.equal((await f.call(reviewPath, f.therapist, 'POST', { note: 'Compare the smiling and frowning pictures together.' })).status, 200);
  for (const user of [f.parent, f.child]) {
    const session = (await f.call(f.path, user)).body.sessions[0];
    assert.equal(session.reviewNote, 'Compare the smiling and frowning pictures together.');
    assert.equal(session.reviewedBy, f.therapist.id);
    assert.ok(session.reviewedAt);
  }
  const paused = await f.assign(['happy', 'sad'], false);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, id: randomUUID(), assignmentId: paused.id })).status, 409);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', { ...submission, id: randomUUID() })).status, 409);
  // A successful submission can still be retried after a plan changes without counting twice.
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', submission)).status, 200);
  f.db.prepare('UPDATE users SET therapist_id=? WHERE id=?').run(f.otherTherapist.id, f.child.id);
  assert.equal((await f.call(f.path, f.therapist)).status, 403);
  assert.equal((await f.call(reviewPath, f.therapist, 'POST', { note: 'Unauthorized' })).status, 403);
  assert.equal((await f.call(f.path, f.otherTherapist)).status, 200);
});

test('expression responses and feedback persist encrypted across service restart', async t => {
  const f = await fixture(t); f.consent();
  const assignment = await f.assign(['happy', 'sad', 'calm']);
  const payload = { id: randomUUID(), assignmentId: assignment.id, assistance: 'with_help', answers: answersFor(['happy', 'sad', 'calm']) };
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', payload)).status, 201);
  const note = 'Synthetic private family guidance';
  assert.equal((await f.call(`/expression-sessions/${payload.id}/review`, f.therapist, 'POST', { note })).status, 200);
  const stored = f.db.prepare('SELECT answers,report,review_note FROM expression_sessions WHERE id=?').get(payload.id);
  assert.ok(stored.answers instanceof Uint8Array);
  assert.ok(stored.report instanceof Uint8Array);
  assert.ok(stored.review_note instanceof Uint8Array);
  assert.ok(!Buffer.from(stored.answers).includes(Buffer.from('happy-1')));
  assert.ok(!Buffer.from(stored.report).includes(Buffer.from('accuracy')));
  assert.ok(!Buffer.from(stored.review_note).includes(Buffer.from(note)));
  assert.equal((await stat(join(f.dir, 'expressions.key'))).mode & 0o777, 0o600);
  await f.restart();
  const loaded = await f.call(f.path, f.parent);
  assert.equal(loaded.status, 200);
  assert.deepEqual(loaded.body.assignment.expressionIds, ['happy', 'sad', 'calm']);
  assert.equal(loaded.body.sessions[0].correct, 6);
  assert.equal(loaded.body.sessions[0].assistance, 'with_help');
  assert.equal(loaded.body.sessions[0].reviewNote, note);
  assert.equal((await f.call(f.sessionsPath, f.child, 'POST', payload)).status, 200);
});
