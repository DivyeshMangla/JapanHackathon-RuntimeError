import { scrypt, randomBytes, timingSafeEqual, createHash } from 'node:crypto';
import { promisify } from 'node:util';
const derive = promisify(scrypt);
export async function hashPassword(password) {
  const salt = randomBytes(16).toString('hex');
  const hash = await derive(password, salt, 64);
  return `scrypt:${salt}:${hash.toString('hex')}`;
}
export async function verifyPassword(password, encoded) {
  const [, salt, expected] = encoded.split(':');
  const actual = await derive(password, salt, 64);
  return timingSafeEqual(actual, Buffer.from(expected, 'hex'));
}
export const tokenHash = value => createHash('sha256').update(value).digest('hex');
export function newSession(db, userId) {
  const token = randomBytes(32).toString('base64url');
  const expires = Date.now() + 7 * 24 * 60 * 60 * 1000;
  db.prepare('DELETE FROM sessions WHERE expires_at < ?').run(Date.now());
  db.prepare('INSERT INTO sessions VALUES (?, ?, ?)').run(tokenHash(token), userId, expires);
  return token;
}
export function requestToken(req) {
  const bearer = req.headers.authorization?.match(/^Bearer ([\w-]+)$/)?.[1];
  return bearer || req.headers.cookie?.match(/(?:^|;\s*)vp_session=([\w-]+)/)?.[1];
}
export function authenticate(db, req) {
  const token = requestToken(req);
  if (!token) return null;
  return db.prepare(`SELECT u.* FROM sessions s JOIN users u ON u.id=s.user_id
    WHERE s.token_hash=? AND s.expires_at>? AND u.status='active'`).get(tokenHash(token), Date.now());
}
