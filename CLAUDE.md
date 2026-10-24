# Project Engineering Standards

This is a production-grade Flutter app handling confidential patient data (stored locally only, no cloud). Write code a senior Flutter engineer would approve in review. Follow these rules for every change.

## Architecture
- Feature-first structure: lib/features/<feature>/{data,domain,presentation}/, plus lib/core/ (theme, routing, utils, constants, errors) and lib/shared/ (reusable widgets).
- Use the state management solution already in the project. Never introduce a second one.
- Data access goes through repository classes only. Widgets never touch storage directly.
- Voice analysis stays behind an abstract interface (e.g. VoiceAnalyzer) with a stub implementation, so the real engine can be swapped in later without touching UI code.
- Role-based access (patient, therapist, admin) is enforced in routing guards, not scattered if-checks inside screens.

## Data & Security
- Patient data must be encrypted at rest. Keep encryption keys in flutter_secure_storage.
- No network calls that send patient data anywhere.
- Models are immutable, with typed serialization (freezed/json_serializable or equivalent). No raw Map<String, dynamic> passed around the app.

## UI
- All colors, text styles, spacing, and radii come from the central theme and constants. No hardcoded Color(0xFF...), TextStyle(fontSize: ...), or magic padding values in widgets.
- Use a spacing scale (4/8/12/16/24/32) and 2-3 radius values only.
- No gradients, glow effects, or emojis in UI text unless explicitly requested.
- Every screen that loads data handles loading, empty, error, and success states.
- Forms show inline validation messages and disable submit while processing.
- Add Semantics labels to icon buttons and custom controls. Tap targets are at least 48x48.
- Split widgets into separate classes when a build method exceeds ~80 lines. Prefer extracted widget classes over _buildX() helper methods.
- Use const constructors wherever possible.
- User-facing strings go in one place (l10n or a strings file), never inline.

## Code Style
- Comments explain WHY, never WHAT. Don't narrate obvious code.
- No print() or debugPrint() in committed code. Use a logger behind a single wrapper.
- No emojis in code, logs, comments, or commit messages.
- No commented-out code, no stale TODOs, no unused imports or dead files.
- Never create files like *_old.dart, *_new.dart, *_v2.dart, or test.dart. Edit the real file.
- Descriptive names. No data, temp, result2, handleTap2.
- Errors are caught at the repository/service layer, converted to typed failures, and shown to the user with a clear message. Never swallow exceptions silently.
- Code must pass `dart format` and `flutter analyze` with zero warnings.

## Repo Hygiene
- Do NOT create summary or report markdown files (IMPLEMENTATION_SUMMARY.md, CHANGES.md, SETUP_GUIDE.md, etc.). Report work in chat only.
- Only add a pubspec dependency when genuinely needed, and state why.
- Keep changes scoped to the task. No unrelated refactors without asking.
- Commit messages follow Conventional Commits: feat(scope): ..., fix(scope): ..., refactor(scope): ...

---

# Melo

A Flutter prototype that helps voice therapy patients follow their home exercise program and lets therapists monitor adherence. Everything runs on the device: no cloud services, no remote backend.

## Running the app

Requires Flutter 3.38 (stable) or newer, plus an Android device or emulator (API 24+) or an iOS device or simulator.

```bash
flutter pub get
flutter run
```

Checks that must pass before work is considered done:

```bash
flutter analyze
flutter test
```

The first launch creates the encryption key, opens the encrypted boxes and seeds demo data. It takes a few seconds while the demo passwords are hashed.

If Android Studio is open on this project, do not also build from the terminal. Two Gradle builds in the same `build/` folder delete each other's files and fail with "file does not exist" errors. A full debug APK holds every CPU architecture (about 160 MB); `flutter run` or `flutter build apk --debug --split-per-abi` produces a single-architecture build of about 75 MB, which matters on emulators with little free storage.

### Seeded accounts

| Role | Email | Password |
| --- | --- | --- |
| Research admin | admin@melo.local | AdminDemo2026 |
| Therapist | a.ortiz@melo.local | TherapistDemo2026 |
| Therapist | s.park@melo.local | TherapistDemo2026 |
| Patient P001 (Ortiz) | p001@melo.local | PatientDemo2026 |
| Patient P002 (Ortiz) | p002@melo.local | PatientDemo2026 |
| Patient P003 (Ortiz) | p003@melo.local | PatientDemo2026 |
| Patient P004 (Park) | p004@melo.local | PatientDemo2026 |
| Patient P005 (Park) | p005@melo.local | PatientDemo2026 |
| Patient P006 (Park, intervention finished) | p006@melo.local | PatientDemo2026 |

