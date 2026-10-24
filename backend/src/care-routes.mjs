import { randomUUID } from 'node:crypto';
import { readFile, writeFile, unlink } from 'node:fs/promises';
import { resolve } from 'node:path';
import { audit, now } from './db.mjs';

const MAX_AUDIO_BYTES = 18 * 1024 * 1024;
const MAX_BODY_BYTES = 26 * 1024 * 1024;
const idPattern = /^[A-Za-z0-9._:-]{1,120}$/;

const parse = row => JSON.parse(row.body);

/**
 * Routes for the directory, study settings, voice samples and the usage log
 * used by the role-based mobile app. Returns true when the
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

  if (path === '/api/directory' && method === 'GET') {
    // Names only, so a screen can show who a family's therapist is.
    const ids = new Set([u.id]);
    if (['patient', 'parent'].includes(u.role) && u.therapist_id) ids.add(u.therapist_id);
    if (u.role === 'patient' && u.parent_id) ids.add(u.parent_id);
    const users = [...ids].map(id => findUser(id)).filter(Boolean).map(x => ({ id: x.id, name: x.name, role: x.role }));
    return send(200, { users });
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
  if (path === '/api/usage' && method === 'GET') {
    requireRole(u, 'admin');
    return send(200, { events: db.prepare('SELECT body FROM usage_events ORDER BY at, seq').all().map(parse) });
  }

  const match = path.match(/^\/api\/patients\/([^/]+)\/(samples|usage)(?:\/([^/]+))?$/);
  if (match) {
    const [, patientId, kind, itemId] = match;
    const patient = accessPatient(u, patientId);

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
