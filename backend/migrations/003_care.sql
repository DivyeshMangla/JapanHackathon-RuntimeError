PRAGMA foreign_keys = ON;
CREATE TABLE IF NOT EXISTS exercise_library (
  id TEXT PRIMARY KEY, body TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS assignments (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id),
  body TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS completions (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id),
  exercise_id TEXT NOT NULL, day TEXT NOT NULL, completed_at TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS voice_samples (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id),
  body TEXT NOT NULL, filename TEXT NOT NULL, bytes INTEGER NOT NULL, created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS assignments_patient ON assignments(patient_id);
CREATE INDEX IF NOT EXISTS completions_patient ON completions(patient_id, day);
CREATE INDEX IF NOT EXISTS samples_patient ON voice_samples(patient_id, created_at);
CREATE TABLE IF NOT EXISTS diary_entries (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id),
  day TEXT NOT NULL, body TEXT NOT NULL
);
CREATE TABLE IF NOT EXISTS usage_events (
  seq INTEGER PRIMARY KEY AUTOINCREMENT, patient_id TEXT NOT NULL REFERENCES users(id),
  at TEXT NOT NULL, body TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS diary_patient ON diary_entries(patient_id, day);
CREATE INDEX IF NOT EXISTS usage_patient ON usage_events(patient_id, at);
