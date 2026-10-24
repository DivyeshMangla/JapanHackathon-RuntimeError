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
  return db;
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
export const exercises = [
  { id: 'humming', name: 'Gentle humming', description: 'Follow the humming technique demonstrated by your therapist.' },
  { id: 'straw', name: 'Straw phonation', description: 'Use the straw technique prescribed by your therapist.' },
  { id: 'breathing', name: 'Relaxed breathing', description: 'Practice the relaxed breathing pattern demonstrated in your session.' },
  { id: 'glides', name: 'Pitch glides', description: 'Follow your therapist’s comfortable pitch range.' },
  { id: 'resonance', name: 'Resonant voice', description: 'Practice your therapist’s resonant voice sequence.' },
  { id: 'reading', name: 'Reading practice', description: 'Read the passage selected by your therapist.' },
];
export const consentVersion = 'CONNECTED-DEMO-1';
export const consentText = 'Prototype consent: I understand that this demonstration stores my profile, practice progress and voice recordings on the connected service and shares them with my assigned therapist. This placeholder must be replaced with approved study information before participant recruitment.';
