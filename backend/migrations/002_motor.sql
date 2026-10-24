CREATE TABLE IF NOT EXISTS motor_submissions (
  id TEXT PRIMARY KEY, patient_id TEXT NOT NULL REFERENCES users(id),
  plan_id TEXT NOT NULL REFERENCES plans(id), exercise_id TEXT NOT NULL,
  filename TEXT NOT NULL, mime TEXT NOT NULL, bytes INTEGER NOT NULL,
  photo_hash TEXT NOT NULL, practice_day TEXT NOT NULL, created_at TEXT NOT NULL,
  analysis_status TEXT NOT NULL CHECK(analysis_status IN ('pending','processing','ready','unavailable','declined')),
  report TEXT, review_note TEXT, reviewed_by TEXT REFERENCES users(id), reviewed_at TEXT
);
CREATE INDEX IF NOT EXISTS motor_patient ON motor_submissions(patient_id, created_at);
