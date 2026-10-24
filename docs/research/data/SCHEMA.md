# Data File Schema

Field definitions for every YAML file in `docs/research/data/`. These files are research outputs that the app can later seed from. They are not loaded by the app yet.

## Conventions

- Encoding UTF-8, two-space indentation, `snake_case` keys.
- Every file starts with a header block:

```yaml
schema_version: 1
generated: 2026-10-09          # date the file was last written
owner: 01-exercises            # research folder that owns the file
description: One sentence.
```

- IDs must exist in the owning Markdown file.
- `source` values are reference keys (for example `Stemple1994`, `AAOHNS2018`) that appear in the reference list of the Markdown file named in `doc`.
- Text fields are paraphrased. Never put questionnaire items, licensed program text, or copyrighted passages in YAML.

### Value object

Every numeric value is a mapping, never a bare number:

```yaml
duration_s:
  value: 15            # number, or null when not established
  min: null            # optional range bounds, for ranges or bands
  max: null
  unit: s              # SI or domain unit: s, Hz, dB, dBFS, dB SPL, cents, semitones, percent, ratio, count, per_day, per_week, days, weeks
  source: Stemple1994  # reference key, or null when not_established
  grade: moderate      # strong | moderate | limited | expert_opinion | none
  status: established  # established | provisional | not_established
  population: null     # required for norms: free text, e.g. "Belgian Dutch adults 20-60, n=50, both sexes"
  note: null           # optional, one sentence
```

Rules:
- `status: established` requires `source` and a `grade` other than `none`.
- `status: provisional` is a value chosen by the research team or taken from a single weak source, pending SLP panel or validation study; it requires `note` saying who must confirm it.
- `status: not_established` requires `value: null`, `source: null`, `grade: none`, and a `note` describing the study that would establish it.
- `population` is required whenever the value is a norm, cut-off, or reliability statistic.

### Shared enumerations

- `grade`: strong, moderate, limited, expert_opinion, none
- `direction`: higher_better, lower_better, closer_to_target, closer_to_one, context_dependent
- `verification_type` (matches `VerificationType` in `lib/features/exercises/domain/exercise.dart`): sustained, glide, notes, loudness, checklist
- `recording_task` (matches `RecordingTask` names): sustainedPhonation, readingPassage, spontaneousSpeech, sustainedA, maximumA, sustainedS, sustainedZ, vowelA, vowelI, vowelU, pitchGlide. New tasks proposed by research use the prefix `proposed_`, e.g. `proposed_softA`, `proposed_counting`.
- `severity` (red flags): urgent, priority, routine, informational
- `gate_role` (environment): quality_gate, interpretation_covariate, both, context_only
- `run_location`: on_device_live, on_device_post, offline

---

## exercises.yaml (owner 01-exercises)

```yaml
exercises:
  - id: EX-SOVT-STRAW
    doc: 01-exercises/sovt.md
    program: Semi-occluded vocal tract exercises
    name: Straw phonation
    seed_id: ex-straw                 # matching id in demo_program.dart, or null
    mechanism_summary: One to three sentences.
    indications: [DX-MTD-PRIMARY, DX-NODULES]       # DX IDs
    indication_notes: Free text for indications without a DX ID.
    contraindications: [Free text, ...]
    cautions: [Free text, ...]
    steps: [Paraphrased patient-facing step, ...]   # 3-7 steps
    dosage:
      repetitions: <value object, unit count>
      sessions_per_day: <value object, unit per_day>
      days_per_week: <value object, unit per_week>
      program_weeks: <value object, unit weeks>
      session_minutes: <value object, unit min>
    verification_type: glide
    targets:                          # value objects; omit keys that do not apply
      duration_s: ...
      pitch_hz: ...
      tolerance_cents: ...
      range_semitones: ...
      loudness_band_db: ...           # relative band, min/max
    progress_marker: Free text naming M- IDs where possible.
    stop_signals: [RF-PRACTICE-PAIN, ...]
    home_suitable: true | false | with_training
    teaching: Free text on demonstration needs.
    evidence_grade: strong | moderate | limited | expert_opinion
    evidence_sources: [Key, ...]
    licensing: open | licensed | trademark_only
```

## measures.yaml (owner 03-measures)