To reset the demo data, uninstall the app or clear its storage.

## Folder structure

```
lib/
  main.dart                 opens storage, seeds, migrates, starts the app
  app.dart                  MaterialApp.router, theme, localization, grain
  core/
    errors/                 typed failures shown to the user
    routing/                go_router config, role-based redirect, RoleShell
    security/               bcrypt password hashing (background isolate)
    storage/                encrypted Hive setup and key management
    theme/                  colors, type, spacing, radius and motion tokens
    utils/                  dates, formatting, l10n access helpers
  shared/
    widgets/                design-system widgets (buttons, inputs, cards,
                            seal, brush stroke, ink wash, skeletons, empty
                            states, stat tiles, pills)
  features/<feature>/
    domain/                 immutable models, pure rules, repository
                            interfaces; no Flutter or Riverpod imports
    data/                   Hive repositories and the Riverpod providers that
                            construct them
    presentation/           screens and widgets
      controllers/          Riverpod providers, notifiers and action classes
  l10n/app_en.arb           English source strings (generated/ is ignored)
test/                       unit tests
assets/fonts/               bundled, script-subset font files (OFL)
```

Features: `auth`, `exercises`, `recordings`, `reminders`, `settings`, `study` (status matrix, study record, monitoring forms, intervention outcomes, feasibility and statistics), `questionnaires` (self-reports, usability, satisfaction feedback), `education` (Learn topics), `usage` (application usage log), `audit` (access log), `patient`, `therapist`, `admin`, `demo_data` (first-launch seeder), `capture_quality` (signal analysis, noise removal, take quality, sensors; no screens), `diagnostics` (debug-only sensor check screen), `setup` (offline device onboarding: role choice, therapist PIN and keys, patient join, consent signing, signed plan transfer), `connected` (the connected-care flavor: account sign-in and registration, therapist PIN lock, consent, plans, practice and recording sync).

## Architecture decisions

