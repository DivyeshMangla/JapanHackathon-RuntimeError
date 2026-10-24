# Melo

Home practice games for children, with their parents and therapists.

- **Child**: picture buttons for saying a useful word, drawing and recognising feelings, opened through the parent's child mode. **My feedback** contains the therapist's guidance.
- **Parent**: adds each child (signing consent once, at that moment), sees submitted/reviewed practice and therapist assessments for all three activities, and hands the phone over in child mode.
- **Therapist**: assigns activities, reviews submissions and publishes practical guidance back to the family. Word feedback can include a voice message.
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
| Child | Signed in as the parent, tap **Start child mode for Ananya**. To leave, tap **Grown-ups: leave child mode** and enter the four-digit PIN chosen when starting child mode |
| Therapist | **I'm a therapist**: `meera@melo.test` (therapist code `MEERA7`) |
| Admin | **I'm a therapist**: `admin@melo.test`, or the web dashboard |

A new family: sign up as a parent with the therapist code `MEERA7`, then **Add a child**: the child's name and the care consent are entered together, and consent is not asked for again.

Drawing analysis can use local Ollama or the optional Groq hosted provider (see `backend/README.md`). Without a configured model, photos still reach the therapist for manual review. Dim photos receive a tonal analysis copy while the original is preserved; unreadable or unrelated photos request a replacement instead of completing practice.

To try feelings practice, open a child from the therapist's Participants tab,
choose **Feelings practice**, select two to six feelings and save. In child mode,
open **Feelings**, choose whether an adult is helping, and identify each pictured
expression. The service calculates correct/total, per-feeling results and confused
labels against the illustration key. The therapist reviews each round and sends
remarks back to **My feedback** and the parent's child dashboard. These are
practice-card results, not an autism assessment or an inference about anyone's
actual emotional state.

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

Say a Word includes therapist-only capture checks, optional local speech
recognition and separate clinician corrections. Configure local whisper.cpp with
`SPEECH_ML_URL`, or select `SPEECH_ML_PROVIDER=groq` with a server-side
`GROQ_API_KEY` (see `backend/.env.example`).
The child and frozen therapist example are independently transcribed without
the target answer in the recognizer prompt. Reports compare recognized text with
the target and reference, flag a mismatching example, and preserve both recordings.
Text similarity is not pronunciation accuracy: no validated pronunciation model
is included, so reports provide no automated accuracy score. Therapists can record
their own assessment and mark feedback reviewed to publish it to the family.
Drawing reports include task-specific evidence and quality limitations, with a
separate therapist assessment. Neither model has been clinically validated here.
Original submissions remain available when optional analysis is unavailable.

Child mode uses a four-digit PIN chosen by the parent each time they start it. Already-open demo sessions without a PIN use `1234`. Account sign-in still uses the account password.


## Optional hosted analysis

For a prototype using a Groq account's available free quota, set
`GROQ_API_KEY` in the backend environment, `MOTOR_ML_PROVIDER=groq` and
`SPEECH_ML_PROVIDER=groq`. Leave model variables unset for the provider defaults:
`qwen/qwen3.8-27b` for photos and `whisper-large-v3` for speech. An existing
local model override must be cleared or changed when switching providers.
Keys stay on the server. Free quotas are limited and account-dependent.

Each parent separately enables **Optional online analysis** on their child's
dashboard before any child's media is sent. The disclosure covers photos, child
voice and therapist reference audio, US processing and retention controls.
Earlier local-analysis consent does not grant online permission. A new online
grant can be made without changing the original signed care consent, and can
be withdrawn for future requests. Synthetic transport tests verify the pipeline;
no provider credentials or real child validation data are bundled.
