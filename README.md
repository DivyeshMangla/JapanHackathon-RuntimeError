# Melo

Home practice games for children, with their parents and therapists.

- **Child**: big picture buttons for saying a useful word and drawing, opened through the parent's child mode.
- **Parent**: adds each child (signing consent once, at that moment), follows their practice and hands the phone over in child mode.
- **Therapist**: assigns words and drawing, and reviews what the child sends.
- **Admin**: manages people, in the app or at http://127.0.0.1:8787.

## Run it

Needs Node 24+ and Flutter 3.38+, with an Android emulator running.

```bash
npm run demo
```

```bash
flutter run
```

`npm run demo` seeds a demo workspace the first time and starts the care service. On a real phone connected over USB, run `adb reverse tcp:8787 tcp:8787` and add `--dart-define=API_BASE_URL=http://127.0.0.1:8787` to `flutter run`. To start over, stop the service and delete `backend/data/`.

## Try the demo

Every account's password is `VoiceDemo!2026`.

| Who | How to get in |
| --- | --- |
| Parent | **I'm a parent**, then **I already have an account**: `parent@melo.test` |
| Child | Signed in as the parent, tap **Start child mode for Ananya**. To leave, tap **Grown-ups: leave child mode** and enter the parent's password |
| Therapist | **I'm a therapist**: `meera@melo.test` (therapist code `MEERA7`) |
| Admin | **I'm a therapist**: `admin@melo.test`, or the web dashboard |

A new family: sign up as a parent with the therapist code `MEERA7`, then **Add a child**: the child's name and the care consent are entered together, and consent is not asked for again.

Handwriting analysis is optional and needs a local Ollama vision model (see `backend/README.md`). Without it, drawing photos still reach the therapist.

## Checks

```bash
flutter analyze
```

```bash
flutter test
```

```bash
npm run test:backend
```

See `CLAUDE.md` for the architecture and engineering rules, `design.md` for the visual system and `backend/README.md` for the API.

Say a Word includes therapist-only automated analysis reports and separate
clinician corrections. No validated pronunciation model is configured, so reports
say **Unable to assess reliably** and provide no accuracy score. Original audio
delivery works independently of optional analysis.
