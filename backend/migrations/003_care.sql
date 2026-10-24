PRAGMA foreign_keys = ON;
-- Exercise activities were removed; their tables go with them.
DROP TABLE IF EXISTS exercise_library;
DROP TABLE IF EXISTS assignments;
DROP TABLE IF EXISTS completions;
DROP TABLE IF EXISTS diary_entries;
CREATE TABLE IF NOT EXISTS voice_samples (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id),
  body TEXT NOT NULL, filename TEXT NOT NULL, bytes INTEGER NOT NULL, created_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS samples_patient ON voice_samples(patient_id, created_at);
CREATE TABLE IF NOT EXISTS usage_events (
  seq INTEGER PRIMARY KEY AUTOINCREMENT, patient_id TEXT NOT NULL REFERENCES users(id),
  at TEXT NOT NULL, body TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS usage_patient ON usage_events(patient_id, at);
