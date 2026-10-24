# Melo: UI reference

A screen-by-screen description of the app as it stands, written as context for
UI work. Read this together with `design.md` (visual language), `CLAUDE.md`
(engineering rules and design decisions) and `lib/l10n/app_en.arb` (all copy).

Every screen lives under `lib/features/<feature>/presentation/`. Strings are
referenced by their ARB key (`l10n.someKey`); the English text is in
`app_en.arb`.

---

## 1. What has been built so far

| Commit | What it added |
| --- | --- |
| `e4e968f` | Flutter scaffold, platform config, bundled fonts |
| `94cc380` | `design.md`, research notes, engineering standards |
| `5c04f6b` | The prototype: patient, therapist and admin flows |
| `7b1af64` | Feature-first `data/domain/presentation` structure |
| `4f18aa7` | Design tokens applied everywhere, all strings localized, large widgets split |
| `79fd83f` | Typed failures (`AppFailure`), `AppLogger`, user-facing error messages |
| `2ec6607` | Step 4 admin features (library approval, versioned assignments, exports, access log), audio encryption |
| uncommitted | `capture_quality` (take quality check: SNR, clipping, voiced length, phone movement), `diagnostics` (developer sensor check screen), take quality card on the Record screen |

### Capabilities by role

**Patient**: sees today's prescribed exercises and ticks off each session;
reads exercise steps and targets; records practice samples or the 17-take probe
protocol (baseline, then follow-ups every 7 or 14 days) with a live level meter,
review playback and an automatic quality check; sees 14-day adherence, streak,
a daily/weekly completion chart and their saved recordings; manages daily
reminder times; reads the Learn topics (app guide, home practice, voice care,
study summary); fills in the baseline and weekly practice self-reports and, at
the end of the intervention, the usability (SUS) and feedback questionnaires,
which appear on Home when due; signs out.

**Therapist**: sees a caseload overview with low-adherence flags; searches
participants; opens a participant to see status, adherence, probe schedule and
assignments; assigns exercises or edits dosage/targets/days (versioned from
today) or ends an assignment; views a participant's adherence over time; lists
and plays caseload voice samples with filters; keeps each participant's study
record (consent, intervention start, orientation, demographic and clinical
form, withdrawal); reviews baseline and follow-up checklists and, per study
week, the app log, practice recordings, self-report and their own monitoring
form; reads the participant's usage log.

**Research admin**: sees enrollment, overall adherence, the status matrix and
every participant; creates patients and therapists and reassigns patients;
manages the exercise library (create, edit, approve, archive, restore); sets the
adherence threshold, probe interval, study length and the number of people
approached; records consent when enrolling a patient; sees study outcomes
(adherence and compliance with mean, SD and median, recruitment, retention,
app usage completion, SUS, satisfaction, and paired t-test and Wilcoxon results
for self-reported practice); exports CSVs for every data collection
instrument; reads the access log.

**Developer (debug/profile builds only)**: a sensor check screen with live
waveform, levels, spectrum, noise classification, SNR, motion, orientation and
proximity.

### Not built (relevant to UI)

- No password reset, profile editing, or account lockout.
- No real voice analysis: every recording shows "Analysis pending"; the status
  matrix main rows are always empty.
- Exercise demonstration videos are a placeholder card.
- Patients cannot back-fill past days.
- No dark mode (design.md marks it unsupported). No tablet-specific layouts
  beyond the 1280px content cap.
- English only (Hindi/Punjabi fonts are bundled as fallbacks, no translations).

---

## 2. Design system in code

All values come from `lib/core/theme/`. Never hardcode a colour, size or text
style in a widget.

### Colours (`AppColors`)

| Token | Value | Use |
| --- | --- | --- |
| `paper` | `#F4F1E8` | Scaffold and card background |
| `ink` | `#0D0D0D` | All dark text and marks (never pure black) |
| `seal` | `#8A1C15` | Accent: primary buttons, eyebrows, active tab, icons in stat tiles, flags |
| `sealDeep` | `#7F1A13` | Pressed/hover primary |
| `sealTint` | seal 8% | Selected pill fill, nav indicator |
| `sealSelection` | seal 20% | Text selection |
| `wash` | `#808080` | Borders of inputs/ghost buttons, inactive icons, chevrons |
| `muted` | `#67645E` | Secondary text (AA contrast) |
| `hairline` | wash 35% | Card borders, dividers, unselected radio circles |
| `washTint` | wash 12% | Skeletons, tracks, hover fill |
| `error` | `#B42318` | Validation errors, poor-take icon |
| `shadow` | ink 6% | Card shadow (0, 2, blur 12) |

