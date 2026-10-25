import { motorExercises } from './motor.mjs';

const cleanNote = value => typeof value === 'string' ? value.trim() : '';
const outcome = value => ['correct', 'on_track', 'needs_practice'].includes(value) ? value : 'not_assessed';
const latest = values => values.filter(Boolean).sort().at(-1) || null;
const trendWeeks = 8;
const weekStart = value => {
  const day = new Date(value);
  day.setUTCHours(0, 0, 0, 0);
  day.setUTCDate(day.getUTCDate() - (day.getUTCDay() + 6) % 7);
  return day;
};

// Weeks run Monday to Sunday (UTC) from the first practice, so a family sees
// change since the child started rather than a fixed window of empty weeks.
// A score is the share of scored work that met the goal; unscored work
// (not yet assessed) only adds to the practice count.
export function weeklyTrend(rows, date, score, today = new Date()) {
  const dates = rows.map(date).filter(Boolean);
  if (!dates.length) return [];
  const last = weekStart(today);
  const first = new Date(Math.max(weekStart(dates.sort()[0]).getTime(), last.getTime() - (trendWeeks - 1) * 7 * 86400000));
  const weeks = [];
  for (let start = first; start <= last; start = new Date(start.getTime() + 7 * 86400000)) {
    const end = start.getTime() + 7 * 86400000;
    const inWeek = rows.filter(row => {
      const at = new Date(date(row)).getTime();
      return at >= start.getTime() && at < end;
    });
    const scores = inWeek.map(score).filter(value => value !== null);
    const earned = scores.reduce((sum, [met]) => sum + met, 0);
    const possible = scores.reduce((sum, [, total]) => sum + total, 0);
    weeks.push({
      weekStart: start.toISOString().slice(0, 10),
      attempts: inWeek.length,
      score: possible ? Math.round(100 * earned / possible) : null,
    });
  }
  return weeks;
}

// This projection is deliberately separate from clinical records: families
// receive published clinician guidance, never recognition output or AI reports.
export function familyProgress({ clock = () => new Date(), fail, json, findUser, wordSnapshot = () => [], motorSnapshot = () => [], expressionSnapshot = () => [] }) {
  const reviewerName = id => id ? findUser(id)?.name || null : null;
  const goalScore = (reviewed, assessment, met) => row => {
    if (!reviewed(row)) return null;
    const value = assessment(row);
    return value === met ? [1, 1] : value === 'needs_practice' ? [0, 1] : null;
  };
  const metrics = (kind, rows, date, reviewed, assessment = () => 'not_assessed', score = goalScore(reviewed, assessment, kind === 'drawing' ? 'on_track' : 'correct')) => ({
    kind,
    trend: weeklyTrend(rows, date, score, clock()),
    attempts: rows.length,
    reviewed: rows.filter(reviewed).length,
    lastPracticedAt: latest(rows.map(date)),
    clinicianCorrect: rows.filter(row => reviewed(row) && assessment(row) === 'correct').length,
    clinicianNeedsPractice: rows.filter(row => reviewed(row) && assessment(row) === 'needs_practice').length,
    clinicianOnTrack: rows.filter(row => reviewed(row) && assessment(row) === 'on_track').length,
  });
  return async function route(req, res, path, user) {
    const match = path.match(/^\/api\/patients\/([^/]+)\/family-progress$/);
    if (!match) return false;
    const patient = findUser(match[1]);
    if (!patient || patient.role !== 'patient') fail(404, 'Child not found.');
    const allowed = user.role === 'patient' && user.id === patient.id
      || user.role === 'parent' && user.id === patient.parent_id
      || user.role === 'therapist' && user.id === patient.therapist_id && user.status === 'active';
    if (!allowed) fail(403, 'This child is not paired with your account.');
    if (req.method !== 'GET') fail(405, 'Method not allowed.');
    const words = wordSnapshot(patient.id);
    const drawings = motorSnapshot(patient.id);
    const expressions = expressionSnapshot(patient.id);
    const wordMetrics = metrics('words', words, row => row.date, row => row.reviewed === true, row => outcome(row.therapistOutcome));
    const drawingMetrics = metrics('drawing', drawings, row => row.created_at, row => !!row.reviewed_at, row => outcome(row.therapist_outcome));
    const expressionMetrics = {
      ...metrics('expressions', expressions, row => row.createdAt, row => !!row.reviewedAt, undefined, row => row.total ? [row.correct, row.total] : null),
      quizCorrect: expressions.reduce((sum, row) => sum + row.correct, 0),
      quizTotal: expressions.reduce((sum, row) => sum + row.total, 0),
      quizIndependentCorrect: expressions.filter(row => row.assistance === 'independent').reduce((sum, row) => sum + row.correct, 0),
      quizIndependentTotal: expressions.filter(row => row.assistance === 'independent').reduce((sum, row) => sum + row.total, 0),
      quizAssistedCorrect: expressions.filter(row => row.assistance === 'with_help').reduce((sum, row) => sum + row.correct, 0),
      quizAssistedTotal: expressions.filter(row => row.assistance === 'with_help').reduce((sum, row) => sum + row.total, 0),
    };
    const feedback = [
      ...words.filter(row => row.reviewed === true && (cleanNote(row.feedback) || row.hasFeedbackAudio || outcome(row.therapistOutcome) !== 'not_assessed')).map(row => ({
        id: `words-${row.id}`, kind: 'words', title: row.word,
        text: cleanNote(row.feedback), hasAudio: !!row.hasFeedbackAudio,
        audioPath: row.hasFeedbackAudio ? `/useful-words/patients/${encodeURIComponent(patient.id)}/attempts/${encodeURIComponent(row.id)}/feedback` : null,
        assessment: outcome(row.therapistOutcome), practiceAt: row.date,
        reviewedAt: row.reviewedAt || null, therapistName: reviewerName(row.reviewedBy),
      })),
      ...drawings.filter(row => row.reviewed_at && (cleanNote(row.review_note) || outcome(row.therapist_outcome) !== 'not_assessed')).map(row => ({
        id: `drawing-${row.id}`, kind: 'drawing',
        title: motorExercises.find(exercise => exercise.id === row.exercise_id)?.name || null,
        text: cleanNote(row.review_note), hasAudio: false, audioPath: null,
        assessment: outcome(row.therapist_outcome), practiceAt: row.created_at,
        reviewedAt: row.reviewed_at, therapistName: reviewerName(row.reviewed_by),
      })),
      ...expressions.filter(row => row.reviewedAt && cleanNote(row.reviewNote)).map(row => ({
        id: `expressions-${row.id}`, kind: 'expressions', title: null,
        text: cleanNote(row.reviewNote), hasAudio: false, audioPath: null,
        assessment: 'not_assessed', practiceAt: row.createdAt,
        reviewedAt: row.reviewedAt, therapistName: reviewerName(row.reviewedBy),
      })),
    ].sort((a, b) => (b.reviewedAt || b.practiceAt).localeCompare(a.reviewedAt || a.practiceAt));
    json(res, 200, {
      patientId: patient.id,
      therapistName: reviewerName(patient.therapist_id),
      activities: [wordMetrics, drawingMetrics, expressionMetrics],
      feedback,
    });
    return true;
  };
}