```yaml
measures:
  - id: M-CPPS-VOWEL
    doc: 03-measures/cepstral.md
    name: Smoothed cepstral peak prominence, sustained vowel
    definition: One to two sentences.
    tasks: [sustainedA]
    units: dB
    direction: higher_better
    algorithm:
      reference_implementation: Praat 6.x "To PowerCepstrogram" + "Get CPPS"
      parameters: {pitch_floor_hz: 60, time_step_s: 0.002, ...}   # numeric parameters as plain numbers here are allowed (they are settings, not findings)
      settings_source: Key
    run_location: on_device_post | offline
    norms:
      - group: Adult females, English, 18-60
        value: <value object with population>
    cutoffs:
      - label: dysphonia vs normal
        value: <value object with population>
        sensitivity: <value object, unit ratio>
        specificity: <value object, unit ratio>
        auc: <value object, unit ratio>
    reliability:
      icc: <value object>
      sem: <value object>
      mdc95: <value object>
    mcid: <value object>
    smartphone:
      validity: Free text summary.
      agreement: <value object, e.g. ICC or bias>
      recommended_role: primary | secondary | not_recommended
    sensitivity_to: [ENV-SNR, ENV-DISTANCE, ENV-CODEC]
    disorders_shifting: [{dx: DX-NODULES, direction: decreases}]
    indian_data: Free text, or "No Indian data found".
```

## verification.yaml (owner 05-exercise-data)

```yaml
verification:
  - exercise_id: EX-SOVT-STRAW
    doc: 05-exercise-data/<file>.md
    verification_type: glide
    signal: Free text.
    features: [{measure: M-F0-RANGE, note: ...}, {feature: voicing_continuity, note: ...}]
    pass_criteria:
      - criterion: Glide covers the target range
        threshold: <value object>
    tolerances:
      pitch_cents: <value object>
      duration_s: <value object>
    compliance_metric: Name and formula in words.
    failure_modes: [Free text, ...]
    false_positive_risks: [Free text, ...]
    run_location: on_device_live
```

## probe-battery.yaml (owner 05-exercise-data)

```yaml
probe_battery:
  - order: 1
    task: sustainedA
    name: Sustained /a/ at comfortable pitch and loudness
    repetitions: 3
    in_current_protocol: true          # present in ProbeProtocol.steps today
    instructions: Paraphrased standardized instruction.
    min_duration_s: <value object>
    measures: [M-CPPS-VOWEL, M-F0-MEAN, ...]
    rationale_source: Key
    requires_calibration: false
reading_passages:
  - language: hi
    name: Passage name
    status: validated | published_unvalidated | none_found
    licensing: Free text.
    source: Key
```

## environment-gates.yaml (owner 04-sensors-environment)

```yaml
gates:
  - factor: ENV-SNR
    doc: 04-sensors-environment/env-acoustic.md
    gate_role: quality_gate
    detection: Free text, naming S- IDs where relevant.
    run_location: on_device_live
    reject_threshold: <value object>
    warning_threshold: <value object>
    affected_measures: [M-JITTER-LOCAL, ...]
    patient_prompt: Paraphrased message for the patient.
    self_report_question: null | Paraphrased question.
```

## red-flags.yaml (owner 06-interpretation)

```yaml
red_flags:
  - id: RF-STRIDOR
    doc: 06-interpretation/red-flags.md
    name: Airway compromise
    trigger: Free text describing the self-report answer or data pattern.
    detection: self_report | data_rule | therapist_observation
    rule: null | Free text with thresholds as value objects below
    thresholds: {}
    severity: urgent
    patient_message: Paraphrased message.
    therapist_action: Free text.
    required_escalation: Free text naming who and how fast.
    sources: [Key, ...]
```

## proms.yaml (owner 06-interpretation)

```yaml
proms:
  - id: PROM-VHI10
    doc: 06-interpretation/proms.md
    name: Voice Handicap Index-10
    construct: Free text.
    domains: [Free text, ...]
    item_count: 10
    response_scale: Free text, e.g. "5-point frequency scale, 0-4"
    score_range: {min: 0, max: 40}
    direction: lower_better
    normal_cutoff: <value object>
    mcid: <value object>
    validated_languages: [{language: Hindi, source: Key, status: validated}]
    licensing: Free text.
    recall_period: Free text.
    administration_minutes: <value object>
    schedule_in_app: baseline_and_end | weekly | per_session
```

## status-rules.yaml (owner 06-interpretation)

```yaml
inputs:
  - name: adherence_rate
    definition: Free text.
    window_days: <value object>
thresholds:
  high_adherence: <value object>
  high_compliance: <value object>
metric_change_rules:
  - measure: M-CPPS-VOWEL
    threshold: <value object>
    method: mdc95 | mcid | rci | literature
probe_outcome_rules:
  - outcome: positive
    rule: Free text.
status_matrix:
  - adherence: high | low | any
    compliance: high | low | any | not_measured
    probe_outcome: positive | stable | mixed | negative | none
    status: onTrack                     # matches ParticipantStatus names; new statuses prefixed proposed_
    therapist_action: Free text.
    patient_message_key: Free text key.
```