`DiagnosticColors` (dark oscilloscope green/cyan/amber) is used **only** by the
sensor check screen via `AppTheme.diagnostics`.

### Spacing, radius, sizes, motion (`app_tokens.dart`)

- `AppSpacing`: `xs 4`, `sm 8`, `md 16`, `lg 24`, `xl 32`; `gutter = 24`;
  `maxContentWidth = 1280`.
- `AppRadius`: `small 4`, `base 8`. Circles via `BoxShape.circle`.
- `AppSizes`: `minTouchTarget 48`, `progressThin 4`, `progressThick 6`,
  `valueColumn 56`, `counterColumn 32`.
- `AppMotion`: `fast 200ms`, `standard 300ms`, `entry 420ms`, `stagger 80ms`,
  ease-out, entry offset 16px. Routes fade in 200ms. No ink ripples.

### Typography (`AppTypography`, Noto Serif JP + JetBrains Mono)

| Theme role | Token | Size / weight |
| --- | --- | --- |
| `displayLarge` | `hero` | 40 / 700 |
| `headlineLarge` | `h1` | 36 / 700 |
| `headlineMedium` | `h2` | 24 / 700 |
| `headlineSmall`, `titleLarge` (app bars) | `h3` | 20 / 600 |
| `titleMedium` | body | 16 / 600 |
| `titleSmall` | label | 14 / 600 |
| `bodyLarge`, `bodyMedium` | `body` | 16 / 400, line height 1.6 |
| `bodySmall` | label | 14 / 400, `muted` |
| `labelLarge` (buttons) | `button` | 16 / 600 |
| `labelMedium` | `label` | 14 / 500 |
| mono | `mono` 14, `monoSmall` 12, `monoMicro` 10, `monoLarge` 16/500, `monoHeadline` 24/500, `monoDisplay` 44/500, `participantCode` 12/500 |

Mono is used for technical values: timers, durations, participant codes,
reminder times, step numbers, dosage lines, counters.

### Shared widgets (`lib/shared/widgets/`)

| Widget | What it is |
| --- | --- |
| `PageList` | Scrolling `ListView` with 24px gutters, 16 top / 32 bottom, capped at 1280px. Body of almost every screen. |
| `AsyncView` | Renders `AsyncValue`: `SkeletonList` while loading, `EmptyState` with a typed failure message on error. |
| `InkCard` | Paper card, 8px radius, hairline border, soft shadow, 16px padding, optional `onTap`. |
| `StatTile` | `InkCard` with seal icon + label, `headlineMedium` value, optional caption. Used in pairs with unequal flex (5:6, 4:7, 6:5). |
| `PrimaryButton` / `SecondaryButton` | Seal-filled / outlined, optional icon, 1px press-down. Full width when in a stretched column. |
| `ChoicePills<T>` | Wrapping single-select outlined pills, 48px tall, seal border + tint when selected. |
| `SectionLabel` | Uppercase `labelMedium` with 1.2 letter spacing, 8px below. |
| `EmptyState` | 40px wash icon, `headlineSmall` title, muted message, optional secondary action. |
| `LabeledTextField` | Label above field (no floating labels), optional prefix icon, suffix, validator. |
| `NumberField` | `LabeledTextField` for positive decimals or whole numbers >= 1 with inline validation. |
| `SealMark` | Rotated red hanko seal with an icon. App mark and "done" stamp. |
| `BrushStroke` | Tapered ink stroke under headings. |
| `InkWashHills` | Layered mountain silhouettes (the only gradient in the app). |
| `PaperGrain` | Static grain overlay over the whole app. |
| `EntryCascade` | Children fade in and rise 16px, staggered 80ms. |
| `Skeleton` / `SkeletonList` | Flat pulsing placeholders (no spinners). |
| `runWithFailureMessage` | Runs a write action; shows a localized snackbar on `AppFailure`. |

