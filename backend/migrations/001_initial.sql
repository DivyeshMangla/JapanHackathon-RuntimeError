PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY, name TEXT NOT NULL, email TEXT NOT NULL UNIQUE COLLATE NOCASE,
  password_hash TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('admin','therapist','parent','patient')),
  status TEXT NOT NULL CHECK(status IN ('active','pending','disabled')),
  clinic TEXT NOT NULL DEFAULT '', registration TEXT NOT NULL DEFAULT '',
  therapist_id TEXT REFERENCES users(id), created_at TEXT NOT NULL,
  participant_code TEXT, parent_id TEXT REFERENCES users(id), link_code TEXT
);
CREATE TABLE IF NOT EXISTS sessions (
  token_hash TEXT PRIMARY KEY, user_id TEXT NOT NULL REFERENCES users(id), expires_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS login_attempts (
  key TEXT PRIMARY KEY, failures INTEGER NOT NULL, reset_at INTEGER NOT NULL
);
CREATE TABLE IF NOT EXISTS consents (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id), version TEXT NOT NULL,
  signer_name TEXT NOT NULL, signature_png TEXT NOT NULL, checks TEXT NOT NULL,
  status TEXT NOT NULL CHECK(status IN ('pending','approved')), signed_at TEXT NOT NULL,
  approved_by TEXT REFERENCES users(id), approved_at TEXT, paper_copy INTEGER NOT NULL DEFAULT 0
);
CREATE TABLE IF NOT EXISTS plans (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id), therapist_id TEXT NOT NULL REFERENCES users(id),
  consent_id TEXT NOT NULL REFERENCES consents(id), title TEXT NOT NULL, exercises TEXT NOT NULL,
  sessions_per_day INTEGER NOT NULL, notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS clinical_forms (
  patient_id TEXT PRIMARY KEY REFERENCES users(id), age INTEGER NOT NULL,
  demographic TEXT NOT NULL, clinical TEXT NOT NULL,
  saved_by TEXT NOT NULL REFERENCES users(id), updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS progress (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id), plan_id TEXT NOT NULL REFERENCES plans(id),
  exercise_id TEXT NOT NULL, minutes INTEGER NOT NULL, completed_at TEXT NOT NULL, received_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS recordings (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id), plan_id TEXT NOT NULL REFERENCES plans(id),
  exercise_id TEXT NOT NULL, filename TEXT NOT NULL, mime TEXT NOT NULL, bytes INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL, created_at TEXT NOT NULL, review_note TEXT, reviewed_by TEXT REFERENCES users(id)
);
CREATE TABLE IF NOT EXISTS audit (
  id TEXT PRIMARY KEY, actor_id TEXT REFERENCES users(id), action TEXT NOT NULL,
  target_id TEXT, detail TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS settings (key TEXT PRIMARY KEY, value TEXT NOT NULL);
CREATE INDEX IF NOT EXISTS patient_therapist ON users(therapist_id);
CREATE INDEX IF NOT EXISTS progress_patient ON progress(patient_id, completed_at);
CREATE INDEX IF NOT EXISTS consent_patient ON consents(patient_id, signed_at);
CREATE INDEX IF NOT EXISTS plans_patient ON plans(patient_id, created_at);
CREATE INDEX IF NOT EXISTS recording_patient ON recordings(patient_id, created_at);
