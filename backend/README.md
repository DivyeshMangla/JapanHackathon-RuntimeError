# Connected care service

Node.js 24+, SQLite, private filesystem recording storage. Uses Node built-ins;
there are no npm dependencies to install. The mobile app and admin dashboard
share this API. The admin dashboard is served from `../admin` on the same origin.

## Run locally

From the repository root:

```powershell
npm run demo
```

Open http://127.0.0.1:8787. Use **Use demo administrator account** on the login
screen, or `admin@melo.test` / `VoiceDemo!2026`.

Other synthetic accounts use the same demo password:

| Role | Email |
| --- | --- |
| Approved therapist | meera@melo.test |
| Patient assigned to Meera | patient@melo.test |
| Pending therapist | riya@melo.test |

Demo seeding runs only when the database contains no accounts. It does not replace
an existing workspace. `npm run dev` starts the service without seeding. Stop it
with Ctrl+C. Default binding is loopback only.

## Empty workspace / real administrator

Use a separate `DATA_DIR` for a non-demo workspace. Set `ADMIN_EMAIL`,
`ADMIN_NAME`, and a unique `ADMIN_PASSWORD` of 12–128 characters in your shell
environment, then run `npm --prefix backend run admin`. The command never prints
the password. Start with `npm run dev`. Public registration can create patients
and pending therapists; it cannot create administrators.

## Storage and access

- `backend/data/melo.sqlite`: users, hashed sessions, consent, clinical
  forms, plans, practice events, recording metadata, login limits and audit events.
- `backend/data/uploads/`: WAV audio, addressed by server-validated IDs. Files are
  delivered only through an authenticated and authorised API route.
- `migrations/001_initial.sql`: idempotent initial schema. SQLite WAL and foreign
  keys are enabled. Back up the database and uploads together using a consistent
  SQLite backup procedure, not a live copy of the main database file alone.
- Passwords use salted scrypt. Browser sessions use HttpOnly/SameSite=Strict
  cookies; mobile clients use bearer tokens held in secure device storage. Only
  token hashes are stored on the server; sessions expire after seven days.
- Disabling an account and password changes revoke its sessions. An active
  therapist can only read assigned patients. Reassignment removes the old
  therapist's API access immediately. Administrators have workspace-wide access.
- Therapist approval is manual. Registration details are self-declared until
  the administrator verifies them externally. A therapist account an
  administrator creates is active at once.
- Every recording playback adds an audit event naming the listener and the
  recording.
- Five failed login attempts for an IP/email pair block that pair for 15 minutes;
  an additional IP limit bounds broad guessing. Public registration is limited.
- JSON mutations and origin checks protect the cookie-based dashboard. The same
  server serves frontend and API; arbitrary cross-origin browser calls are denied.
- Consent must be submitted by the patient, approved by their assigned therapist
  with paper-copy confirmation, and followed by clinical forms before a plan can
  be created. Clinical forms are not included in the patient-facing response.
- Progress and recording IDs make successful retries idempotent. Recordings are
  WAV, at most 120 seconds / 12 MB; request bodies are bounded.

## API

All paths start with `/api`. Errors have `{ "error": "message" }` and an HTTP
status. Send JSON with `Content-Type: application/json`.

| Method / path | Access / purpose |
| --- | --- |
| GET `/health`, `/config` | Health, exercise library, current prototype consent |
| POST `/auth/register` | Patient or pending therapist signup |
| POST `/auth/login` | Email/password; `client: "mobile"` returns a bearer token |
| GET `/auth/me` | Current active account |
| POST `/auth/logout` | Revoke current session |
| POST `/auth/password` | Verify current password and replace it; revoke all sessions |
| GET `/overview`, `/users`, `/audit` | Administrator dashboard data |
| POST `/users` | Administrator creates a patient or an approved therapist |
| PATCH `/users/:id` | Administrator approves/enables/disables account |
| GET `/patients` | Administrator: all; therapist: assigned patients |
| GET `/patients/:id` | Own patient record / assigned therapist / administrator |
| PUT `/patients/:id/assignment` | Administrator assigns an active therapist |
| POST `/patients/:id/consent` | Patient submits version, checks and PNG signature |
| POST `/patients/:id/approve-consent` | Assigned therapist approves consent |
| PUT `/patients/:id/forms` | Assigned therapist saves age, demographic and clinical forms |
| POST `/patients/:id/plans` | Assigned therapist prescribes library exercises and dose |
| POST `/patients/:id/progress` | Patient sends an idempotent completed practice event |
| POST `/patients/:id/recordings` | Patient sends idempotent base64 WAV upload |
| GET `/recordings/:id/audio` | Patient owner / assigned therapist / administrator; each play is audited |
| POST `/recordings/:id/review` | Assigned therapist adds feedback |

See `test/api.test.mjs` for executable payload examples and permission checks.

## Deployment boundary

This implementation is a **local functional prototype**, not a hosted clinical
service. A production deployment needs an HTTPS endpoint/reverse proxy,
`PUBLIC_ORIGIN`, `NODE_ENV=production` (Secure cookies), institution-managed
administrator credentials, appropriate encrypted server volumes/backups, and
approved consent content. Server SQLite/filesystem data is not application-level
encrypted. The current single-instance storage is intended for a small prototype;
use shared database/object storage before adding multiple backend instances.

Email verification/reset delivery, MFA, cloud hosting, hospital identity
integration, push notifications, and institutional retention/withdrawal policies
are not implemented. No external services or hosting accounts are configured.

## Tests

```powershell
npm test --prefix backend
```

The API tests use isolated temporary SQLite databases and synthetic records.
They exercise auth, approval, access isolation, reassignment, clinical gates,
retry idempotency, recording upload/playback/review, rate limiting, password
changes, and persistence. They do not touch the local demo database.
