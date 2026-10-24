import { DatabaseSync } from 'node:sqlite';
import { existsSync, mkdirSync, readFileSync, renameSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomUUID } from 'node:crypto';

export const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
export function openDatabase(dataDir = process.env.DATA_DIR || resolve(root, 'data')) {
  mkdirSync(dataDir, { recursive: true });
  mkdirSync(resolve(dataDir, 'uploads'), { recursive: true });
  const file = resolve(dataDir, 'melo.sqlite');
  // Databases created before the rename keep their data; the WAL files must move with them.
  const legacy = resolve(dataDir, 'voice-practice.sqlite');
  if (!existsSync(file) && existsSync(legacy)) {
    for (const suffix of ['', '-wal', '-shm']) {
      if (existsSync(legacy + suffix)) renameSync(legacy + suffix, file + suffix);
    }
  }
  const db = new DatabaseSync(file);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;');
  db.exec(readFileSync(resolve(root, 'migrations/001_initial.sql'), 'utf8'));
  db.exec(readFileSync(resolve(root, 'migrations/002_care.sql'), 'utf8'));
  // SQLite has no ADD COLUMN IF NOT EXISTS, so the column is added once here.
  if (!db.prepare('PRAGMA table_info(users)').all().some(c => c.name === 'participant_code')) {
    db.exec('ALTER TABLE users ADD COLUMN participant_code TEXT');
    for (const { id } of db.prepare("SELECT id FROM users WHERE role='patient' ORDER BY created_at, rowid").all()) {
      db.prepare('UPDATE users SET participant_code=? WHERE id=?').run(nextParticipantCode(db), id);
    }
  }
  return db;
}
export function nextParticipantCode(db) {
  const highest = db.prepare("SELECT participant_code FROM users WHERE participant_code IS NOT NULL").all()
    .map(r => Number(r.participant_code.slice(1))).filter(Number.isInteger).reduce((a, b) => Math.max(a, b), 0);
  return `P${String(highest + 1).padStart(3, '0')}`;
}
export const now = () => new Date().toISOString();
export function publicUser(user) {
  if (!user) return null;
  const { password_hash, ...safe } = user;
  return safe;
}
export function audit(db, actor, action, target = null, detail = '') {
  db.prepare('INSERT INTO audit VALUES (?, ?, ?, ?, ?, ?)').run(randomUUID(), actor, action, target, detail, now());
}
export const consentVersion = 'CONNECTED-DEMO-1';
export const consentText = 'Prototype consent: I understand that this demonstration stores my profile, practice progress and voice recordings on the connected service and shares them with my assigned therapist. This placeholder must be replaced with approved study information before participant recruitment.';
