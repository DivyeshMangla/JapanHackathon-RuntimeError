import { randomUUID, randomBytes, createCipheriv, createDecipheriv } from 'node:crypto';
import { readFileSync, writeFileSync, chmodSync } from 'node:fs';
import { resolve } from 'node:path';
import { audit, now } from './db.mjs';

export const expressionIds = Object.freeze(['happy', 'sad', 'angry', 'surprised', 'scared', 'calm']);
export const expressionPictures = ids => ids.flatMap(id => [`${id}-1`, `${id}-2`]);

// This is a fixed picture-label exercise, not an inference about anybody's emotional state.
export function scoreExpressionAnswers(answers) {
  const perExpression = new Map();
  const confusions = new Map();
  const items = answers.map(({ pictureId, selected }) => {
    const expected = pictureId.slice(0, pictureId.lastIndexOf('-'));
    const correct = expected === selected;
    const count = perExpression.get(expected) || { expressionId: expected, correct: 0, total: 0 };
    count.total++;
    if (correct) count.correct++;
    else {
      const key = `${expected}:${selected}`;
      const confusion = confusions.get(key) || { expected, selected, count: 0 };
      confusion.count++;
      confusions.set(key, confusion);
    }
    perExpression.set(expected, count);
    return { pictureId, expected, selected, correct };
  });
  const correct = items.filter(item => item.correct).length;
  return {
    correct, total: items.length, accuracy: Math.round(correct * 10000 / items.length) / 100,
    perExpression: [...perExpression.values()], confusions: [...confusions.values()], items,
    interpretation: 'Accuracy on this illustrated picture-label task only. Not a diagnosis or a measure of real-world emotion understanding.',
  };
}