Feature-level reusable widgets: `AdherencePanel` + `CompletionChart`
(`exercises/presentation`), `WeekdayPicker`, `RecordingTile`,
`PlaybackButton`, `AnalysisChip`, `TakeQualityCard`
(`recordings/presentation`), `ParticipantCard`, `LowAdherenceFlag`,
`StatusCard`, `ParticipantNotFound` (`therapist/presentation`),
`ExerciseStatusChip` (`admin/presentation`), `ExerciseChecklistTile`,
`ExerciseMeta` (`patient/presentation/today_exercises_screen.dart`).

### Shell and navigation

- `RoleShell` (`core/routing/role_shell.dart`): `Scaffold` with a Material 3
  `NavigationBar` and a hairline top border. Tapping the active tab returns it
  to its root. Each role is a `StatefulShellRoute.indexedStack`, so tabs keep
  their own stacks.
- `SignedInGate` renders nothing during the frames between sign-out and the
  redirect.
- `redirectFor` confines each role to `/patient`, `/therapist` or `/admin`;
  signed-out users go to `/login` (or `/sensor-check`).

---

## 3. Route map

```
/                         SplashScreen
/login                    LoginScreen
/sensor-check             SensorCheckScreen (debug/profile only)

/patient                  [Home]      PatientHomeScreen
  /learn                              LearnScreen
  /learn/:topic                       LearnTopicScreen
  /questionnaires/self-report/:week   SelfReportScreen (week 0 = baseline)
  /questionnaires/usability           UsabilityScreen (SUS)
  /questionnaires/feedback            FeedbackScreen
/patient/exercises        [Exercises] TodayExercisesScreen
/patient/exercises/:id                ExerciseDetailScreen
/patient/exercises/:id/diary          VoiceDiaryScreen (voice-use monitoring)
/patient/record           [Record]    RecordScreen
/patient/progress         [Progress]  ProgressScreen
/patient/profile          [Profile]   PatientProfileScreen

/therapist                [Overview]       TherapistDashboardScreen
/therapist/participants   [Participants]   ParticipantsScreen
  /:patientId                              ParticipantDetailScreen
  /:patientId/assign?schedule=             AssignmentEditorScreen
  /:patientId/adherence                    ParticipantAdherenceScreen
  /:patientId/record                       StudyRecordScreen
  /:patientId/assessment                   AssessmentScreen
  /:patientId/assessment/monitoring?week=  MonitoringFormScreen
  /:patientId/usage                        UsageLogScreen
/therapist/recordings?patient= [Voice samples] VoiceSamplesScreen

/admin                    [Overview] StudyOverviewScreen
  /outcomes                          StudyOutcomesScreen
/admin/people             [People]   PeopleScreen
  /new?role=                         UserFormScreen
/admin/library            [Library]  ExerciseLibraryScreen
  /:exerciseId | /new                ExerciseEditorScreen
/admin/settings           [Settings] StudySettingsScreen
  /access-log                        AccessLogScreen
```

Bottom-tab icons (Lucide): patient `house`, `listChecks`, `mic`,
`chartColumn`, `circleUser`; therapist `layoutDashboard`, `users`,
`audioLines`; admin `layoutDashboard`, `users`, `libraryBig`, `settings`.

---

## 4. Screens

Each entry gives the file, what the screen is for, its layout top to bottom,
its states, interactions, and the providers it reads.

### 4.1 Splash and sign-in

#### SplashScreen
`features/auth/presentation/splash_screen.dart`

Shown while the saved session restores. A centred 72px `SealMark` on paper.
No text.

#### LoginScreen
`features/auth/presentation/login_screen.dart`

- **Background**: `InkWashHills` (200px) pinned to the bottom; hidden while the
  keyboard is open.
- **Content** (centred, scrollable, max width 440, `EntryCascade`):
  1. `_LoginHeader`: `SealMark` aligned right; app title "Melo" split
     on two lines in `displayLarge`; `BrushStroke` 104px; tagline
     (`loginTagline`) in `bodyLarge` muted.
  2. `_LoginForm`: email field (mail icon), password field (lock icon,
     eye/eye-off toggle with tooltip), `PrimaryButton` "Sign in" (log-in icon),
     and in non-release builds a `TextButton` "Sensor check (debug)" (activity icon).
