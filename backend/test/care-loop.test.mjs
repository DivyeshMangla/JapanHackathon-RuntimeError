import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtemp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { createApp } from '../src/server.mjs';
import { newSession } from '../src/auth.mjs';
import { consentVersion, now } from '../src/db.mjs';
import { motorReference } from '../src/motor-reference.mjs';
import { motorExercises } from '../src/motor.mjs';
import { toneWav } from './fixtures/audio.mjs';

test('all three activities deliver therapist assessments and guidance to the child and parent dashboards', async t => {
  const dir = await mkdtemp(join(tmpdir(), 'melo-care-loop-'));
  const app = createApp({ dataDir: dir, motorAnalyzer: async () => { throw new Error('Analysis must respect declined consent'); } });
  await new Promise(resolve => app.server.listen(0, '127.0.0.1', resolve));
  t.after(async () => {
    await app.motor.waitForIdle();
    app.server.closeAllConnections();
    await new Promise(resolve => app.server.close(resolve));
    app.db.close();
    await rm(dir, { recursive: true, force: true });
  });
  const base = `http://127.0.0.1:${app.server.address().port}/api`;
  const add = role => {
    const id = randomUUID();
    app.db.prepare('INSERT INTO users(id,name,email,password_hash,role,status,created_at) VALUES(?,?,?,?,?,?,?)')
      .run(id, `Synthetic ${role}`, `${id}@example.test`, 'unused', role, 'active', now());
    return { id, token: newSession(app.db, id) };
  };
  const therapist = add('therapist'), parent = add('parent'), child = add('patient'), stranger = add('parent');
  app.db.prepare('UPDATE users SET therapist_id=?,parent_id=? WHERE id=?').run(therapist.id, parent.id, child.id);
  const consentId = randomUUID();
  app.db.prepare('INSERT INTO consents(id,patient_id,version,signer_name,signature_png,checks,status,signed_at) VALUES(?,?,?,?,?,?,?,?)')
    .run(consentId, child.id, consentVersion, 'Synthetic guardian', 'fixture', JSON.stringify({ analysis: false }), 'approved', now());
  const call = async (user, path, method = 'GET', body) => {
    const response = await fetch(base + path, { method, headers: { Authorization: `Bearer ${user.token}`, ...(body ? { 'Content-Type': 'application/json' } : {}) }, ...(body ? { body: JSON.stringify(body) } : {}) });
    return { status: response.status, data: await response.json() };
  };
  const wordPath = `/useful-words/patients/${child.id}`, patientPath = `/patients/${child.id}`;
  const birthDate = new Date(); birthDate.setUTCFullYear(birthDate.getUTCFullYear() - 7);
  assert.equal((await call(therapist, `${wordPath}/enrollment`, 'PUT', { birthDate: birthDate.toISOString().slice(0, 10), usesSpeech: true, therapistSelectedGoals: true })).status, 200);
  const audio = toneWav().toString('base64');
  const word = await call(therapist, `${wordPath}/words`, 'POST', { word: 'help', picture: 'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAAB', exampleAudio: audio });
  assert.equal(word.status, 201);
  const wordId = randomUUID();
  assert.equal((await call(child, `${wordPath}/attempts`, 'POST', { id: wordId, wordId: word.data.id, audio })).status, 201);
  assert.equal((await call(therapist, `${wordPath}/attempts/${wordId}/review`, 'PUT', { feedback: 'Try the first sound slowly.', feedbackAudio: audio, reviewed: false, therapistOutcome: 'not_assessed' })).status, 200);
  assert.equal((await call(parent, `${patientPath}/family-progress`)).data.feedback.length, 0, 'draft remarks are not published');
  assert.equal((await call(therapist, `${wordPath}/attempts/${wordId}/review`, 'PUT', { feedback: 'Try the first sound slowly.', feedbackAudio: audio, reviewed: true, therapistOutcome: 'needs_practice', analysisCorrection: 'Private clinical correction' })).status, 200);

  const plan = await call(therapist, `${patientPath}/plans`, 'POST', { title: 'Synthetic drawing', exercises: ['motor-lines'], sessionsPerDay: 1, notes: 'Draw on paper.' });
  assert.equal(plan.status, 201);
  const drawingId = randomUUID();
  assert.equal((await call(child, `${patientPath}/motor-submissions`, 'POST', { id: drawingId, planId: plan.data.plan.id, exerciseId: 'motor-lines', practiceDay: new Date().toLocaleDateString('en-CA', { timeZone: 'Asia/Kolkata' }), photo: motorReference(motorExercises[0]).toString('base64') })).status, 201);
  assert.equal((await call(therapist, `/motor-submissions/${drawingId}/review`, 'POST', { note: 'Leave more space between the lines.', therapistOutcome: 'on_track' })).status, 200);

  const assignment = await call(therapist, `${patientPath}/expressions`, 'PUT', { expressionIds: ['happy', 'sad'], enabled: true });
  assert.equal(assignment.status, 200);
  const expressionId = randomUUID();
  const answers = ['happy-1', 'happy-2', 'sad-1', 'sad-2'].map(pictureId => ({ pictureId, selected: pictureId === 'happy-2' ? 'sad' : pictureId.split('-')[0] }));
  assert.equal((await call(child, `${patientPath}/expression-sessions`, 'POST', { id: expressionId, assignmentId: assignment.data.assignment.id, assistance: 'with_help', answers })).status, 201);
  assert.equal((await call(therapist, `/expression-sessions/${expressionId}/review`, 'POST', { note: 'Compare the eyes as well as the mouth.' })).status, 200);

  for (const user of [parent, child]) {
    const dashboard = await call(user, `${patientPath}/family-progress`);
    assert.equal(dashboard.status, 200);
    assert.equal(dashboard.data.feedback.length, 3);
    assert.ok(dashboard.data.activities.every(activity => activity.attempts === 1 && activity.reviewed === 1));
    assert.equal(dashboard.data.activities.find(activity => activity.kind === 'words').clinicianNeedsPractice, 1);
    assert.equal(dashboard.data.activities.find(activity => activity.kind === 'drawing').clinicianOnTrack, 1);
    const expression = dashboard.data.activities.find(activity => activity.kind === 'expressions');
    assert.equal(expression.quizCorrect, 3); assert.equal(expression.quizTotal, 4);
    assert.equal(expression.quizAssistedTotal, 4); assert.equal(expression.quizIndependentTotal, 0);
    assert.ok(!JSON.stringify(dashboard.data).includes('Private clinical correction'));
    assert.ok(!JSON.stringify(dashboard.data).includes(audio));
    const message = dashboard.data.feedback.find(feedback => feedback.kind === 'words');
    assert.equal((await call(user, message.audioPath)).data.audio, audio);
  }
  assert.equal((await call(stranger, `${patientPath}/family-progress`)).status, 403);
  assert.equal((await call(parent, `${wordPath}/attempts/${wordId}/audio`)).status, 403, 'a family voice message does not grant access to private original recordings');
});