export function expressionsApi({ db, dataDir, accessPatient, requireRole, body, text, fail, json }) {
  const configuredKey = process.env.EXPRESSIONS_KEY || process.env.USEFUL_WORDS_KEY;
  let key;
  if (configuredKey) {
    key = Buffer.from(configuredKey, 'base64');
    if (key.length !== 32) throw Error('Expressions encryption requires a base64-encoded 32-byte key');
  } else {
    if (process.env.NODE_ENV === 'production') throw Error('EXPRESSIONS_KEY or USEFUL_WORDS_KEY is required in production');
    const keyPath = resolve(dataDir, 'expressions.key');
    try { key = readFileSync(keyPath); }
    catch (error) {
      if (error.code !== 'ENOENT') throw error;
      key = randomBytes(32);
      writeFileSync(keyPath, key, { flag: 'wx', mode: 0o600 });
    }
    chmodSync(keyPath, 0o600);
    if (key.length !== 32) throw Error('Invalid expressions encryption key');
  }
  // Bind ciphertext to its record and purpose so copying payloads cannot swap patient results.
  const seal = (value, context) => {
    const nonce = randomBytes(12);
    const cipher = createCipheriv('aes-256-gcm', key, nonce);
    cipher.setAAD(Buffer.from(`melo-expressions:${context}`));
    const payload = Buffer.concat([cipher.update(JSON.stringify(value)), cipher.final()]);
    return Buffer.concat([nonce, cipher.getAuthTag(), payload]);
  };
  const open = (value, context) => {
    const bytes = Buffer.from(value);
    const cipher = createDecipheriv('aes-256-gcm', key, bytes.subarray(0, 12));
    cipher.setAAD(Buffer.from(`melo-expressions:${context}`));
    cipher.setAuthTag(bytes.subarray(12, 28));
    return JSON.parse(Buffer.concat([cipher.update(bytes.subarray(28)), cipher.final()]).toString());
  };
  const latest = patientId => db.prepare('SELECT * FROM expression_assignments WHERE patient_id=? ORDER BY updated_at DESC,rowid DESC LIMIT 1').get(patientId);
  const consented = patientId => db.prepare("SELECT status FROM consents WHERE patient_id=? ORDER BY signed_at DESC,rowid DESC LIMIT 1").get(patientId)?.status === 'approved';
  const assignmentJson = row => row ? { id: row.id, expressionIds: open(row.expression_ids, `assignment:${row.patient_id}:${row.id}`), enabled: row.enabled === 1, updatedAt: row.updated_at } : null;
  const sessionJson = row => ({ id: row.id, assignmentId: row.assignment_id, createdAt: row.created_at, ...open(row.report, `report:${row.patient_id}:${row.id}`), reviewNote: row.review_note ? open(row.review_note, `review:${row.patient_id}:${row.id}`) : null, reviewedBy: row.reviewed_by, reviewedAt: row.reviewed_at });
  const snapshot = (patientId, limit) => db.prepare(`SELECT * FROM expression_sessions WHERE patient_id=? ORDER BY created_at DESC,rowid DESC${limit ? ' LIMIT 100' : ''}`).all(patientId).map(sessionJson);
  function validateAnswers(answers, ids) {
    const pictures = new Set(expressionPictures(ids));
    if (!Array.isArray(answers) || answers.length !== pictures.size) fail(400, 'Answer each assigned picture once.');
    const seen = new Set();
    for (const answer of answers) {
      if (!answer || typeof answer !== 'object' || !pictures.has(answer.pictureId) || seen.has(answer.pictureId) || !ids.includes(answer.selected)) fail(400, 'Choose one assigned feeling for each different picture.');
      seen.add(answer.pictureId);
    }
    return answers.map(({ pictureId, selected }) => ({ pictureId, selected })).sort((a, b) => a.pictureId.localeCompare(b.pictureId));
  }
  return {
    snapshot,
    async handle(req, res, path, user) {
      const recordMatch = path.match(/^\/api\/patients\/([^/]+)\/expressions$/);
      if (recordMatch) {
        const patient = accessPatient(user, recordMatch[1]);
        if (req.method === 'GET') {
          json(res, 200, { assignment: assignmentJson(latest(patient.id)), consented: consented(patient.id), sessions: snapshot(patient.id, 100) });
          return true;
        }
        if (req.method === 'PUT') {
          requireRole(user, 'therapist');
          if (!consented(patient.id)) fail(409, 'Approved consent is required before assigning practice.');
          if (patient.status !== 'active') fail(409, 'This child’s account is disabled.');
          const input = await body(req, 4096);
          const ids = input.expressionIds;
          if (!Array.isArray(ids) || ids.length < 2 || ids.length > expressionIds.length || new Set(ids).size !== ids.length || !ids.every(id => expressionIds.includes(id)) || typeof input.enabled !== 'boolean') fail(400, 'Choose two to six different feelings and whether practice is enabled.');
          // Keep assignment versions so old sessions still have an unambiguous answer set.
          const id = randomUUID();
          db.prepare('INSERT INTO expression_assignments VALUES (?,?,?,?,?,?)').run(id, patient.id, user.id, seal(expressionIds.filter(value => ids.includes(value)), `assignment:${patient.id}:${id}`), Number(input.enabled), now());
          audit(db, user.id, 'Assigned feelings practice', patient.id, id);
          json(res, 200, { assignment: assignmentJson(latest(patient.id)) });
          return true;
        }
        fail(405, 'Method not allowed.');
      }
      const submitMatch = path.match(/^\/api\/patients\/([^/]+)\/expression-sessions$/);
      if (submitMatch) {
        const patient = accessPatient(user, submitMatch[1]);
        requireRole(user, 'patient');
        if (req.method !== 'POST') fail(405, 'Method not allowed.');
        if (!consented(patient.id)) fail(409, 'Approved consent is required before practice.');
        const input = await body(req, 8192);
        const id = text(input.id, 'Session ID', 80);
        const assignmentId = text(input.assignmentId, 'Assignment ID', 80);
        if (!['independent', 'with_help'].includes(input.assistance)) fail(400, 'Choose whether an adult helped with this round.');
        if (!/^[a-zA-Z0-9-]+$/.test(id)) fail(400, 'Invalid session ID.');
        const assignment = db.prepare('SELECT * FROM expression_assignments WHERE id=? AND patient_id=?').get(assignmentId, patient.id);
        if (!assignment) fail(400, 'Choose practice assigned by your therapist.');
        const answers = validateAnswers(input.answers, open(assignment.expression_ids, `assignment:${patient.id}:${assignment.id}`));
        const serialized = JSON.stringify(answers);
        const existing = db.prepare('SELECT * FROM expression_sessions WHERE id=?').get(id);
        if (existing) {
          if (existing.patient_id !== patient.id || existing.assignment_id !== assignment.id || JSON.stringify(open(existing.answers, `answers:${existing.patient_id}:${existing.id}`)) !== serialized || open(existing.report, `report:${existing.patient_id}:${existing.id}`).assistance !== input.assistance) fail(409, 'Session ID conflicts with existing practice.');
          json(res, 200, { session: sessionJson(existing) });
          return true;
        }
        if (latest(patient.id)?.id !== assignment.id || assignment.enabled !== 1) fail(409, 'Your therapist changed this practice. Reload and start a new round.');
        if (patient.status !== 'active') fail(409, 'This child’s account is disabled.');
        const report = { ...scoreExpressionAnswers(answers), assistance: input.assistance };
        db.prepare('INSERT INTO expression_sessions(id,patient_id,assignment_id,answers,report,created_at) VALUES (?,?,?,?,?,?)').run(id, patient.id, assignment.id, seal(answers, `answers:${patient.id}:${id}`), seal(report, `report:${patient.id}:${id}`), now());
        audit(db, user.id, 'Completed feelings practice', patient.id, id);
        json(res, 201, { session: sessionJson(db.prepare('SELECT * FROM expression_sessions WHERE id=?').get(id)) });
        return true;
      }
      const reviewMatch = path.match(/^\/api\/expression-sessions\/([^/]+)\/review$/);
      if (!reviewMatch) return false;
      const session = db.prepare('SELECT * FROM expression_sessions WHERE id=?').get(reviewMatch[1]);
      if (!session) fail(404, 'Feelings practice not found.');
      accessPatient(user, session.patient_id);
      requireRole(user, 'therapist');
      if (req.method !== 'POST') fail(405, 'Method not allowed.');
      const input = await body(req, 8192);
      const note = text(input.note, 'Therapist feedback', 2000);
      db.prepare('UPDATE expression_sessions SET review_note=?,reviewed_by=?,reviewed_at=? WHERE id=?').run(seal(note, `review:${session.patient_id}:${session.id}`), user.id, now(), session.id);
      audit(db, user.id, 'Reviewed feelings practice', session.patient_id, session.id);
      json(res, 200, { ok: true });
      return true;
    },
  };
}
