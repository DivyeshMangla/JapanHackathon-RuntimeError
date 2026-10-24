# Melo

Home practice games for children, with their parents and therapists.

- **Child**: big picture buttons for today's games, saying a useful word and drawing.
- **Parent**: follows each child's practice, signs consent and sets up the child's device.
- **Therapist**: assigns games, words and drawing, and reviews what the child sends.
- **Admin**: manages people and the exercise library, in the app or at http://127.0.0.1:8787.

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
| Child | On the welcome page, choose **Set up for my child**, enter the parent code `PARENT` and the name `Ananya` |
| Parent | **I'm a parent**, then **I already have an account**: `parent@melo.test` |
| Therapist | **I'm a therapist**: `meera@melo.test` (therapist code `MEERA7`) |
| Admin | **I'm a therapist**: `admin@melo.test`, or the web dashboard |

A new family: sign up as a parent with the therapist code `MEERA7`, open Settings to see your parent code, then set up the child with that code.

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
