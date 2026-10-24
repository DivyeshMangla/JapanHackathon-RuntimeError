CREATE TABLE IF NOT EXISTS expression_assignments (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES users(id),
  therapist_id TEXT NOT NULL REFERENCES users(id),
  expression_ids BLOB NOT NULL,
  enabled INTEGER NOT NULL CHECK(enabled IN (0,1)),
  updated_at TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS expression_assignment_patient ON expression_assignments(patient_id, updated_at);
CREATE TABLE IF NOT EXISTS expression_sessions (
  id TEXT PRIMARY KEY,
  patient_id TEXT NOT NULL REFERENCES users(id),
  assignment_id TEXT NOT NULL REFERENCES expression_assignments(id),
  answers BLOB NOT NULL,
  report BLOB NOT NULL,
  created_at TEXT NOT NULL,
  review_note BLOB,
  reviewed_by TEXT REFERENCES users(id),
  reviewed_at TEXT
);
CREATE INDEX IF NOT EXISTS expression_session_patient ON expression_sessions(patient_id, created_at);