- **States**: empty fields show `loginMissingFields` under the password field;
  submitting disables fields and changes the button label to "Signing in" (`loginSubmitting`);
  wrong credentials show `loginFailed`; storage failures show the typed failure
  message. All errors render as the password field's `errorText`.
- **Providers**: `authControllerProvider`.

### 4.2 Patient

#### PatientHomeScreen (Home tab)
`features/patient/presentation/patient_home_screen.dart`

No app bar. `SafeArea` + `PageList` + `EntryCascade`:

1. `_HomeGreeting`: long date uppercase in seal `labelMedium`; greeting with
   first name (`greeting`, time-of-day aware) in `headlineLarge`; `BrushStroke`
   88px.
2. `_ProbeDueCard` (only when a probe is due today): audio-lines icon, "Baseline
   voice check due" or "Voice check due", body copy, `SecondaryButton` "Start voice check" that
   goes to Record.
3. `_TodayCard`: label "Today's sessions"; big `done` in `displayLarge` + "of N" in muted
   `headlineSmall`; seal check `SealMark` when finished; 6px progress bar;
   message (nothing today / all done / N left); `PrimaryButton` "Start exercises" or
   "Continue exercises" to Exercises when work remains.
4. `_StreakAndReminder`: two `StatTile`s, flex 5:6. Streak (flame) with
   "days" caption; Next reminder (bell, or bell-off "None") showing the
   clock time and "Today"/"Tomorrow". Reminder tile opens Profile.
5. `_RecordShortcut`: tappable card with a mic `SealMark`, "Record a voice
   sample" + subtitle, chevron. Opens Record.

States: skeletons while `patientActivityProvider` loads, error state via
`AsyncView`. Providers: `currentUserProvider`, `patientActivityProvider`,
`probeDueProvider`, `reminderTimesProvider`.

#### TodayExercisesScreen (Exercises tab)
`features/patient/presentation/today_exercises_screen.dart`

- App bar: "Today's exercises" (`exercisesTitle`).
- Summary line (`bodySmall`): date and "done of due sessions".
- One `ExerciseChecklistTile` per exercise due today (`EntryCascade`):
  title (`titleMedium`, struck through and muted when all sessions done);
  `ExerciseMeta` mono line "5 min · 10 reps · twice a day"; one `Checkbox` per
  prescribed session (only the next box can be ticked and only the last ticked
  box can be cleared); chevron. Tapping the card opens the detail screen.
- **Empty**: `EmptyState` calendar-check, "Nothing scheduled today", action "See
  your progress".
- Writes go through `completionActionsProvider` with `runWithFailureMessage`.

#### ExerciseDetailScreen
`features/patient/presentation/exercise_detail_screen.dart`

- App bar with back button only (no title).
- `_Header`: program uppercase seal eyebrow; title `headlineLarge`;
  `ExerciseMeta`; summary `bodyLarge`.
- `_MediaPlaceholder`: 16:9 card with ink-wash hills, play-circle icon,
  "Demonstration video" / "Not included in this prototype".
- "TARGETS" section (only if the assignment has targets): card with a seal
  target icon per line (duration, pitch, tolerance, range).
- "STEPS" section: numbered steps, number in seal mono `01`, text `bodyLarge`.
- If due today: "N of M sessions done today"; `PrimaryButton` "Mark session
  done" (until complete); `SecondaryButton` "Undo last session" (when >= 1).
- **Not found** (exercise not currently assigned): `EmptyState` file-question.

#### RecordScreen (Record tab)
`features/patient/presentation/record_screen.dart`, state in
`recordings/presentation/controllers/recording_session.dart`.

A single screen driven by `RecordingStage`. App bar title is "Voice recording", or
"Baseline voice check" / "Voice check" during a probe. Failures and microphone
denial surface as snackbars.

