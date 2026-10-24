# Offline Android launch, login and setup

This branch replaces the seeded-demo launch path with `SetupApp`. Use **Android
API 24+** and Flutter stable (developed with Flutter 3.38.9 / Dart 3.10.8).
The old feature code is retained for reference and regression tests, but it is
not routed or initialized by this entry point. Today, baseline recording and
prescribing are explicitly labeled stubs. There is no backend or analytics.

```sh
flutter pub get
flutter analyze
flutter test
flutter test test/setup/two_device_integration_test.dart
flutter build apk --flavor study --release
flutter run --flavor study -d <android-device-id>
```

Run Flutter build and integration-test commands sequentially in this checkout;
they regenerate shared Android plugin-registration files.

The physical smoke test uses a separate application ID and refuses to touch
storage unless its directory belongs to `com.melo.app.setupcheck`.
The explicit `setupcheck` build flavor isolates installation as well as storage. Run it with:

```powershell
flutter test integration_test/setup_android_test.dart --flavor setupcheck -d <android-device-id>
```

It uses the real Android Keystore, production-cost PBKDF2, signup widgets,
persistent restart semantics and typed reset. It does not exercise another
phone's camera, the Android share target, biometric enrollment or TTS quality.

`android/app/src/release/AndroidManifest.xml` removes INTERNET permission even
if a dependency contributes it. Debug/profile retain Flutter tooling sockets.
The QR scanner uses bundled ML Kit, not a first-run model download. Android
backup is disabled and FLAG_SECURE blocks screenshots and recent-app previews.
Release signing still uses the repository's **development signing key**; configure
institutional signing before distribution.

## State and routing

The persisted `SetupStage` and `SetupState` live in `lib/core/setup_state.dart`.
Riverpod injects `SetupService`; go_router redirects every route against it.
All mutations enforce the same rules in the service, independent of navigation.

```text
unset
  patient: needsJoin → language → information → consent → signature
           → sendConsent → awaitingPlan → orientation → baseline → active
  therapist: needsSignup → needsPin → needsKeys → ready
```

`language` through `sendConsent` refine joined/consentPending. `awaitingPlan` is
consentSent. `orientation` is planReceived/needsOrientation. Each completed step
and its data are persisted in one snapshot. Draft consent ticks and baseline
task completion survive restarts. An unfinished drawing or unsubmitted form is
not saved. A successful share-sheet handoff or explicit transfer confirmation
moves consent to awaitingPlan; it does **not** imply therapist approval. Consent
can be re-exported while waiting. No polling runs.

Active patients open Today without a PIN. Ready therapists always restart locked
at `/unlock`; only successful PIN or opted-in biometrics opens their patient list.
Backgrounding obscures the UI; returning after 60 seconds locks the therapist
session. External file-picker/share activities shorter than this keep the session
so a normal transfer can complete. If a long transfer locks it, unlock and retry.
Signup, PIN setup and interrupted key generation resume at their saved steps.

## Storage and isolation

`lib/data/setup_repository.dart` provides repository and secret-store interfaces
plus local and in-memory implementations. The encrypted Hive database
`offline_setup/setup` is the SQLCipher-equivalent local encrypted store. A random
256-bit key is held by flutter_secure_storage, protected by Android Keystore.
An HKDF-derived separate key authenticates each JSON snapshot with AES-256-GCM
inside Hive encryption; GCM AAD is `setup-snapshot-v1`. Hive commits the entire
snapshot in one record and flushes it. Invalid authentication fails closed.

Each installation has one role. The therapist snapshot contains only that
therapist's `patients[participantId]`. Patient IDs and therapist IDs are random
UUIDs. An installation never opens another therapist's store. The old demo's
`melo` boxes are not migrated or read. Existing demo installations
should not be used as study devices; this workflow's reset affects its own
namespace, not old demo data.

Private signing/encryption keys and the PIN hash are stored only in secure
storage. PINs are 4–6 digits, PBKDF2-HMAC-SHA256 with 600,000 iterations and a
random 128-bit salt, computed in a background isolate. Five failures lock for
30 seconds, then 60, 120, etc., capped at an 8.5-hour lock. Deadline, failure
count and escalation persist in secure storage. Success resets escalation.
Tests inject a low iteration count solely to keep fixtures fast.

