# Melo

Prototype Flutter app for voice therapy home practice and adherence monitoring.

The repository now also includes a connected care backend and admin dashboard.
Run `npm run demo` (Node.js 24+) and open http://127.0.0.1:8787 to explore the
synthetic admin workspace. See [Connected workspace](docs/CONNECTED_WORKSPACE.md)
for the connected Android build, project boundaries and workflows, and
[Backend](backend/README.md) for API and storage details.

The default Android entry point runs the offline launch, login and consent/setup
workflow. See [README_SETUP.md](README_SETUP.md) for build commands, device roles,
security design and two-phone testing. Run with `flutter run --flavor study`.
The seeded demo logins described in [CLAUDE.md](CLAUDE.md) belong to the retained
legacy screens and are not used by this workflow. [design.md](design.md) describes
the visual system, which the setup screens share with the rest of the app.

“Say a Useful Word” is available in the **connected** flavor. Start the backend,
then run `flutter run --flavor connected -t lib/main_connected.dart` (the Android
emulator uses `http://10.0.2.2:8787`; set `--dart-define=API_BASE_URL=https://…` for
your server). In a paired child's record, the therapist opens **Say a Useful
Word**, confirms eligibility, and assigns a word, picture, and example audio.
The guardian completes the separately labeled prototype consent on the child's
account. The child opens **Say a Useful Word** from their home screen; attempts
go directly to the therapist, without caregiver approval. This is therapist-guided
practice, not a validated standalone treatment.

The feature is now labeled **Say a Word** and includes therapist-only automated
analysis reports and separate clinician corrections. With no validated
pronunciation model configured, reports say **Unable to assess reliably** and
provide no accuracy score. Recognition failure never blocks original audio.