- **setup**
  - `_ProbeCard`: audio-lines `SealMark` 40, "Baseline voice check" or "Voice
    check", status ("Due now" / next due date / "All voice checks for the study are done."), body
    ("17 short recordings..."), `PrimaryButton` "Start voice check".
  - "PRACTICE RECORDING" section with body copy; three `_TaskOption` cards
    (sustained phonation, reading passage, spontaneous speech), each with icon,
    label, instructions and a radio-style circle; seal when selected.
  - `SecondaryButton` "Start recording"; recording tip in `bodySmall`.
- **ready** (probe only, before each take): `_ProbeHeading` ("TAKE 3 OF 17" seal
  eyebrow, 4px progress bar, task name `headlineMedium`, "Trial 2 of 3",
  instructions, reading passage card when relevant); `PrimaryButton` "Record this take";
  `TextButton` "Finish later"; tip.
- **recording**: probe heading or task eyebrow + instructions; dot (grey during
  the 0.5s lead-in, seal after) next to the timer in `monoDisplay`; "Wait" /
  "Go" label; `_LevelMeter` (24 ink ticks, tallest in the middle, fill left to
  right); `PrimaryButton` "Stop"; "Stops automatically after 3 minutes".
- **review / saving**: probe heading (probe only); "Listen back"
  `headlineSmall` + body; card with task, type and `PlaybackButton` for the
  draft; `TakeQualityCard` ("Checking the recording" then good / acceptable /
  poor with issues and SNR in mono). Buttons: normally `PrimaryButton` "Save recording"
  (or "Save and continue" in a probe) then `SecondaryButton` "Record again"; if
  the take is poor the order flips and save becomes "Keep anyway". `TextButton`
  "Discard" (or "Finish later" in a probe). All disabled while saving; save
  label becomes "Saving". Practice save shows a "Recording saved" snackbar.
- **probeComplete**: check `SealMark` 64, "Voice check complete" + body,
  `PrimaryButton` "Done".

#### ProgressScreen (Progress tab)
`features/patient/presentation/progress_screen.dart`

- App bar "Progress".
- `StatTile` pair, flex 6:5: "Last 14 days" rate with caption, and "Streak"
  days.
- `AdherencePanel`: Daily/Weekly `ChoicePills`; `CompletionChart` in a card
  (14 daily or 8 weekly columns, tap/drag to select, selected value shown above,
  rest days as a grey tick); "Show as table" toggle revealing a table card
  (period, done/due or "Rest day", percent).
- "RECORDINGS" section: `RecordingTile` list (task, kind · type · date-time,
  `PlaybackButton`). **Empty**: mic-off `EmptyState` with "Make a recording".
- Providers: `patientActivityProvider`, `patientRecordingsProvider`.

#### PatientProfileScreen (Profile tab)
`features/patient/presentation/patient_profile_screen.dart`

- App bar "Profile".
- `_Identity`: name `headlineMedium`, email `bodySmall`, "Participant code" in
  mono, "Therapist" name; user `SealMark` 48 on the right.
- "REMINDERS" section: "No reminders set" when empty; one card per time (seal
  bell, time in `monoLarge`, remove `IconButton` x with tooltip);
  `SecondaryButton` "Add reminder time" opens the Material time picker, then asks
  for notification permission (snackbar if denied).
- `SecondaryButton` "Sign out".

### 4.3 Therapist

#### TherapistDashboardScreen (Overview tab)
`features/therapist/presentation/therapist_dashboard_screen.dart`

- App bar with only `SignOutButton` in actions.
- `_Greeting` (same pattern as patient home).
- `_CaseloadStats`, flex 4:7: "Caseload" count (opens Participants) and
  "Caseload adherence" over the 14-day window.
- "NEEDS ATTENTION": `ParticipantCard`s for flagged patients, lowest rate
  first, or an "everyone on track" card with a check seal; then the flag rule
  text (`flagRule`) in `bodySmall`.
- "LATEST RECORDINGS": up to 3 `RecordingTile`s with participant code and
  `AnalysisChip`; "No recordings yet" when empty; `TextButton` "All voice
  samples".
- Providers: `caseloadProvider`, `studySettingsProvider`,
  `caseloadRecordingsProvider`.

#### ParticipantsScreen (Participants tab)
`features/therapist/presentation/participants_screen.dart`

