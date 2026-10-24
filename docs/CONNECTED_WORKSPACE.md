# App, admin and backend

The Flutter project remains at the repository root. Two independently organised
projects sit beside it:

```text
lib/                         Flutter patient + therapist application
  main.dart                  Existing offline study entry point
  main_connected.dart        Connected account entry point
  features/connected/        data/ (API client, encrypted cache and outbox),
                             domain/ (typed models), presentation/ (screens)
admin/                       Browser administrator workspace
backend/                     Node API, SQLite schema, uploads and API tests
test/connected/              Mobile cache/outbox/session tests
```

The dashboard is local at http://127.0.0.1:8787. Run `npm run demo` from the root
to create synthetic data and launch it. The dashboard has login, live overview,
patient search and filters, CSV export, account creation, therapist approval,
assignment, disabling/enabling accounts, consent/plan/progress inspection,
recording playback, audit history, and password changes.

## Connected Flutter build

Run the backend first. For an Android emulator:

```powershell
flutter run --flavor connected -t lib/main_connected.dart --dart-define=API_BASE_URL=http://10.0.2.2:8787
```

For an Android phone attached over USB, forward its port to this machine:

```powershell
adb reverse tcp:8787 tcp:8787
flutter run --flavor connected -t lib/main_connected.dart --dart-define=API_BASE_URL=http://127.0.0.1:8787
```

The connected flavor has a separate `.connected` application ID and separate
encrypted storage. It does not import the old offline QR setup database. The
existing study build continues to use `flutter run --flavor study`; study and
setupcheck release variants still remove INTERNET permission. Connected debug
permits HTTP for loopback development. Connected release requires an HTTPS
`API_BASE_URL`, for example:

```powershell
flutter build apk --release --flavor connected -t lib/main_connected.dart --dart-define=API_BASE_URL=https://your-api.example.org
```

The example hostname must be replaced by your deployed service. No hosted service
has been provisioned. Existing Android release signing remains the development key.

## Patient workflow

1. Register or use an administrator-created patient account, then sign in.
2. Read the prototype information, complete required checks, optionally consent
   to anonymised analysis, draw a signature and submit consent online.
3. An administrator assigns an approved therapist. The patient sees a waiting
   screen until the therapist approves consent, saves assessment forms and
   prescribes a plan.
4. Refresh to receive the plan. Log completed practice with the actual duration,
   or record up to two minutes of mono WAV audio.
5. Practice events and recordings enter the encrypted local outbox before upload.
   Successful items are removed; failed items keep the same event ID for retry.
   Sync runs after saving, on refresh, on resume and after sign-in/unlock. It does
   not run as an Android background service.
6. Therapist recording feedback appears on the patient's home screen after sync.

The patient can use a previously cached plan offline. First registration/login,
consent submission and receipt of a new plan require connectivity. This is a
separate connected flow; the offline flow's orientation/baseline stubs are not
silently treated as completed or migrated into it.

## Therapist workflow

1. Register with name, email, password, clinic and professional registration.
2. Administrator reviews the self-declared credentials and approves the account.
3. Sign in and set a 4–6 digit PIN for local access, optionally enabling enrolled
   device biometrics. On cold launch and return
   after 60 seconds in the background, the therapist workspace is locked.
4. Open an assigned patient, review consent and signature, confirm the paper
   copy, and approve. Save age, demographic information and clinical assessment.
5. Prescribe one to six exercises, one to five daily sessions, and instructions.
6. Review practice and play recordings, then leave feedback.

Forgotten connected-mode PINs can be replaced after online account-password
verification. This differs from the isolated offline study reset. PINs use the
existing PBKDF2/lockout service. Opted-in biometrics can unlock after the PIN
lockout expires; they do not bypass an active lockout.

## Account and offline boundaries

Sessions live in secure device storage. Cached records and queued recordings live
in an encrypted Hive box whose key is held in secure storage. Each API origin has
a separate namespace, and queues are additionally scoped to the server user ID.
Signing into another account never sends the previous account's queued data.

On sign-out, the local token is removed and online sessions are revoked. Unsynced
practice stays encrypted for the same account to resume later. An offline
sign-out cannot immediately revoke a token on an unreachable server. Server-side
disabling takes effect on the next online request; it cannot remotely erase
offline cached data. A password change revokes all server sessions.

Account password reset by email, background sync notifications and automatic
migration of offline consent are future work. Consent text and exercise content
remain explicitly prototype material.

## Validation

Run `flutter analyze`, `flutter test`, and `npm run test:backend`.
Build Flutter variants sequentially because they share generated Android files.
The connected-service tests cover durable retry, per-account queues, recording
queues and locked/restored/revoked sessions. API tests cover the full connected
care exchange and denial paths. Real microphone, device networking and audio
playback still require an Android device acceptance run.
