import { randomUUID, createHash } from 'node:crypto';
import { readFile, writeFile, unlink } from 'node:fs/promises';
import { resolve } from 'node:path';
import { audit, now, consentVersion } from './db.mjs';
import { motorExercises, photoType } from './motor.mjs';

export function motorApi({
  db,
  dataDir,
  analyze,
  accessPatient,
  requireRole,
  body,
  text,
  fail,
  json,
}) {
  let work = Promise.resolve();
  const rows = patientId =>
    db
      .prepare(
        'SELECT * FROM motor_submissions WHERE patient_id=? ORDER BY created_at DESC,rowid DESC LIMIT 100',
      )
      .all(patientId);
  const consent = id =>
    db
      .prepare(
        'SELECT * FROM consents WHERE patient_id=? ORDER BY signed_at DESC,rowid DESC LIMIT 1',
      )
      .get(id);
  const canAnalyze = id => {
    const c = consent(id);
    return (
      c?.status === 'approved' &&
      c.version === consentVersion &&
      JSON.parse(c.checks).analysis === true
    );
  };
  function enqueue(id) {
    work = work.then(async () => {
      const row = db.prepare('SELECT * FROM motor_submissions WHERE id=?').get(id);
      if (!row || !['pending', 'processing'].includes(row.analysis_status)) return;
      if (!canAnalyze(row.patient_id)) {
        db.prepare("UPDATE motor_submissions SET analysis_status='declined' WHERE id=?").run(id);
        return;
      }
      db.prepare("UPDATE motor_submissions SET analysis_status='processing' WHERE id=?").run(id);
      try {
        const report = await analyze(
          await readFile(resolve(dataDir, 'uploads', row.filename)),
          motorExercises.find(e => e.id === row.exercise_id),
        );
        db.prepare("UPDATE motor_submissions SET analysis_status='ready',report=? WHERE id=?").run(
          JSON.stringify(report),
          id,
        );
      } catch {
        // Preserve the original for human review when inference fails or the model is offline.
        db.prepare("UPDATE motor_submissions SET analysis_status='unavailable' WHERE id=?").run(id);
      }
    });
  }
  db.prepare(
    "UPDATE motor_submissions SET analysis_status='pending' WHERE analysis_status='processing'",
  ).run();
  for (const row of db
    .prepare("SELECT id FROM motor_submissions WHERE analysis_status='pending'")
    .all())
    enqueue(row.id);
  return {
    summaries(patientId, role) {
      return rows(patientId).map(({ filename, photo_hash, report, ...row }) => ({
        ...row,
        report: role === 'patient' ? null : report ? JSON.parse(report) : null,
      }));
    },
    waitForIdle: () => work,
    async handle(req, res, path, u) {
      const upload = path.match(/^\/api\/patients\/([^/]+)\/motor-submissions$/);
      if (upload && req.method === 'POST') {
        const p = accessPatient(u, upload[1]);
        requireRole(u, 'patient');
        const b = await body(req, 9 * 1024 * 1024);
        const c = consent(p.id);
        if (c?.status !== 'approved' || c.version !== consentVersion)
          fail(409, 'Your therapist must approve consent first.');
        const plan = db
          .prepare('SELECT * FROM plans WHERE id=? AND patient_id=?')
          .get(b.planId || '', p.id);
        if (
          !plan ||
          !JSON.parse(plan.exercises).includes(b.exerciseId) ||
          !motorExercises.some(e => e.id === b.exerciseId)
        )
          fail(400, 'Choose a motor exercise assigned in your plan.');
        const id = text(b.id, 'Submission ID', 80);
        if (!/^[a-zA-Z0-9-]+$/.test(id)) fail(400, 'Invalid submission ID.');
        if (
          typeof b.photo !== 'string' ||
          b.photo.length > 8 * 1024 * 1024 ||
          !/^[A-Za-z0-9+/]+={0,2}$/.test(b.photo)
        )
          fail(400, 'Choose a JPEG or PNG photo up to 6 MB.');
        const photo = Buffer.from(b.photo, 'base64');
        const mime = photoType(photo);
        if (!mime || photo.length > 6 * 1024 * 1024)
          fail(
            400,
            'Choose a JPEG or PNG photo up to 6 MB (PNG: at least 64 × 64, at most 24 megapixels).',
          );
        const day = text(b.practiceDay, 'Practice day', 10);
        const date = new Date(`${day}T12:00:00Z`);
        if (
          !/^\d{4}-\d{2}-\d{2}$/.test(day) ||
          !Number.isFinite(date.getTime()) ||
          date.toISOString().slice(0, 10) !== day ||
          Math.abs(date.getTime() - Date.now()) > 36 * 3600000
        )
          fail(400, 'Submit practice for today.');
        const hash = createHash('sha256').update(photo).digest('hex');
        const existing = db.prepare('SELECT * FROM motor_submissions WHERE id=?').get(id);
        if (existing) {
          if (
            existing.patient_id !== p.id ||
            existing.plan_id !== plan.id ||
            existing.exercise_id !== b.exerciseId ||
            existing.photo_hash !== hash ||
            existing.practice_day !== day
          )
            fail(409, 'Submission ID conflicts with an existing photo.');
          return json(res, 200, { id });
        }
        if (
          db
            .prepare(
              "SELECT COUNT(*) AS n FROM motor_submissions WHERE analysis_status IN ('pending','processing')",
            )
            .get().n >= 20
        )
          fail(429, 'Analysis queue is busy. Keep your photo and try again soon.');
        const filename = `motor-${id}.${mime === 'image/png' ? 'png' : 'jpg'}`;
        await writeFile(resolve(dataDir, 'uploads', filename), photo, {
          flag: 'wx',
        }).catch(() => fail(409, 'Photo upload conflict.'));
        const status = canAnalyze(p.id) ? 'pending' : 'declined';
        db.exec('BEGIN');
        try {
          const alreadyCounted = db
            .prepare(
              'SELECT 1 FROM motor_submissions WHERE patient_id=? AND plan_id=? AND exercise_id=? AND practice_day=?',
            )
            .get(p.id, plan.id, b.exerciseId, day);
          db.prepare(
            'INSERT INTO motor_submissions(id,patient_id,plan_id,exercise_id,filename,mime,bytes,photo_hash,practice_day,created_at,analysis_status) VALUES(?,?,?,?,?,?,?,?,?,?,?)',
          ).run(
            id,
            p.id,
            plan.id,
            b.exerciseId,
            filename,
            mime,
            photo.length,
            hash,
            day,
            now(),
            status,
          );
          if (!alreadyCounted)
            db.prepare('INSERT INTO progress VALUES(?,?,?,?,?,?,?)').run(
              randomUUID(),
              p.id,
              plan.id,
              b.exerciseId,
              motorExercises.find(e => e.id === b.exerciseId).minutes,
              now(),
              now(),
            );
          db.exec('COMMIT');
        } catch (error) {
          db.exec('ROLLBACK');
          await unlink(resolve(dataDir, 'uploads', filename));
          throw error;
        }
        audit(db, u.id, 'Uploaded motor practice', p.id, id);
        if (status === 'pending') enqueue(id);
        return json(res, 201, { id });
      }
      const match = path.match(/^\/api\/motor-submissions\/([^/]+)\/(photo|review|analyze)$/);
      if (!match) return false;
      const row = db.prepare('SELECT * FROM motor_submissions WHERE id=?').get(match[1]);
      if (!row) fail(404, 'Practice photo not found.');
      accessPatient(u, row.patient_id);
      if (match[2] === 'photo' && req.method === 'GET') {
        const bytes = await readFile(resolve(dataDir, 'uploads', row.filename));
        audit(db, u.id, 'Viewed motor photo', row.patient_id, row.id);
        res.writeHead(200, {
          'Content-Type': row.mime,
          'Content-Length': bytes.length,
        });
        res.end(bytes);
        return true;
      }
      requireRole(u, 'therapist');
      if (match[2] === 'review' && req.method === 'POST') {
        const b = await body(req);
        db.prepare(
          'UPDATE motor_submissions SET review_note=?,reviewed_by=?,reviewed_at=? WHERE id=?',
        ).run(text(b.note, 'Therapist feedback', 2000), u.id, now(), row.id);
        audit(db, u.id, 'Reviewed motor practice', row.patient_id, row.id);
        json(res, 200, { ok: true });
        return true;
      }
      if (match[2] === 'analyze' && req.method === 'POST') {
        if (!canAnalyze(row.patient_id))
          fail(409, 'Optional automated analysis was not agreed to.');
        if (!['pending', 'processing', 'ready'].includes(row.analysis_status)) {
          if (
            db
              .prepare(
                "SELECT COUNT(*) AS n FROM motor_submissions WHERE analysis_status IN ('pending','processing')",
              )
              .get().n >= 20
          )
            fail(429, 'Analysis queue is busy. Try again soon.');
          db.prepare("UPDATE motor_submissions SET analysis_status='pending' WHERE id=?").run(
            row.id,
          );
          enqueue(row.id);
          audit(db, u.id, 'Retried motor analysis', row.patient_id, row.id);
        }
        json(res, 202, { ok: true });
        return true;
      }
      fail(405, 'Method not allowed.');
    },
  };
}
