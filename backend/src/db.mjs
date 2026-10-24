import { DatabaseSync } from 'node:sqlite';
import { existsSync, mkdirSync, readFileSync, renameSync } from 'node:fs';
import { resolve, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { randomBytes, randomUUID } from 'node:crypto';
import { motorExercises } from './motor.mjs';

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
  const initial = readFileSync(resolve(root, 'migrations/001_initial.sql'), 'utf8');
  db.exec(initial);
  db.exec(readFileSync(resolve(root, 'migrations/003_care.sql'), 'utf8'));
  // SQLite has no ADD COLUMN IF NOT EXISTS, so the column is added once here.
  if (!db.prepare('PRAGMA table_info(users)').all().some(c => c.name === 'participant_code')) {
    db.exec('ALTER TABLE users ADD COLUMN participant_code TEXT');
    for (const { id } of db.prepare("SELECT id FROM users WHERE role='patient' ORDER BY created_at, rowid").all()) {
      db.prepare('UPDATE users SET participant_code=? WHERE id=?').run(nextParticipantCode(db), id);
    }
  }
  if (!db.prepare("SELECT sql FROM sqlite_master WHERE name='users'").get().sql.includes("'parent'")) addFamilyAccounts(db, initial);
  db.exec(`CREATE UNIQUE INDEX IF NOT EXISTS users_link_code ON users(link_code);
    CREATE INDEX IF NOT EXISTS users_parent ON users(parent_id);`);
  for (const { id } of db.prepare("SELECT id FROM users WHERE role IN ('therapist','parent') AND link_code IS NULL").all()) {
    db.prepare('UPDATE users SET link_code=? WHERE id=?').run(newLinkCode(db), id);
  }
  db.exec(readFileSync(resolve(root, 'migrations/002_motor.sql'), 'utf8'));
  return db;
}
// Databases created before parents had accounts carry a role CHECK that SQLite
// cannot alter in place, so the users table is rebuilt from the current schema.
function addFamilyAccounts(db, initial) {
  const schema = initial.match(/CREATE TABLE IF NOT EXISTS users \([\s\S]*?\n\);/)[0].replace('IF NOT EXISTS users', 'users_next');
  const columns = 'id,name,email,password_hash,role,status,clinic,registration,therapist_id,created_at,participant_code';
  db.exec('PRAGMA foreign_keys = OFF');
  db.exec('BEGIN');
  try {
    db.exec(`${schema}
      INSERT INTO users_next(${columns}) SELECT ${columns} FROM users;
      DROP TABLE users;
      ALTER TABLE users_next RENAME TO users;`);
    db.exec('COMMIT');
  } catch (error) { db.exec('ROLLBACK'); throw error; }
  finally { db.exec('PRAGMA foreign_keys = ON'); }
  db.exec(initial);
}
// No 0/O or 1/I/L, so a code read aloud or copied from a screen is unambiguous.
const codeAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
export function newLinkCode(db) {
  for (;;) {
    const code = Array.from(randomBytes(6), byte => codeAlphabet[byte % codeAlphabet.length]).join('');
    if (!db.prepare('SELECT 1 FROM users WHERE link_code=?').get(code)) return code;
  }
}
export const normalizeLinkCode = value => typeof value === 'string' ? value.replace(/[\s-]/g, '').toUpperCase() : '';
export function nextParticipantCode(db) {
  const highest = db.prepare("SELECT participant_code FROM users WHERE participant_code IS NOT NULL").all()
    .map(r => Number(r.participant_code.slice(1))).filter(Number.isInteger).reduce((a, b) => Math.max(a, b), 0);
  return `P${String(highest + 1).padStart(3, '0')}`;
}
export const now = () => new Date().toISOString();
export function publicUser(user) {
  if (!user) return null;
  const { password_hash, ...safe } = user;
  // A child set up from a parent's code has a placeholder address nobody signs in with.
  return user.role === 'patient' && user.parent_id ? { ...safe, email: null } : safe;
}
export function audit(db, actor, action, target = null, detail = '') {
  db.prepare('INSERT INTO audit VALUES (?, ?, ?, ?, ?, ?)').run(randomUUID(), actor, action, target, detail, now());
}
export const exercises = [...motorExercises];
export const consentVersion = 'CONNECTED-DEMO-3';
export const consentText = 'Prototype consent: I understand that this demonstration stores my profile, practice progress, handwriting photos and voice recordings on the connected service and shares them with my assigned therapist. An adult signs for a child. Optional automated analysis describes visible practice marks and may suggest recognized speech and pronunciation reports for therapist review. Estimates may be inaccurate or unable to assess reliably; pronunciation accuracy requires a model validated for the child’s age, language and speech characteristics. This placeholder must be replaced with approved study information before participant recruitment.';