- App bar "Participants".
- Search `LabeledTextField` (name or code, search icon).
- `ParticipantCard` list: code in mono, name `titleMedium`, "Last active ...";
  right-aligned rate `headlineSmall` + "14 days"; 4px progress bar;
  `LowAdherenceFlag` (flag icon + "Low adherence" in seal caption) when flagged.
- **Empty caseload** and **no search matches** each have an `EmptyState`.

#### ParticipantDetailScreen
`features/therapist/presentation/participant_detail_screen.dart`

- App bar with back only.
- `_ProfileHeader`: code mono, name `headlineLarge`, email, "Enrolled on ...",
  flag if low.
- `StatusCard`: compass icon, "Status", status label, suggested action.
- `_ParticipantStats`, flex 7:4: 14-day rate with last-active caption (opens
  adherence screen); "Voice samples" count with next probe date or "Probes
  complete" (opens Voice samples filtered to this patient).
- `SecondaryButton` "Adherence over time".
- "ASSIGNED EXERCISES": `_AssignmentRow` cards (title, "Mon-Fri · 2 a day · 10
  reps", pencil icon) that open the editor; "No exercises assigned yet." when empty;
  `SecondaryButton` "Assign exercise".
- **Not on caseload**: `ParticipantNotFound` (user-x, "Back to participants").

#### ParticipantAdherenceScreen
`features/therapist/presentation/participant_adherence_screen.dart`

- App bar "Adherence".
- Code + name `headlineMedium`.
- `StatTile` pair, flex 6:5: 14-day and 7-day rates.
- `AdherencePanel` (same as patient Progress).
- `StatusCard`.
- "BY EXERCISE, LAST 14 DAYS": per exercise card with title, "days · done of
  due", rate, 4px bar.

#### AssignmentEditorScreen
`features/therapist/presentation/assignment_editor_screen.dart`

- App bar "Assign exercise" or "Edit assignment".
- Participant code in mono.
- New: "EXERCISE" picker, one card per approved, not-yet-assigned exercise
  (title, program, radio circle; seal when selected), or a note that every approved
  exercise is already assigned. Edit: exercise title `headlineMedium`.
- After an exercise is chosen:
  - "DAYS": `WeekdayPicker`, seven 48px toggles (Mo-Su), selected filled seal
    with paper text; at least one stays on.
  - "DOSAGE": two `_Stepper` cards (sessions per day 1-4, reps per session
    1-30) with minus/plus `IconButton`s and the value in `monoLarge`.
  - "TARGETS (<verification type>)": `NumberField`s for that type (sustained:
    duration; notes: pitch, tolerance, duration; glide: range), each with an
    example hint; loudness and checklist show a note instead.
  - `PrimaryButton` "Assign" / "Save changes" ("Saving" while busy).
  - Edit only: `TextButton` "End assignment" with an `AlertDialog`
    confirmation.
  - Note "Changes apply from today. Earlier days keep the dosage..."

#### VoiceSamplesScreen (Voice samples tab)
`features/therapist/presentation/voice_samples_screen.dart`

- App bar "Voice samples".
- `_FilterPanel`: four labelled `ChoicePills` rows, each starting with "All":
  Participant (codes), Kind (practice/probe), Task, Type.
- "Showing N of M recordings".
- `RecordingTile` list with participant code and `AnalysisChip` (hourglass +
  "Analysis pending"). Read-only. Empty filter result: mic-off `EmptyState`.
- Opening from a participant pre-selects that participant (the route is keyed by
  patient id so the filters reset).

### 4.4 Research admin

#### StudyOverviewScreen (Overview tab)
`features/admin/presentation/study_overview_screen.dart`

- App bar with `SignOutButton`.
- Header: "STUDY OVERVIEW" seal eyebrow, "Melo pilot"
  `headlineLarge`, `BrushStroke`.
- `StatTile` pair, flex 4:7: "Enrolled" with therapist count; "Overall
  adherence" with "N below X%" caption.
- "STATUS MATRIX": card listing every `ParticipantStatus` with label, action and
  count in `monoLarge` (muted when 0); explanatory note below.
- "PARTICIPANTS": `_ParticipantRow` cards (code in a fixed 56px column, status,
  "Low adherence" text, rate). Rows are not tappable. Empty: user-plus
  `EmptyState`.

#### PeopleScreen (People tab)
`features/admin/presentation/people_screen.dart`

- App bar "People".
- `ChoicePills`: Patients / Therapists.
- `PrimaryButton` "Add patient" / "Add therapist".
- Patients: card with code, name, "Therapist: ..." or "No therapist assigned", and a
  `TextButton` "Reassign" that opens a bottom sheet listing therapists (current
  one marked with a seal check).
- Therapists: card with name, email, and caseload count on the right.
- Empty: users `EmptyState`.

#### UserFormScreen
`features/admin/presentation/user_form_screen.dart`

- App bar "Add patient" / "Add therapist".
- Fields: full name (required), email (pattern check), temporary password (8+
  chars, within bcrypt's 72-byte limit). Inline validation on submit.
- Patients only: "THERAPIST" `ChoicePills` with therapist names, plus a note
  that the participant code is assigned automatically.
- Server-side input problems (for example a duplicate email) show in `error`
  colour above the button; other failures as a snackbar.
- `PrimaryButton` "Create account" / "Creating"; success shows a
  snackbar with the new code and pops.

#### ExerciseLibraryScreen (Library tab)
`features/admin/presentation/exercise_library_screen.dart`

- App bar "Exercise library".
- `ChoicePills` filter with counts: All (n), Approved (n), Pending approval
  (n), Archived (n).
- `PrimaryButton` "New exercise".
- Exercise cards: title, program, `ExerciseStatusChip` (badge-check ink /
  clock seal / archive muted, outlined, icon + text).
- Empty filter: library `EmptyState`.

#### ExerciseEditorScreen
`features/admin/presentation/exercise_editor_screen.dart`

- App bar "New exercise" or "Exercise".
- Existing exercise: status chip plus "Approved on ... by ...".
- Content fields: name, program (hint), summary (3 lines), steps (8 lines, one
  per line), evidence source (optional). Required fields validate inline.
- Dosage row: minutes, reps, per day as three whole-number fields side by side.
- "VERIFICATION": `ChoicePills` for sustained / glide / notes / loudness /
  checklist, then default target fields for the chosen type.
- Actions: note that saving withdraws approval (approved exercises only);
  `PrimaryButton` "Save"; `SecondaryButton` "Approve for assignment" (pending
  only); `TextButton` "Archive" / "Restore". Each shows a snackbar and pops on
  success; all disabled while busy.

#### StudySettingsScreen (Settings tab)
`features/admin/presentation/study_settings_screen.dart`

- App bar "Settings".
- "ADHERENCE THRESHOLD": `Slider` 50-100% in 5% steps with the value in
  `monoLarge` in a fixed column; help text.
- "PROBE SCHEDULE": "Probe every" pills (Week / Two weeks); "Study length"
  pills (4 / 6 / 8 weeks); help text.
- `PrimaryButton` "Save settings", enabled only when something changed.
- "EXPORT": help text and three `SecondaryButton`s (completions, assignments,
  recordings) with file-down icons; the running one reads "Saving" and the
  others disable. Opens the system save dialog.
- "AUDIT": tappable card "Access log" with scroll icon and chevron.
- `SecondaryButton` "Sign out".

#### AccessLogScreen
`features/audit/presentation/access_log_screen.dart`

- App bar "Access log".
- "Showing N entries", then one card per entry, newest first: seal headphones
  (playback) or file-down (export) icon, action label `titleSmall`, target,
  user email, timestamp in mono. Read-only.
- Empty: scroll `EmptyState`.

### 4.5 Developer

#### SensorCheckScreen
`features/diagnostics/presentation/sensor_check_screen.dart` and the panel
files beside it.

Uses `AppTheme.diagnostics` (dark oscilloscope look, `DiagnosticColors`),
deliberately separate from the paper design. Title uppercase "SENSOR CHECK",
then a note that nothing is saved. Panels, top to bottom:

1. `MicrophonePanel`: waveform (raw vs denoised), level meter (floor, voice
   threshold, input, clean), `SpectrumPanel` (input / learned noise / clean
   spectra with hum and tone markers), `NoiseTypesPanel` (rumble, mains hum,
   whine, broadband, fluctuating, clicks with measurements), `_QualityPanel`
   (noise floor, SNR, noise removed, clean SNR, phonation, clipping). Shows
   "starting" / "denied" / failure notes.
2. `MotionPanel`: gyroscope and accelerometer traces with a still/moving
   verdict and threshold line.
3. `OrientationPanel`: pitch and roll against a user-set reference ("Set
   reference angle" button).
4. `ProximityPanel`: near/far reading.

Charts are `CustomPainter`s in `widgets/diagnostic_charts.dart`; panel frames
and readouts are in `widgets/scope_widgets.dart`.

---

## 5. Cross-cutting UI patterns

- **Page anatomy**: `Scaffold` > `AppBar` (title `titleLarge` 20/600) >
  `AsyncView` > `PageList`. Home/overview tabs skip the title and open with an
  eyebrow + `headlineLarge` + `BrushStroke` header and an `EntryCascade`.
- **Section rhythm**: `SectionLabel`, content, then 24 or 32px before the next
  section. Cards in a list are separated by 8px (dense lists) or 16px (primary
  lists).
- **Loading**: `SkeletonList` everywhere; buttons change their label while
  working ("Saving", "Signing in").
- **Errors**: load errors become an `EmptyState` with the failure message; write
  errors become a snackbar via `runWithFailureMessage`; form errors are inline.
- **Status is never colour alone**: flags, chips and quality results always
  pair an icon with text.
- **Selection**: single-choice options are either `ChoicePills` (short labels)
  or tappable cards with a circle/circle-check icon (options with
  descriptions).
- **Stat pairs** use unequal flex, never equal columns.
- **Accessibility**: icon buttons carry tooltips; checkboxes, steppers, level
  meter and chart have semantics labels; touch targets are at least 48px.

---

## 6. Observations for UI improvement

Starting points noticed while documenting. These are not bugs, and none has
been changed.

**Token drift**: a few literal values remain in widgets: login
`maxWidth: 440`, pill vertical padding `10`, level meter height `32`, step
number `height: 1.75`, and icon sizes 14/16/18/20/22/40/72 used ad hoc. An
`AppSizes.icon*` scale would make icon sizing consistent.

**Patient**
- `ExerciseChecklistTile` puts one 48px checkbox per session in a row; at 4
  sessions a day the title column gets narrow on small phones.
- Record setup gives the probe a primary button and practice a secondary one,
  which is intentional, but the screen is long; the practice task list could
  collapse once the probe is done for the period.
- Exercise detail has an empty app bar; the program/title header could move
  into a collapsing app bar.
- No confirmation before "Discard" on a reviewed take.
- Profile has no way to edit name or password.

**Therapist**
- Voice samples: four pill rows push the list below the fold. A compact filter
  bar or a bottom-sheet filter would help as caseloads grow.
- Participant detail shows assignments without their adherence; that lives one
  tap away on the adherence screen.
- Dashboard app bar holds only sign-out, leaving an empty bar above the
  greeting.

**Admin**
- Overview participant rows are not tappable and show no name (by design, codes
  only), so there is no drill-down from the overview.
- Study settings has no unsaved-changes warning when leaving the tab.
- Access log has no filtering or grouping by date.
- People screen has no search and no way to deactivate an account.

**General**
- No tablet layout: content just caps at 1280px wide, which is very wide for
  single-column cards. A narrower reading width (around 640px) for forms and
  detail pages would read better.
- Empty states are left-aligned inside a `PageList`; on tall screens they sit
  high with a lot of space below.

---

## 7. Working on the UI with Claude

Useful framing for a prompt:

- Point at the screen file and this document's section for it.
- Remind it to use only `AppColors`, `AppTypography`, `AppSpacing`,
  `AppRadius`, `AppSizes`, `AppMotion`, and to add any new string to
  `lib/l10n/app_en.arb` (then `flutter gen-l10n`).
- Reuse the shared widgets in section 2 before creating new ones; extract a
  widget class rather than a `_buildX()` helper when a build method passes ~80
  lines.
- Keep loading, empty, error and success states, 48px targets, semantics
  labels, and icon + text for status.
- Finish with `dart format .`, `flutter analyze` and `flutter test`.
