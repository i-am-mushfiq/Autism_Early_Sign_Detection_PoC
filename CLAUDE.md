# Sanket

Early developmental observation for children aged 18–36 months in Bangladesh — "early developmental signals, not diagnoses." Built for a National Ideathon. Guided play activities give a child standardized chances to respond; phone sensors measure the response; only modalities that pass quality checks are used; the output is an observation plus one of four next steps, never a diagnosis.

The spec is `docs/ideathon/Sanket_National_Ideathon_Submission_JUDGE_READY(1).docx` (§5 journey, §7 activities, §8 quality control, §10 privacy and result wording, §16 demo conditions, §17 product boundaries). How the app implements it: `mobile/sanket_mobile/MEASUREMENT.md`.

## Non-negotiable product rules
- No diagnosis, no condition probability or score, no treatment advice.
- An unreliable modality is **excluded**, never converted into a value. Too little valid data → **Inconclusive**. Non-participation is never interpreted; a child never "fails".
- Only four result states: *No strong follow-up signal observed*, *Monitor*, *Discuss with a professional*, *Inconclusive* (spec wording, `lib/l10n/strings.dart`).
- No facial identity recognition, no background recording, no raw video or audio kept.
- Do not invent clinical thresholds. All numbers live in `lib/core/prototype_parameters.dart` and are labelled as prototype values.

## Layout
```
mobile/sanket_mobile/     Flutter Android app — the active codebase (git: github.com/i-am-mushfiq/Autism_Early_Sign_Detection_PoC)
mobile/build-snapshots/   frozen copies from before git (history only; never edit)
releases/android/         built APKs, Sanket-<version>-<change>.apk (not in git)
web/landing-page/         static marketing site + PWA prototype (its own git repo)
docs/ideathon/            submission .docx and pitch decks (not in git)
design/                   app-screen mockups, mascot emotion PNGs, generated art
```

## Mobile app (`mobile/sanket_mobile`)
- Flutter 3.22.3 / Dart 3.4.4, AGP 7.3, Kotlin 1.7.10, Gradle 7.6.3, JDK 17. Key deps: `camera` 0.10.5+9, `google_mlkit_face_detection` 0.13.1, `google_mlkit_pose_detection` 0.14.0, `permission_handler`, `shared_preferences`.
- The toolchain is user-local. In PowerShell, first run: `. C:\Users\TL-77057\Downloads\toolchain\env.ps1`
- Check: `flutter analyze; flutter test` (84 tests) · Phone APK: `flutter build apk --release --target-platform android-arm,android-arm64` · Emulator APK: `--target-platform android-x64` (AVD `sanket34`, `ANDROID_AVD_HOME=...\toolchain\avd`).
- `android/build.gradle` forces the ML Kit plugin modules to compileSdk 34: AGP 7.3 cannot read SDK 35 during release resource verification. Keep this unless AGP is upgraded.
- Release builds are still signed with debug keys.

### Architecture
```
lib/core/         pure Dart: samples, measurement model, quality gates, calibration, activity catalog,
                  interpretation rules, session record + repository (no Flutter UI)
lib/activities/<activity>/  <name>_analyzer.dart (pure capture → observation), <name>_controller.dart
                  (timeline, timeouts, events), <name>_view.dart (child board + caregiver panel)
lib/runtime/      ActivityController base, CalibrationController, SessionController (plan, retries,
                  breaks, time limit, save-once finalize)
lib/sensors/      SensorHub interface; DeviceSensorHub = camera + ML Kit + native mic channel
lib/l10n/         enum T (every string in English + Bangla), Strings/LocaleScope (context.s)
lib/presentation/ theme, screens (welcome, consent, profile, setup, result, history), session stage
android/.../MainActivity.kt  EventChannel `sanket/audio_level`: RMS/peak dBFS per 100 ms, no audio kept
test/support/     FakeSensorHub, SimChild (simulated child producing samples), runActivity/runSession helpers
```
- Add a string: add a `T` entry with both languages; `test/l10n_test.dart` checks placeholders and script.
- Change a rule or threshold: edit `prototype_parameters.dart` / `interpretation.dart` and bump `rulesVersion`.
- Each activity must stay a pure analyzer plus a controller; results must be reproducible from stored JSON.

## Landing page (`web/landing-page`)
- No dependencies. `npm run dev` → http://127.0.0.1:4173 serves `site/`; `npm run build` → `dist/`.

## Windows notes
- Git Bash `mv` of a locked directory falls back to copy+delete and can leave a partial split. Stop the lock first.
- PowerShell `>` corrupts binary output (e.g. `adb exec-out screencap`); use Bash for that.