Forgot PIN requires literal `DELETE`. A durable reset marker makes interrupted
wipes resume on launch. It deletes all workflow records and private/PIN keys,
rotates the database key, and returns to Signup. Old consent packages cannot be
decrypted with the new keys. There is no recovery. The app cannot revoke copies
already exported to other apps or phones; Android flash storage also cannot
promise forensic overwrite. Destroying the old keys provides cryptographic
erasure of encrypted workflow records.

## Exchange protocol

Every transport consumes or returns a typed `SyncEnvelope`:

```json
{
  "version": 1,
  "type": "join | consent | plan",
  "senderId": "UUID",
  "recipientId": "UUID or * for public join",
  "nonce": "base64",
  "ciphertext": "base64",
  "mac": "base64"
}
```

JSON signatures use recursively key-sorted, compact UTF-8 JSON (`canonical`).
Protocol v1 supports only the stated payload shapes, not arbitrary JSON numbers.
Packages are limited to 1 MiB and unknown envelope versions are rejected.

* **Join:** public, unencrypted; empty nonce/mac. `ciphertext` is base64 JSON
  `{v, therapistId, name, clinic, x25519Pub, ed25519Pub, consentVersion}`. The
  scanner pins those public keys on the patient phone. The profile is not
  institution-verified: confirm the name/clinic in person. Scanning grants no
  access and creates no therapist-side patient record.
* **Consent:** encrypted to the pinned therapist's X25519 public key. A fresh
  ephemeral X25519 key is generated per export. HKDF-SHA256 derives 32 bytes
  using the 12-byte GCM nonce as salt and
  `voice-setup-v1:` + canonical envelope header as info. The canonical header
  `{version,type,senderId,recipientId}` is also authenticated as GCM AAD.
  `ciphertext` is base64(ephemeral public key [32 bytes] || GCM ciphertext);
  `mac` is the 16-byte GCM tag. Recipient mismatch gets a clear error; changing
  the recipient or any authenticated byte cannot bypass decryption.
* **Consent plaintext:** `{record, signature}`. The Ed25519-signed record includes
  participant/therapist IDs, consentVersion, UTC signedAt, locale, every required
  and optional boolean, 18+ confirmation, PNG drawing and patient Ed25519 public
  key. The therapist verifies the signature and required items before storing a
  pending request. The drawing is part of the cryptographically signed data.
* **Approval:** therapist signs `{participantId, therapistId, consentVersion,
  consentHash, approvedAt, paperCopy}`. consentHash is SHA-256 of the **complete
  signed patient consent**, binding the countersignature to the exact record and
  patient signature. The paper-copy checkbox is required. Only then can forms
  be saved or a prescription created. Duplicate consent imports are idempotent;
  conflicting records cannot overwrite an existing participant.
* **Plan:** unencrypted, therapist-signed `{record, signature}` in base64
  `ciphertext`, with empty nonce/mac. The record carries v, both IDs, createdAt,
  three mock exercises, dose, approval and countersignature. It intentionally
  contains **no demographic/clinical forms, name or signature PNG**. It still
  exposes a pseudonymous ID and exercise choices to anyone holding the package.
  The patient verifies the pinned therapist signature, exact recipient, approval
  signature and locally computed consent hash before moving to orientation.

`SyncTransport` implementations:

* `FileTransport`: share_plus exports JSON; file_picker imports and bounds input.
  The staging file is deleted after sharing; plugin-owned transfer caches are
  purged at the next cold launch and on therapist reset. Imported cache copies
  are removed after parsing without deleting user-selected originals.
  The app itself does not send network requests. Choose an offline Android share
  destination (Bluetooth, USB/local files); another chosen app may use a network.
* `QrTransport`: qr_flutter display and mobile_scanner import. Up to 1,400 UTF-8
  bytes uses one QR. Larger envelopes are base64-chunked into 1,200-character
  parts with `{qr:1,id:SHA256,i,n,data}` framing, at most 1,200 frames. Frames cycle
  every 700 ms, with pause/manual advance. The receiver tolerates out-of-order
  and duplicate frames, rejects mixed/conflicting frames and verifies the full
  checksum. Large PNG signatures work but file transfer is much faster.
* `FakeTransport`: serialization-preserving queue for two-device tests.

