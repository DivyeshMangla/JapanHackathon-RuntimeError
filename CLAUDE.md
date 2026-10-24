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

A Flutter prototype for children's home therapy practice. Four roles share one app: the child (role `patient`: big picture buttons for saying a useful word and drawing, reached only through the parent's child mode), the parent (adds each child and signs consent once while doing so, follows each child, turns on child mode), the therapist (assigns and reviews) and the administrator (people and settings). Records live on the care service in `backend/` (Node, SQLite, see `backend/README.md`); only reminders, this phone's access log and an unsent word attempt stay on the device.

## Running the app

Requires Flutter 3.38 (stable) or newer, plus an Android device or emulator (API 24+) or an iOS device or simulator.

Start the care service first (Node 24 or newer), then run the app. There are no build flavors:

```bash
npm run demo
flutter pub get
flutter run
```

The app reaches the service at `http://10.0.2.2:8787` (the host machine from an Android emulator); the debug build allows that plain HTTP. Pass `--dart-define=API_BASE_URL=https://...` for another address; release builds require HTTPS. On a USB phone, `adb reverse tcp:8787 tcp:8787` with `API_BASE_URL=http://127.0.0.1:8787` works the same way.

Checks that must pass before work is considered done:

```bash
flutter analyze
flutter test
npm run test:backend
```

The first launch creates the device encryption key and opens the encrypted boxes.

If Android Studio is open on this project, do not also build from the terminal. Two Gradle builds in the same `build/` folder delete each other's files and fail with "file does not exist" errors. A full debug APK holds every CPU architecture (about 160 MB); `flutter run` or `flutter build apk --debug --split-per-abi` produces a single-architecture build of about 75 MB, which matters on emulators with little free storage.

### Accounts

Accounts come from the backend demo seed (`npm run demo`, see `backend/README.md`), all with the password `VoiceDemo!2026`: `admin@melo.test`, the therapist `meera@melo.test` (therapist code `MEERA7`) and the parent `parent@melo.test`. A child has no password: sign in as the parent and tap "Start child mode for Ananya"; leaving child mode asks for the parent's password. The seed includes signed consent for every child and a drawing plan for Ananya.

## Folder structure

