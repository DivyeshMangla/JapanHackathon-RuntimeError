import { randomUUID } from 'node:crypto';
import { readFile, writeFile, unlink } from 'node:fs/promises';
import { resolve } from 'node:path';
import { audit, now } from './db.mjs';

const MAX_AUDIO_BYTES = 18 * 1024 * 1024;
const MAX_BODY_BYTES = 26 * 1024 * 1024;
const idPattern = /^[A-Za-z0-9._:-]{1,120}$/;

const parse = row => JSON.parse(row.body);
const completionOut = row => ({
  id: row.id, patientId: row.patient_id, exerciseId: row.exercise_id, day: row.day, completedAt: row.completed_at,
});

/**
 * Routes for the exercise library, assignments, practice completions and
 * voice samples used by the role-based mobile app. Returns true when the
 * request was handled. Bodies are stored as the app sends them so the app's
 * models stay the single description of each record; the server checks who
 * may write them and the references between them.
 */
export async function careRoutes(ctx) {
  const { db, u, res, path, method, req, body, json, fail, findUser, accessPatient, requireRole, dataDir } = ctx;
  const send = (status, value) => { json(res, status, value); return true; };

  const checkId = (value, name) => {
    if (typeof value !== 'string' || !idPattern.test(value)) fail(400, `${name} is not valid.`);
    return value;
  };
  const canWriteFor = patient => {
    if (u.role === 'admin') return;
    if (u.role === 'therapist' && patient.therapist_id === u.id) return;
    fail(403, 'This patient is not assigned to you.');
  };

  if (path === '/api/library' && method === 'GET') {
    return send(200, { exercises: db.prepare('SELECT body FROM exercise_library').all().map(parse) });
  }
  const libraryMatch = path.match(/^\/api\/library\/([^/]+)$/);
  if (libraryMatch && method === 'PUT') {
    requireRole(u, 'admin');
    const b = await body(req);
    if (b.id !== libraryMatch[1] || typeof b.title !== 'string' || !b.title.trim()) fail(400, 'Send an exercise with an id and title.');
    checkId(b.id, 'Exercise id');
    db.prepare('INSERT INTO exercise_library VALUES (?,?,?) ON CONFLICT(id) DO UPDATE SET body=excluded.body, updated_at=excluded.updated_at')
      .run(b.id, JSON.stringify(b), now());
    audit(db, u.id, 'Saved exercise', b.id, b.title);
    return send(200, { ok: true });
  }

  if (path === '/api/directory' && method === 'GET') {
    // Names only, so a screen can show who a family's therapist is.
    const ids = new Set([u.id]);
    if (['patient', 'parent'].includes(u.role) && u.therapist_id) ids.add(u.therapist_id);
    if (u.role === 'patient' && u.parent_id) ids.add(u.parent_id);
    const users = [...ids].map(id => findUser(id)).filter(Boolean).map(x => ({ id: x.id, name: x.name, role: x.role }));
    return send(200, { users });
  }

  if (path === '/api/assignments' && method === 'GET') {
    requireRole(u, 'admin');
    return send(200, { assignments: db.prepare('SELECT body FROM assignments').all().map(parse) });
  }
  if (path === '/api/completions' && method === 'GET') {
    requireRole(u, 'admin');
    return send(200, { completions: db.prepare('SELECT * FROM completions ORDER BY completed_at').all().map(completionOut) });
  }
  if (path === '/api/samples' && method === 'GET') {
    requireRole(u, 'admin');
    return send(200, { samples: db.prepare('SELECT body FROM voice_samples ORDER BY created_at DESC').all().map(parse) });
  }

  if (path === '/api/study-settings') {
    if (method === 'GET') {
      const row = db.prepare("SELECT value FROM settings WHERE key='study'").get();
      return send(200, { settings: row ? JSON.parse(row.value) : null });
    }
    if (method === 'PUT') {
      requireRole(u, 'admin');
      const b = await body(req);
      db.prepare("INSERT INTO settings VALUES ('study',?) ON CONFLICT(key) DO UPDATE SET value=excluded.value").run(JSON.stringify(b));
      audit(db, u.id, 'Saved study settings');
      return send(200, { ok: true });
    }
  }
  if (path === '/api/diary' && method === 'GET') {
    requireRole(u, 'admin');
    return send(200, { entries: db.prepare('SELECT body FROM diary_entries ORDER BY day').all().map(parse) });
  }
  if (path === '/api/usage' && method === 'GET') {
    requireRole(u, 'admin');
    return send(200, { events: db.prepare('SELECT body FROM usage_events ORDER BY at, seq').all().map(parse) });
  }

  const match = path.match(/^\/api\/patients\/([^/]+)\/(assignments|completions|samples|diary|usage)(?:\/([^/]+))?$/);
  if (match) {
    const [, patientId, kind, itemId] = match;
    const patient = accessPatient(u, patientId);

    if (kind === 'assignments') {
      if (!itemId && method === 'GET') {
        return send(200, { assignments: db.prepare('SELECT body FROM assignments WHERE patient_id=?').all(patientId).map(parse) });
      }
      if (itemId && method === 'PUT') {
        canWriteFor(patient);
        const b = await body(req);
        if (b.id !== itemId || b.patientId !== patientId) fail(400, 'The assignment does not match this patient.');
        checkId(itemId, 'Assignment id');
        const row = db.prepare('SELECT body FROM exercise_library WHERE id=?').get(b.exerciseId);
        const exercise = row && parse(row);
        if (!exercise || exercise.archived || !exercise.approvedAt) fail(400, 'Only approved exercises can be assigned.');
        db.prepare('INSERT INTO assignments VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET body=excluded.body, updated_at=excluded.updated_at')
          .run(itemId, patientId, JSON.stringify(b), now());
        audit(db, u.id, 'Saved assignment', patientId, exercise.title);
        return send(200, { ok: true });
      }
      if (itemId && method === 'DELETE') {
        canWriteFor(patient);
        db.prepare('DELETE FROM assignments WHERE id=? AND patient_id=?').run(itemId, patientId);
        audit(db, u.id, 'Removed assignment', patientId, itemId);
        return send(200, { ok: true });
      }
    }

    if (kind === 'completions') {
      if (!itemId && method === 'GET') {
        const url = new URL(req.url, 'http://localhost');
        const from = url.searchParams.get('from') || '0000-00-00';
        const to = url.searchParams.get('to') || '9999-99-99';
        const rows = db.prepare('SELECT * FROM completions WHERE patient_id=? AND day>=? AND day<=? ORDER BY completed_at').all(patientId, from, to);
        return send(200, { completions: rows.map(completionOut) });
      }
      if (itemId && method === 'PUT') {
        requireRole(u, 'patient');
        checkId(itemId, 'Completion id');
        const b = await body(req);
        const day = typeof b.day === 'string' ? b.day.slice(0, 10) : '';
        const completedAt = new Date(b.completedAt);
        if (!/^\d{4}-\d{2}-\d{2}$/.test(day) || !Number.isFinite(completedAt.getTime())) fail(400, 'Send a valid day and time.');
        if (!db.prepare('SELECT id FROM exercise_library WHERE id=?').get(b.exerciseId)) fail(400, 'Unknown exercise.');
        const existing = db.prepare('SELECT patient_id FROM completions WHERE id=?').get(itemId);
        if (existing && existing.patient_id !== patientId) fail(409, 'Completion id conflict.');
        db.prepare('INSERT INTO completions VALUES (?,?,?,?,?) ON CONFLICT(id) DO UPDATE SET exercise_id=excluded.exercise_id, day=excluded.day, completed_at=excluded.completed_at')
          .run(itemId, patientId, b.exerciseId, day, completedAt.toISOString());
        return send(200, { ok: true });
      }
      if (itemId && method === 'DELETE') {
        requireRole(u, 'patient');
        db.prepare('DELETE FROM completions WHERE id=? AND patient_id=?').run(itemId, patientId);
        return send(200, { ok: true });
      }
    }

    if (kind === 'samples') {
      if (!itemId && method === 'GET') {
        return send(200, { samples: db.prepare('SELECT body FROM voice_samples WHERE patient_id=? ORDER BY created_at DESC').all(patientId).map(parse) });
      }
      if (itemId && method === 'PUT') {
        requireRole(u, 'patient');
        checkId(itemId, 'Recording id');
        const b = await body(req, MAX_BODY_BYTES);
        if (!b.meta || b.meta.id !== itemId || b.meta.patientId !== patientId) fail(400, 'The recording does not match this patient.');
        if (db.prepare('SELECT patient_id FROM voice_samples WHERE id=?').get(itemId)) return send(200, { id: itemId });
        if (typeof b.audio !== 'string' || !/^[A-Za-z0-9+/]*={0,2}$/.test(b.audio)) fail(400, 'Invalid audio encoding.');
        const audio = Buffer.from(b.audio, 'base64');
        if (audio.length < 44 || audio.length > MAX_AUDIO_BYTES || audio.toString('ascii', 0, 4) !== 'RIFF' || audio.toString('ascii', 8, 12) !== 'WAVE') fail(400, 'Upload a WAV recording.');
        const filename = `sample-${randomUUID()}.wav`;
        await writeFile(resolve(dataDir, 'uploads', filename), audio, { flag: 'wx' });
        // The device path means nothing on the server and must not be kept.
        const meta = { ...b.meta, filePath: '' };
        try {
          db.prepare('INSERT INTO voice_samples VALUES (?,?,?,?,?,?)').run(itemId, patientId, JSON.stringify(meta), filename, audio.length, now());
        } catch (error) {
          await unlink(resolve(dataDir, 'uploads', filename));
          throw error;
        }
        audit(db, u.id, 'Uploaded recording', patientId, itemId);
        return send(201, { id: itemId });
      }
    }

    if (kind === 'diary') {
      if (!itemId && method === 'GET') {
        return send(200, { entries: db.prepare('SELECT body FROM diary_entries WHERE patient_id=? ORDER BY day, rowid').all(patientId).map(parse) });
      }
      if (itemId && method === 'PUT') {
        requireRole(u, 'patient');
        checkId(itemId, 'Entry id');
        const b = await body(req);
        const day = typeof b.day === 'string' ? b.day.slice(0, 10) : '';
        if (b.id !== itemId || b.patientId !== patientId || !/^\d{4}-\d{2}-\d{2}$/.test(day)) fail(400, 'The diary entry does not match this patient.');
        db.prepare('INSERT INTO diary_entries VALUES (?,?,?,?) ON CONFLICT(id) DO UPDATE SET body=excluded.body, day=excluded.day').run(itemId, patientId, day, JSON.stringify(b));
        return send(200, { ok: true });
      }
      if (itemId && method === 'DELETE') {
        requireRole(u, 'patient');
        db.prepare('DELETE FROM diary_entries WHERE id=? AND patient_id=?').run(itemId, patientId);
        return send(200, { ok: true });
      }
    }

    if (kind === 'usage') {
      if (!itemId && method === 'GET') {
        return send(200, { events: db.prepare('SELECT body FROM usage_events WHERE patient_id=? ORDER BY at, seq').all(patientId).map(parse) });
      }
      if (!itemId && method === 'POST') {
        requireRole(u, 'patient');
        const b = await body(req);
        const at = new Date(b.at);
        if (b.patientId !== patientId || typeof b.action !== 'string' || !Number.isFinite(at.getTime())) fail(400, 'Send a valid usage event.');
        db.prepare('INSERT INTO usage_events(patient_id,at,body) VALUES (?,?,?)').run(patientId, at.toISOString(), JSON.stringify(b));
        return send(201, { ok: true });
      }
    }
  }

  const audioMatch = path.match(/^\/api\/samples\/([^/]+)\/audio$/);
  if (audioMatch && method === 'GET') {
    const sample = db.prepare('SELECT * FROM voice_samples WHERE id=?').get(audioMatch[1]);
    if (!sample) fail(404, 'Recording not found.');
    accessPatient(u, sample.patient_id);
    const audio = await readFile(resolve(dataDir, 'uploads', sample.filename));
    audit(db, u.id, 'Played recording', sample.patient_id, sample.id);
    res.writeHead(200, { 'Content-Type': 'audio/wav', 'Content-Length': audio.length });
    res.end(audio);
    return true;
  }
  return false;
}