NearbyTransport is a **deferred stretch**, not implemented or advertised as
active. `LocalTherapistDirectory` always returns no match across phones. The
six-digit field displays: “Code lookup arrives with the hospital backend; scan
the QR for now”. It never fakes a connection.

## Consent, language and narration

All consent/information copy is explicitly **PLACEHOLDER**, including English,
Hindi and Punjabi ARBs under `lib/features/setup/l10n`. Labels are loaded through
`SetupStrings`; Noto Sans Devanagari/Gurmukhi are bundled. Clinical and language
review, ethics-approved text, final forms and new consent version are required
before recruitment. Some technical validation errors remain English.

`NarrationSource` checks `assets/audio/narration/information-<locale>.mp3` in the
asset manifest first. No approved narration audio is supplied yet. To add it,
place the files there and register the folder in pubspec.yaml. Otherwise
flutter_tts chooses an explicitly offline installed voice and highlights callback
word ranges. If no offline voice exists, it shows an error; it does not select a
network voice. Audio-file narration has no word timing without a timing track.

## Two-phone acceptance test

Use fresh test installations and synthetic information only. Run in airplane
mode with Bluetooth enabled if testing that share destination.

1. Phone A: choose Therapist, enter self-declared profile, set/confirm PIN,
   optionally enable already-enrolled biometrics, generate keys, open My join code.
2. Phone B: choose Patient. Try the six-digit field and confirm that it cannot
   resolve a code. Scan A's join QR; confirm the name and clinic in person.
3. B: select en/hi/pa, read/listen to placeholder information, expand and check
   every required item and 18+. Leave anonymised analysis unticked to test that
   it is optional. Draw a signature, redo it, then save.
4. B → A: transfer consent by file, import on A, and confirm B remains waiting.
   Repeat with QR (including animated frames); duplicate imports must not create
   a second request. Cancel an export/import and verify the state remains usable.
5. A: review verified signature, version, timestamp, consent booleans and drawing.
   Verify forms are inaccessible before approval. Confirm paper copy and approve.
   Enter synthetic forms; choose any three mock exercises and dose 1–20.
6. A → B: send the plan by file, then repeat the scenario with QR. B must reject a
   modified plan and a plan for another participant. A successful import advances
   B to the three orientation cards and three baseline stub tasks, then Today.
7. Restart either phone at every setup stage. B resumes or opens Today without
   PIN. A ready session always requires unlock. Five wrong PINs lock for 30 s;
   restart during lockout and verify the remaining wait persists. A second block
   is 60 s. Correct PIN or enrolled biometrics after lockout unlocks.
8. A second independent therapist phone must reject B's original encrypted
   consent. The automated test performs this with a third isolated in-memory
   device. Typed DELETE on A must erase workflow records/keys and return to Signup.

Automated tests under `test/setup` cover this exchange, state/resume/guards,
consent gates, optional refusal, PIN salt/lockout/reset, authenticated encrypted
storage, key rotation, envelope tampering/serialization, and QR byte limits,
duplicate/out-of-order/mixed/corrupt frames. Widget tests exercise role selection
and required-consent gating. Real camera, share-sheet, fingerprint, TTS voice and
two-physical-device behavior require the acceptance test above.

## Remaining limits

Validation on 24 October 2026: `flutter analyze` was clean and all **153 host
tests** passed, including the in-memory two-device exchange. The Android
release build (`flutter build apk --flavor study --release`) succeeded; the APK
manifest was checked and contains no INTERNET permission. The physical
Android smoke test was interrupted and is **not a pass**. Two-physical-phone
file/QR transfer, biometrics and installed-voice playback remain pending; the
user elected to finish with automated checks. A first isolated-build guard
also correctly refused to access storage when the package ID was wrong; the
explicit `setupcheck` flavor now produces the separate test package.

This is a prototype, not a study-ready release. Baseline buttons record no audio;
Today and prescriptions are stubs. There is no clinical backend, Nearby lookup,
withdrawal/re-consent/export revocation workflow or therapist verification. The
protocol needs an independent security review. A four-digit PIN has limited
entropy; a compromised/rooted device or manipulated wall clock is outside this
prototype's guarantees. Setup checks protect normal app operations, not a
compromised OS. Keep devices physically controlled. File/QR package possession
does not prove the person signing was the intended participant.