```
lib/
  main.dart                 opens device storage, points the app at the care service, starts it
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

Features: `auth` (welcome page, sign-in, parent sign-up, child mode), `patient` (the child's area), `parent`, `therapist`, `admin`, `useful_words` (say a useful word), `motor` (drawing practice with photos and therapist review), `recordings`, `reminders`, `settings`, `study` (study period and status matrix only), `usage` (application usage log), `audit` (access log), `capture_quality` (signal analysis, noise removal, take quality, sensors; no screens), `diagnostics` (debug-only sensor check screen).

## Architecture decisions

- **Repository interfaces.** UI and controllers depend only on interfaces in `domain/` (for example `UserRepository`, `AuthRepository`). The `Backend*` classes in `data/` talk to the care service through `BackendClient` (`core/network`), and are wired up in Riverpod providers, so another implementation can be swapped in by changing one provider. Every transport or server problem becomes a `NetworkFailure`.
- **Riverpod without code generation.** Plain `Provider`, `NotifierProvider` and `AsyncNotifierProvider` keep the build free of `build_runner`.
- **Startup.** `main()` opens the device database, overrides `localDatabaseProvider` and `backendClientProvider` (address from `--dart-define=API_BASE_URL`, HTTPS required in release builds) in a `ProviderContainer`, then hands the container to `UncontrolledProviderScope`. The session token is kept in `flutter_secure_storage`, so a restart restores the session.
- **Routing.** `routerProvider` builds a single `GoRouter` whose `refreshListenable` follows `authControllerProvider`. `redirectFor` is a pure function (unit tested) that holds on the splash route while the session is restoring, lets signed-out users open only the public pages (`AppRoutes.public`: welcome, sign-in, parent sign-up, sensor check), and keeps each role inside its own route tree (`/patient`, `/parent`, `/therapist`, `/admin`).
- **Role areas.** Each role's routes live in its feature (`parent/presentation/parent_routes.dart`). Parent, therapist and admin areas are `StatefulShellRoute.indexedStack` tab shells, so every tab keeps its own navigation stack. The child's area has no tab bar: one home of picture buttons (`ChildTile`), each opening its own page. Every area is wrapped in `SignedInGate`, which renders nothing in the frames between sign-out and the redirect, so screens can read `currentUserProvider` without null checks.
- **Family accounts and child mode.** Therapists get a six-character `link_code` (no 0/O or 1/I/L). A parent signs up with their therapist's code (`POST /auth/register`) and lands on that caseload. The parent adds each child (`POST /children`, `AddChildScreen`), which creates the child on the parent's caseload together with the signed consent. Child mode (`StartChildModeButton`, `POST /patients/:id/child-mode`) ends the parent's session and signs the device in as the child, so the existing child area and the service's patient-only rules apply unchanged. Leaving (`LeaveChildModeDialog`, `POST /auth/end-child-mode`) needs the parent's password, checked by the service (five tries per 15 minutes), and returns a fresh parent session. A child never types an email or password, and there is no separate child sign-in. `familyChildProvider` returns null for a child who is not the parent's own, and the service lets a parent read only their own children.
- **One consent, taken once.** Consent is signed only while adding a child; the account and the approved consent are created in one transaction, and no screen asks for it again. Consent never expires: the service records which version was signed but accepts any approved consent, so a new consent version applies only to children added after it. The child's detail page only reports it. It covers practice, word attempts and drawing photos.
- **One audio player.** `playbackProvider` owns a single `just_audio` player, so starting one recording stops any other. The recording flow releases it before moving or deleting a file.
- **Reminders follow the session.** `reminderSyncProvider`, watched at the app root, schedules a child's or parent's daily practice reminders when they sign in and cancels all reminders on sign-out, so a shared device never shows another person's reminders. Parents set the times in Settings.
- **Caseload access is checked, not just hidden.** `caseloadProvider` loads only the signed-in therapist's patients. Participant screens look patients up through `caseloadParticipantProvider`, which returns null for anyone not on that caseload, so typing another patient's id into a URL shows "Participant not found".
- **Analysis seam.** `AnalysisService` (`recordings/domain/analysis_service.dart`) is the only thing the UI knows about voice analysis. `analysisServiceProvider` supplies `StubAnalysisService`, which does no signal processing and reports every recording as pending. A real analyser replaces that one provider.
- **Take quality check.** `assessTake` (`capture_quality/domain`) measures SNR (mean voiced level over the quietest tenth of blocks, after an 80 Hz high-pass), clipping and voiced length. Thresholds follow research doc 4.3: SNR 42 dB or more is good, under 30 dB is poor, clipping must stay under 0.1%; more than 25% of the take spent moving is poor (provisional). It now drives the sensor check screen only, since the adult probe-recording screen was removed.
- **Noise removal is display only.** `SpectralDenoiser` is a log-MMSE (Ephraim and Malah) estimator with a decision-directed a priori SNR. It learns the noise spectrum only from blocks the level detector marks as background, so a long held vowel is never learned as noise. It drives the sensor check screen only. Saved recordings are never processed, because noise reduction changes jitter, shimmer, HNR and CPP. `NoiseProfiler` classifies the background (rumble, 50/60 Hz mains hum, tonal whine, broadband, fluctuating, clicks) from a 4096-point spectrum of background-only audio; its thresholds are provisional heuristics.
- **Sensor check screen.** `/sensor-check` is reachable from the login screen in debug and profile builds only (`!kReleaseMode`) and is allowed while signed out. It uses its own oscilloscope palette (`DiagnosticColors`, `AppTheme.diagnostics`), kept apart from the design.md tokens. The microphone streams PCM to memory only. `sensors_plus` (gyroscope and accelerometer, also used by the take check) and `proximity_sensor` were added for it.
- **Typed failures.** `core/errors/app_failure.dart` defines a sealed `AppFailure` hierarchy (`StorageFailure`, `RecordingFailure`, `PlaybackFailure`, `ReminderFailure`, `ExportFailure`, `InvalidInputFailure`, `SensorFailure`, `MediaFailure` for picked photos and sound files, `NetworkFailure`). Every repository method and platform service (vault, recorder, reminder scheduler, export) runs inside `guard`/`guardStorage`, which logs the underlying error and rethrows it as a typed failure. Screens never see raw exceptions: write actions go through `runWithFailureMessage` (a snackbar with a localized message), `AsyncView` names the failure on load errors, and the recording session reports failures through its state. Reminder sync and startup migration log failures instead of blocking sign-in or launch.
- **Logging.** `AppLogger` (`core/logging`) is the only logging entry point and writes to the platform log via `dart:developer`. It never sends anything off the device. Callers log failure types and technical details, never patient names, emails or audio. `print` is banned by lint.
- **Words and drawing.** `useful_words` and `motor` talk to the care service through `BackendClient`. `WordRepository` takes its transport and draft store as functions so tests can fake them; `wordRepositoryProvider` adapts the client and the encrypted `word_drafts` box. Drawing tasks come from the service's motor catalogue; a therapist picks them on the child's Drawing page, which saves them as the child's plan (`POST /patients/:id/plans`). `MotorPhotoPicker` scales each picked photo to at most 1280 px and re-encodes it as PNG before upload, because camera JPEGs often carry trailing data (motion photos, maker trailers) that the service's image check rejects, and the re-encode also drops location metadata. A sent word and a sent drawing show `showCelebration`, which respects reduced motion.
- **Usage logging never blocks.** `UsageLogger` records patient actions only (sign-in and sign-out, which child mode logs on entry and exit, recordings saved, reminder changes; older logs may also hold exercise and session events from the removed activities). A failed write is logged and the patient's action still succeeds.
- **Failed sign-in does not touch auth state.** `AuthController.signIn` returns `false` and leaves state unchanged, so the router does not react to a bad password.

## Data model and storage

- `User`: id, role (patient, parent, therapist, admin), name, email (empty for children), createdAt, participantCode (children only, e.g. P001), therapistId (children and parents), parentId (children only), parentName (where the service lists a child with their parent), linkCode (therapists and parents).
- `Recording`: id, patientId, kind (practice or probe), task, type (baseline, follow-up, home practice), trial, probeSessionId, filePath (encrypted file), durationSec, createdAt, analysisStatus (always `pending`).
- `StudySettings`: probeIntervalDays (default 7), studyWeeks (default 4).
- `AccessLogEntry`: at, userId, userEmail, action (playback or export), target.
- `UsageEvent`: at, patientId, action, detail (an id or name, never typed text).
- Reminder times: minutes after midnight per user, shown as `ReminderTime`.

Storage approach:

- **Where data lives.** Users, consent, the usage log, study settings and voice samples are stored by the care service (`backend/src/care-routes.mjs`, tables in `backend/migrations/003_care.sql`, which also drops the tables of the removed exercise activities). Bodies are stored as the app's own models send them, and the server checks who may write them: only an administrator edits settings, only the patient (the device in child mode) writes usage events and recordings. Patients get sequential participant codes (P001) from the server.
- **Device storage.** Hive Community Edition (`hive_ce`) holds reminder times and this phone's access log, every box opened with `HiveAesCipher` (AES-256) with a 32-byte key kept only in `flutter_secure_storage`. Models are immutable classes with hand-written, typed `toMap`/`fromMap`; maps exist only at the data boundary (Hive and the JSON in `Backend*` repositories) and never reach controllers or widgets.
- **Passwords.** The care service hashes passwords with salted scrypt. Passwords are 10 to 128 characters without leading or trailing spaces. Disabling an account or changing a password ends its sessions.
- **Recordings.** Captured with the `record` package as WAV, 44.1 kHz, mono, with auto gain, echo cancellation and noise suppression off so the signal stays unprocessed for later analysis. A take is captured to `draft.wav` in app-private storage; keeping it uploads the WAV to the care service and deletes the draft, so the draft under review is the only recording file the phone holds. Takes stop by themselves after 3 minutes. A failed upload returns to review so the take is not lost. Playback fetches the audio, writes a temporary copy that is deleted when another recording loads or playback is released, and clears leftovers at every launch. Each play is audited by the server.
- **Probes.** Probe recordings follow the fixed protocol from research doc section 14 (`ProbeProtocol`): sustained /a/ x3, maximum /a/ x3, /s/ x2, /z/ x2, /a/ /i/ /u/, pitch glide x2, reading passage, 30 s spontaneous speech, 17 takes in all, each with a 0.5 s lead-in cue. The first probe is the baseline; later ones are follow-ups due every `probeIntervalDays` until `studyWeeks` ends, counted from the study record's intervention start. If a late probe would push the next one past the end, the post-intervention probe is due on the follow-up day instead, so it is never skipped. Softest and loudest /a/ are omitted because they need a calibrated microphone. Practice recordings are free-choice.
- **Exports.** CSV exports (recording metadata, usage log) identify patients only by participant code, contain no audio or file paths, quote delimiters and defuse spreadsheet formulas. The admin picks the save location through the system save dialog; each saved export is logged.
- **Access log.** Kept on this phone only; the care service keeps its own audit trail (the admin dashboard lists it). Every recording playback (saved recordings, not unsaved drafts) and every saved export appends an entry with user, time and target. The app offers no way to edit or delete entries.
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
- **Asymmetric layouts.** Paired stat tiles use unequal flex (5:6 or 6:5) rather than equal columns.
- **Input level meter.** A row of 24 ticks, tallest in the middle, filling left to right with the live microphone level. Only height and colour change.
- **Reading passage.** The reading task uses a short passage written for this app rather than a published clinical passage, to avoid copyright questions. A study would likely swap in its standard passage.
- **Therapist navigation.** Three tabs: Overview (with the therapist code for parents, caseload and voice sample counts), Participants, Voice samples. Each participant links to their words, drawing and usage log. Sign out sits in the Overview app bar, since a whole profile tab would hold only that one action.
- **Parent navigation.** Two tabs: Family (each child with Start child mode, and Add a child; a child's detail page has child mode as its primary action, the consent on file and drawing feedback) and Settings (therapist, practice reminders, sign out).
- **Admin navigation.** Three tabs: Overview (enrollment, voice samples, participants by code), People (children, parents and therapists; add parents and therapists, reassign a child's therapist; children are added by their parent), Settings (probe schedule, exports, access log, sign out).
- **Localization.** All user-facing strings of the main app, including notification text, live in `lib/l10n/app_en.arb` (English is the source; `flutter gen-l10n` generates into the git-ignored `lib/l10n/generated/`). Domain enums carry no display text; `core/utils/l10n.dart` maps them to strings. Noto Sans Devanagari and Noto Sans Gurmukhi are bundled (four weights each, subset to their scripts) and set as `fontFamilyFallback` on every text style.
- **Analysis state.** Each recording in therapist views carries an outlined chip with an hourglass icon and "Analysis pending".
- **Voice sample filters.** Participant, task and type are single-select pill rows, each with an "All" option, and a count of matching recordings. Opening samples from a participant pre-selects that participant.
- **Launch screen and app icon.** Android launch screens use the page colour `#FFFBF4`. The app icon is an adaptive icon: the page colour behind the `MeloMark` foreground, regenerated by `flutter test tool/generate_app_icons.dart`. The full wordmark with its tagline is `assets/branding/melo-logo.svg`. Android 7.0 and 7.1 have no adaptive icons and still show the default Flutter icon.
- **Step-by-step page layout.** Sign-up, adding a child, words and drawing pages use `ActionPage` (`shared/widgets/action_page.dart`): title and content on the page wash, actions in a white panel pinned to the bottom, so the next step stays within thumb reach however long the consent text is. Errors appear in red just above the actions. Placeholder study text is marked by a peach `PlaceholderNotice` so it cannot be mistaken for approved wording. Forms stay on the page wash rather than inside white cards, because white fields and pills would disappear in them.

## Known limitations and stubs

- Voice analysis is a stub. Every recording shows "Analysis pending" and no acoustic measures are computed.
- Child mode ends the parent's session on that phone, so a parent who forgets their password can only leave by reinstalling or clearing the app's data, and there is no password reset yet.
- A temporary plaintext copy exists in the app's temp directory while a recording is loaded for playback, and the take under review is plaintext until saved or discarded. The care service stores audio and records unencrypted at the application level; use an encrypted server volume.
- Reminders use inexact scheduling (`inexactAllowWhileIdle`) to avoid Android's exact-alarm permission, so they can arrive a few minutes late.
- There is no password reset or email verification, and the app needs a network connection to the care service: sending a word, a drawing or signing in fails with a clear message when offline, and nothing is queued.
- Only Android and iOS are configured. Desktop and web are not targeted.
- Take quality checks cover SNR, clipping, voiced length and phone movement. Phone angle and distance and device metadata from the protocol are not checked, and quality results are not stored with the recording.
- The movement and noise-type thresholds are provisional and need calibrating on real devices.
- Only English strings exist. Hindi and Punjabi need translated ARB files and validated translations of any clinical instruments, including the SUS.
- The access log is append-only within the app, but it is not tamper-evident: someone with root access to the device could alter the database.