- **Repository interfaces.** UI and controllers depend only on interfaces in `domain/` (for example `UserRepository`, `AuthRepository`). The Hive classes in `data/` are wired up in Riverpod providers, so a self-hosted server implementation can be swapped in by changing one provider.
- **Riverpod without code generation.** Plain `Provider`, `NotifierProvider` and `AsyncNotifierProvider` keep the build free of `build_runner`.
- **Storage is opened before `runApp`.** `main()` opens the database, overrides `localDatabaseProvider` in a `ProviderContainer`, runs the seeder, then hands the container to `UncontrolledProviderScope`.
- **Routing.** `routerProvider` builds a single `GoRouter` whose `refreshListenable` follows `authControllerProvider`. `redirectFor` is a pure function (unit tested) that holds on the splash route while the session is restoring, sends signed-out users to `/login`, and keeps each role inside its own route tree (`/patient`, `/therapist`, `/admin`).
- **Role areas are tab shells.** Each role's routes live in its feature (`patient/presentation/patient_routes.dart`) as a `StatefulShellRoute.indexedStack`, so every tab keeps its own navigation stack. The shell is wrapped in `SignedInGate`, which renders nothing in the frames between sign-out and the redirect, so screens can read `currentUserProvider` without null checks.
- **Shared activity provider.** `patientActivityProvider(patientId)` loads a patient's schedules, the exercise library and 56 days of completions, and derives daily adherence once. Patient screens use it now; therapist screens will reuse it. Mutations go through small action classes (`CompletionActions`, `ReminderActions`) that write via the repository and then invalidate the affected provider.
- **Adherence maths is pure.** `Adherence` in `exercises/domain/adherence.dart` turns schedules and completions into per-day or per-week due/done counts, rates and streaks. It is unit tested.
- **One audio player.** `playbackProvider` owns a single `just_audio` player, so starting one recording stops any other. The recording flow releases it before moving or deleting a file.
- **Reminders follow the session.** `reminderSyncProvider`, watched at the app root, schedules a patient's daily reminders when they sign in and cancels all reminders on sign-out, so a shared device never shows another person's reminders.
- **Caseload access is checked, not just hidden.** `caseloadProvider` loads only the signed-in therapist's patients. Participant screens look patients up through `caseloadParticipantProvider`, which returns null for anyone not on that caseload, so typing another patient's id into a URL shows "Participant not found".
- **Analysis seam.** `AnalysisService` (`recordings/domain/analysis_service.dart`) is the only thing the UI knows about voice analysis. `analysisServiceProvider` supplies `StubAnalysisService`, which does no signal processing and reports every recording as pending. A real analyser replaces that one provider.
- **Take quality check.** After every take, `TakeQualityChecker` decodes the draft WAV on a background isolate and `assessTake` measures SNR (mean voiced level over the quietest tenth of blocks, after an 80 Hz high-pass), clipping and voiced length. The recording session also samples the gyroscope and accelerometer during the take. Thresholds follow research doc 4.3: SNR 42 dB or more is good, under 30 dB is poor, clipping must stay under 0.1%; more than 25% of the take spent moving is poor (provisional). A poor take makes "Record again" the main action, but the patient can still keep it. The check is advisory and never alters the audio; a failed check only hides the card.
- **Noise removal is display only.** `SpectralDenoiser` is a log-MMSE (Ephraim and Malah) estimator with a decision-directed a priori SNR. It learns the noise spectrum only from blocks the level detector marks as background, so a long held vowel is never learned as noise. It drives the sensor check screen only. Saved recordings are never processed, because noise reduction changes jitter, shimmer, HNR and CPP. `NoiseProfiler` classifies the background (rumble, 50/60 Hz mains hum, tonal whine, broadband, fluctuating, clicks) from a 4096-point spectrum of background-only audio; its thresholds are provisional heuristics.
- **Sensor check screen.** `/sensor-check` is reachable from the login screen in debug and profile builds only (`!kReleaseMode`) and is allowed while signed out. It uses its own oscilloscope palette (`DiagnosticColors`, `AppTheme.diagnostics`), kept apart from the design.md tokens. The microphone streams PCM to memory only. `sensors_plus` (gyroscope and accelerometer, also used by the take check) and `proximity_sensor` were added for it.
- **Typed failures.** `core/errors/app_failure.dart` defines a sealed `AppFailure` hierarchy (`StorageFailure`, `RecordingFailure`, `PlaybackFailure`, `ReminderFailure`, `ExportFailure`, `InvalidInputFailure`, `SensorFailure`). Every repository method and platform service (vault, recorder, reminder scheduler, export) runs inside `guard`/`guardStorage`, which logs the underlying error and rethrows it as a typed failure. Screens never see raw exceptions: write actions go through `runWithFailureMessage` (a snackbar with a localized message), `AsyncView` names the failure on load errors, and the recording session reports failures through its state. Reminder sync and startup migration log failures instead of blocking sign-in or launch.
- **Logging.** `AppLogger` (`core/logging`) is the only logging entry point and writes to the platform log via `dart:developer`. It never sends anything off the device. Callers log failure types and technical details, never patient names, emails or audio. `print` is banned by lint.
- **Protocol coverage.** The study protocol's baseline assessment, intervention, follow-up, outcome measures and data collection instruments map to the app as follows. Information sheet and written consent: recorded when the admin enrols a patient (required) and editable in the study record. Demographic and Clinical Information Form, orientation date and intervention start: the therapist's study record screen. Baseline adherence assessment: the patient's week-0 self-report. Application Usage Log: `usage`. Adherence and Compliance Monitoring Form: one therapist form per study week. Participant self-report: a weekly questionnaire. Usability Feedback Questionnaire: the System Usability Scale. Feedback: structured satisfaction items plus three open questions for thematic analysis. Educational support and orientation: the Learn topics. The Participant Information Sheet and Written Consent Form themselves stay on paper; the Learn topic "About this study" is a plain-language summary, not a replacement.
- **Intervention outcomes.** `InterventionOutcome` (`study/domain`) scores the participant's own study period (`StudyPeriod`: `studyWeeks` weeks from the study record's intervention start), finished days only. Adherence is the protocol formula: completed sessions over prescribed sessions. Compliance ("follows recommended frequency and schedule") is the share of prescribed days on which the full daily dose was completed on that day. Each study week shows the four sources the protocol names side by side: application log, practice recordings, participant self-report and therapist monitoring form. The 14-day window in the existing therapist and patient views is unchanged.
- **Questionnaire timing.** `StudyTasks` decides what is due: the baseline self-report until submitted; each week's self-report from the last day of that week for seven days; usability and feedback from the last intervention day on. A withdrawn participant is asked for nothing and no more probes.
- **Feasibility and statistics.** `StudyOutcomes` computes recruitment rate (enrolled over the admin-entered number of eligible people approached), retention rate (enrolled participants not withdrawn) and app usage completion (practice marked in every study week, over participants whose intervention has ended, withdrawals counting as not completing). `statistics.dart` gives mean, sample SD, median and percentages, and both paired tests from the analysis plan: paired t-test (Student's t via the regularized incomplete beta) and Wilcoxon signed-rank (exact without ties up to n = 25, otherwise normal approximation with tie and continuity corrections). Both are unit tested against SciPy. The app reports both and leaves the choice to the analyst. In-app, they compare self-reported practice at baseline and in the final week.
- **Exercise library.** The library ships empty. The speech-therapy catalogue was removed when the app moved to autism therapy; exercises are added through the admin library editor, and demo accounts start with no assignments or completion history.
- **Clinician-chosen material.** Twelve entries depend on what the clinician picks (syllables, words, water depth, a care plan, effort limits). They are flagged `needsInstructions`, and an assignment cannot be saved without per-patient instructions, which the patient sees as "Your therapist's instructions". Program cautions (vocal strength and closure) and the water-straw safety note show to therapists when assigning and to patients with the exercise.
- **Voice-use monitoring.** The hygiene exercise "Voice-use monitoring" is a `voiceDiary` exercise: ticking its session opens a diary form (speaking time, fatigue 0 to 10, situations), and saving it marks the session. Therapists see the entries on the assessment screen; they are exported as a CSV.
- **Usage logging never blocks.** `UsageLogger` records patient actions only (sign-in, sign-out, exercise and Learn views, sessions marked and undone, recordings saved, questionnaires submitted, reminder changes). A failed write is logged and the patient's action still succeeds.
- **Setup flow.** `main.dart` currently starts `SetupApp`, the offline two-phone onboarding described in README_SETUP.md, instead of the legacy app. `SetupService` owns every setup mutation. Its signed records stay as maps inside the service, because their exact JSON is what the signatures cover, and widgets read immutable models only (`TherapistProfile`, `SetupPatient`, `ConsentSummary`, `ConsentItem`, `ParticipantForms` in `setup/domain`). Every refusal is a `SetupFailure` with a `SetupFailureReason` (`core/errors/setup_failure.dart`), which the pages map to a localized message through `setupFailureMessageKey`; any other error is logged and shown as a generic package failure. Setup strings live in `features/setup/l10n/setup_{en,hi,pa}.arb`, loaded by `SetupStrings`, and a test checks every failure reason has a message in all three.
- **Connected care (opt-in flavor).** `lib/main_connected.dart` with `--flavor connected` talks to the Node service in `backend/` (API, SQLite, uploads) that also serves the admin dashboard in `admin/`; see `docs/CONNECTED_WORKSPACE.md` and `backend/README.md`. It is the one place the app sends patient data off the device, by design and only in that flavor: the study and setupcheck release builds still remove the INTERNET permission. `ConnectedService` (`connected/data`) keeps the session token in secure storage, caches the last records in an encrypted Hive box per API origin and account, and queues practice and recordings in an outbox that uploads in order with server-side idempotent ids. Screens read the typed models in `connected/domain`; every failure is a `ConnectedFailure` (`core/errors/connected_failure.dart`) mapped to a localized message, except a rejected request, which shows the server's own explanation. Connected strings live in `app_en.arb` with the `connected` prefix.
- **Failed sign-in does not touch auth state.** `AuthController.signIn` returns `false` and leaves state unchanged, so the router does not react to a bad password.

## Data model and storage

- `User`: id, role (patient, therapist, admin), name, email, createdAt, participantCode (patients only, e.g. P001), therapistId (patients only).
- `Exercise` (research doc 7.4): id, title, program, summary, steps, durationMinutes, default repetitions and sessionsPerDay, verificationType (sustained, glide, notes, loudness, checklist, voiceDiary), defaultTargets, evidenceSource, programNote (the program's purpose or usage note, stored per exercise so approving an exercise approves the guidance shown with it), caution, needsInstructions, catalogueOrder (position in the clinical source; orders programs and exercises), approvedBy, approvedAt, archived. Status is derived: pending approval (no approval), approved, or archived. Any content edit clears the approval. Only approved exercises can be assigned.
- `Schedule` (an assignment version): id, patientId, exerciseId, weekdays (1 = Monday to 7 = Sunday), sessionsPerDay, repetitions, targets (durationSec, pitchHz, toleranceCents, rangeSemitones), instructions (the therapist's per-patient instructions, required when the exercise needs them), effectiveFrom, effectiveTo (null while current), assignedBy. Editing closes the current version yesterday and starts a new one today; ending an assignment closes it. A version that only started today is replaced rather than split.
- `Completion`: id, patientId, exerciseId, day, completedAt. One record per session; a day's sessions count up to that version's sessionsPerDay.
- `Recording`: id, patientId, kind (practice or probe), task, type (baseline, follow-up, home practice), trial, probeSessionId, filePath (encrypted file), durationSec, createdAt, analysisStatus (always `pending`).
- `StudySettings`: adherenceThreshold (default 0.8), probeIntervalDays (default 7), studyWeeks (default 4).
- `AccessLogEntry`: at, userId, userEmail, action (playback or export), target.
- `ParticipantRecord` (one per patient): interventionStart, infoSheetProvided, consentSignedOn, demographics (age, gender, education, occupation, voice-use level, primary language), clinical (diagnosis, symptom months, smoking, laryngoscopy date, therapy start, in-clinic sessions per week, other conditions), orientationOn, withdrawnOn, withdrawalReason. Patients from before records existed get an undocumented record starting on their account date.
- `AdherenceSelfReport`: week (0 = baseline), submittedAt, daysPractised (0 to 7 in the previous week), main barrier, note.
- `UsabilityResponse`: the ten SUS answers (1 to 5) and the derived 0 to 100 score. `SatisfactionResponse`: nine 1 to 5 ratings plus liked most, difficulties and suggestions.
- `MonitoringEntry`: week, therapist, practice, schedule and technique ratings (fully, mostly, partly, not at all), barriers, notes.
- `UsageEvent`: at, patientId, action, detail (an id or name, never typed text).
- `VoiceUseEntry`: day, loggedAt, speaking time band, vocal fatigue (0 to 10), situations that increased effort, note. One entry completes one session of a voice-diary exercise; undoing the session removes the entry.
- Reminder times: minutes after midnight per user, shown as `ReminderTime`.

Storage approach:

- **Hive Community Edition** (`hive_ce`), the maintained fork of Hive with the same API. Models are immutable classes with hand-written, typed `toMap`/`fromMap`. This is the project's chosen equivalent of freezed/json_serializable: maps exist only inside `data/` repositories at the Hive boundary and never reach controllers or widgets, and the build stays free of `build_runner`.
- **Encryption.** Every box is opened with `HiveAesCipher` (AES-256). The 32-byte key is generated on first launch with `Hive.generateSecureKey()` and kept only in `flutter_secure_storage` (Android Keystore, iOS Keychain).
- **Boxes.** `users` (profiles keyed by id), `credentials` (bcrypt hashes keyed by user id, kept apart from profile data so the domain `User` never carries a hash), `meta` (active session user id, seed version), `exercises`, `schedules` (every version), `completions`, `recordings` (metadata only), `reminders`, `access_log` (append-only, auto-increment keys), `participants` (study records keyed by patient id), `questionnaires` (self-reports, usability and feedback keyed by response id, tagged by type inside the repository), `monitoring`, `usage_log` (append-only, auto-increment keys), `voice_diary`. Study settings, including the number of people approached, live in `meta`.
- **Passwords.** bcrypt on a background isolate. Plaintext is never stored. Passwords over 72 bytes are rejected because bcrypt ignores the excess. Release and profile builds use cost 10. Debug builds use cost 6, because unoptimized debug Dart took about 14 seconds per cost-10 hash on an emulator. Each hash records its own cost, so accounts created by either kind of build still sign in.
- **Recordings.** Captured with the `record` package as WAV, 44.1 kHz, mono, with auto gain, echo cancellation and noise suppression off so the signal stays unprocessed for later analysis. Files live in `<application support>/recordings/`, which is app-private and never the gallery or media store. A take is captured to `draft.wav`; keeping it encrypts it to `<participant code>_<type>_<task>_t<trial>_<yyyyMMddTHHmmss>.wav.vpa` and deletes the draft, so the draft under review is the only plaintext audio. Takes stop by themselves after 3 minutes.
- **Audio encryption.** `RecordingVault` encrypts each file with AES-256-GCM (`cryptography` package, pure Dart, run on an isolate). Layout: magic `VPA1`, 12-byte random nonce, ciphertext, 16-byte tag; the magic is also the associated data. The key is separate from the Hive key and kept only in `flutter_secure_storage`. Playback decrypts to `<temp>/playback/` and the copy is deleted when another recording loads or playback is released; leftover copies are cleared at every launch. Installs from before encryption are migrated at launch (`encryptLegacyRecordings`), which is safe to rerun.
- **Probes.** Probe recordings follow the fixed protocol from research doc section 14 (`ProbeProtocol`): sustained /a/ x3, maximum /a/ x3, /s/ x2, /z/ x2, /a/ /i/ /u/, pitch glide x2, reading passage, 30 s spontaneous speech, 17 takes in all, each with a 0.5 s lead-in cue. The first probe is the baseline; later ones are follow-ups due every `probeIntervalDays` until `studyWeeks` ends, counted from the study record's intervention start. If a late probe would push the next one past the end, the post-intervention probe is due on the follow-up day instead, so it is never skipped. Softest and loudest /a/ are omitted because they need a calibrated microphone. Practice recordings are free-choice.
- **Exports.** CSV exports (demographic and clinical information with consent and status, outcome measures per participant with per-week columns, completions, assignment versions with dosage, targets and instructions, voice-use diary, recording metadata, self-reports, monitoring forms, usability item answers with SUS score, feedback with open comments, usage log) identify patients only by participant code, contain no audio or file paths, quote delimiters and defuse spreadsheet formulas. The admin picks the save location through the system save dialog; each saved export is logged.
- **Access log.** Every recording playback (saved recordings, not unsaved drafts) and every saved export appends an entry with user, time and target. The app offers no way to edit or delete entries.
- **Seeding.** `DemoSeeder` runs in numbered stages tracked by `seed.version` in `meta`, so an existing install picks up new stages without being wiped. Stage 1 writes the accounts. Stage 3 writes 17 demo voice samples: a baseline sustained phonation and baseline reading passage for everyone, plus later home practice and follow-up samples for the more engaged patients. Stage 2 writes 09:00 and 18:30 reminders for each patient. No exercises, assignments or completion history are seeded. Stage 5 writes study records (P005 still lacks orientation), baseline self-reports for everyone, week 1 self-reports and monitoring forms for some patients, a usage history derived from any completions, and P006, who started 29 days before seeding and has finished the intervention with every weekly report and form, so their follow-up questionnaires and post-intervention probe are due. Seeded ids are fixed, so an interrupted stage can safely re-run; usage events are only seeded into an empty log.
- Android sets `allowBackup="false"` so the encrypted boxes are not copied into device backups.

## Design decisions not covered by design.md

design.md describes the visual system: a peach and lilac wash fading into a grey page, white cards, charcoal text and actions, lime accents. These are the choices made to apply it:

- **Design tokens.** Every colour, gradient, text style, spacing value, radius and fixed size comes from `core/theme` (`AppColors`, `AppTypography`, `AppSpacing`, `AppRadius`, `AppSizes`, `AppMotion`). Spacing uses 4/8/16/24/32 only, with a 24px page gutter. Radii are 16 (`small`: compact surfaces, checkboxes), 28 (`base`: cards, inputs, sheets, dialogs) and `pill` for capsules.
- **Colours.** Page `#FFFBF4`, cards and inputs white, indigo ink `#34408F` for text and primary actions, sunshine `#FFC95C` for progress and selected accents (with teal, blossom and orchid from the Melo mark), error `#BB3049` for validation and destructive actions only. `AppColors.peach` marks cautions and placeholder text.
- **Gradients.** The engineering standards ban gradients unless requested; design.md requests them. `AppColors.pageGradient` (the page wash, painted once behind every route) and `AppColors.darkGradient` (circular icon badges and the dark home summary) are the only ones.
- **Buttons.** `PrimaryButton` is a charcoal capsule with paper text; `SecondaryButton` is a white capsule with a hairline border. Both are at least 56px tall and press with a slight scale. A page has one primary action.
- **Inputs.** `LabeledTextField`: label above the field (no floating labels), white fill, no border at rest, a 2px ink border when focused, error red when invalid. On a white sheet the fill switches to `washTint` so the field stays visible.
- **Type roles.** Nunito Sans, bundled at 400/500/600/700. Headings use regular or medium weight with tight tracking and sentence case: page titles 28px, H1 32px, H2 24px, card titles 18px. Body 16px, labels 14px, captions 12px. JetBrains Mono (`monoSmall`, `monoLarge`, `monoDisplay`, `participantCode`) is for codes, timers and other technical values.
- **Icons.** Lucide via `lucide_icons_flutter`. Feature icons sit in `SealMark`, a dark circular badge; the app's own mark is the smiling "o" of the Melo wordmark with three drops (`MeloMark`).
- **Touch targets.** Buttons, pills, day toggles and icon buttons are at least 48 by 48 (`AppSizes.minTouchTarget`).
- **Light mode only.** design.md marks dark mode as unsupported.
- **Page transitions.** A 200ms fade for every route, via `FadePageTransitionsBuilder`. Entry animations respect reduced motion.
- **Loading.** No circular spinners. Lists show skeleton blocks (`Skeleton`, `SkeletonList`) that pulse with a flat fill, and buttons change their label while working.
- **Navigation.** Every role area uses `RoleShell`: a white floating capsule. Inactive destinations show only their icon; the active one widens into a charcoal capsule with its label. Every label stays available through tooltips and semantics.
- **Choice pills.** Single- and multi-select options use `ChoicePills` and `MultiChoicePills`: charcoal with white text when selected, white otherwise.
- **Secondary text colour.** Secondary text uses `AppColors.muted` `#656669`, which passes WCAG AA on the page and on white. `AppColors.wash` is for borders, icons and other non-text marks, which only need 3:1.
- **Completion chart.** A single series, so it has no legend; the period label above names it. Columns are at most 24px wide with rounded tops, square bases and at least a 2px gap. The value appears only for the selected column. Tap or drag to select. Rest days show a baseline tick instead of a zero-height bar. A "Show as table" toggle gives the same numbers as text.
- **Asymmetric layouts.** Paired stat tiles use unequal flex (5:6 or 6:5) rather than equal columns.
- **Input level meter.** A row of 24 ticks, tallest in the middle, filling left to right with the live microphone level. Only height and colour change.
- **Reading passage.** The reading task uses a short passage written for this app rather than a published clinical passage, to avoid copyright questions. A study would likely swap in its standard passage.
- **Therapist navigation.** Three tabs: Overview, Participants, Voice samples. Sign out sits in the Overview app bar, since a whole profile tab would hold only that one action.
- **Low adherence flag.** A patient is flagged when they complete under the study's adherence threshold (admin setting, default 80%, per research doc 8.3) of prescribed sessions over the last 14 days. The flag is an icon with the words "Low adherence", never colour alone. The overview lists flagged patients lowest first and states the rule underneath.
- **Assignment editor.** Assigning is two steps. First the therapist ticks any number of exercises (approved, unassigned only, grouped by program); once one is ticked, a bar pinned to the bottom shows the count and Continue, so the long library never has to be scrolled to reach the action. The second step sets the days once for all of them (seven toggles, at least one always on), then sessions-per-day and repetitions steppers, targets matching each exercise's verification type, and instructions for each exercise. The pinned bar then holds Assign, and any problem to fix is shown in red in that bar instead of a snackbar, which would cover it. Inputs are also checked on the drafts themselves, because the lazily built list never validates fields that were not scrolled into view. Editing one current assignment keeps a single-exercise form with "End assignment" behind a confirmation. A note states that changes apply from today.
- **Status matrix.** Shown on each participant and as counts on the admin overview, using the research doc 8.3 rows plus "Awaiting probe analysis" for patients without a probe rating. With the analysis stub every patient is in that row; the matrix is wired for when `AnalysisService.probeOutcome` returns real ratings.
- **Admin navigation.** Four tabs: Overview (enrollment, overall adherence, status matrix, participants by code), People (patients and therapists, create, reassign), Library (status filter, editor with approve and archive), Settings (threshold, probe schedule, exports, access log, sign out).
- **Localization.** All user-facing strings of the main app, including notification text, live in `lib/l10n/app_en.arb` (English is the source; `flutter gen-l10n` generates into the git-ignored `lib/l10n/generated/`). Domain enums carry no display text; `core/utils/l10n.dart` maps them to strings. Noto Sans Devanagari and Noto Sans Gurmukhi are bundled (four weights each, subset to their scripts) and set as `fontFamilyFallback` on every text style. The setup flow has its own English, Hindi and Punjabi strings (see below).
- **Analysis state.** Each recording in therapist views carries an outlined chip with an hourglass icon and "Analysis pending".
- **Voice sample filters.** Participant, task and type are single-select pill rows, each with an "All" option, and a count of matching recordings. Opening samples from a participant pre-selects that participant.
- **Launch screen and app icon.** Android launch screens use the page colour `#FFFBF4`. The app icon is an adaptive icon: the page colour behind the `MeloMark` foreground, regenerated by `flutter test tool/generate_app_icons.dart`. The full wordmark with its tagline is `assets/branding/melo-logo.svg`. Android 7.0 and 7.1 have no adaptive icons and still show the default Flutter icon.
- **Step-by-step page layout.** Setup and connected pages use `ActionPage` (`shared/widgets/action_page.dart`): title and content on the page wash, actions in a white panel pinned to the bottom, so the next step stays within thumb reach however long the consent text is. Errors appear in red just above the actions. Placeholder study text is marked by a peach `PlaceholderNotice` so it cannot be mistaken for approved wording. Patients appear in the therapist's list by the first block of their id in mono; the review page shows the full id. Forms stay on the page wash rather than inside white cards, because white fields and pills would disappear in them.

## Known limitations and stubs

- Seeded voice samples are synthetic: a sustained vowel-like tone at a per-patient pitch, generated on first launch. They exist so playback and filters can be demonstrated. The reading passage and spontaneous speech samples are the same kind of tone, not speech.
- Voice analysis is a stub. Every recording shows "Analysis pending" and no acoustic measures are computed.
- Patients can only mark today's exercises. Past days cannot be back-filled.
- Exercise text comes from the clinical source document, but its default dosage and verification types are the app's placeholders, and three entries have no description yet. Each exercise shows a placeholder where a demonstration video would go.
- Decrypted copies exist in the app's temp directory while a recording is loaded for playback, and the take under review is plaintext until saved or discarded.
- Recording encryption uses pure-Dart AES-GCM, which is slower than a native implementation; long takes take a moment to save and to start playing.
- Reminders use inexact scheduling (`inexactAllowWhileIdle`) to avoid Android's exact-alarm permission, so they can arrive a few minutes late.
- There is no password reset or account lockout after repeated failures.
- Only Android and iOS are configured. Desktop and web are not targeted.
- The status matrix cannot yet place anyone in its main rows: it needs probe ratings, and voice analysis is a stub. Compliance is measured as the protocol defines it (frequency and schedule). The research doc's narrower measure, repetitions on target (8.2), is not, because exercise verification is not implemented.
- Take quality checks cover SNR, clipping, voiced length and phone movement. Phone angle and distance and device metadata from the protocol are not checked, and quality results are not stored with the recording.
- The movement and noise-type thresholds are provisional and need calibrating on real devices.
- Assignments created before versioning were migrated with their original start date and the default dosage of one session a day.
- Only English strings exist. Hindi and Punjabi need translated ARB files and validated translations of any clinical instruments, including the SUS.
- The SUS items read "app" for "system", the usual substitution. The satisfaction items, self-report questions, education text and demographic and clinical fields are this app's own wording and need the expert panel's review before the pilot.
- Acoustic voice measures for the pre/post comparison are not computed (voice analysis is a stub), so the in-app paired tests cover self-reported practice only.
- Open feedback answers and the occupation and diagnosis fields are free text. They are exported as written, so the research team must check them for identifying details.
- The access log is append-only within the app, but it is not tamper-evident: someone with root access to the device could alter the database.

