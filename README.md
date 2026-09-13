# Sanket — early developmental signals, not diagnoses

Sanket is a proof-of-concept Android app for families of children aged 18–36 months in Bangladesh. A 6–8 minute session of six short guided play activities gives the child standardized chances to respond. The phone's camera, microphone and touchscreen measure those responses on the device. Every signal passes a quality check before it is used, and the session ends in one of four careful next steps: *No strong follow-up signal observed*, *Monitor*, *Discuss with a professional*, or *Inconclusive*.

**Sanket is a research prototype. It does not diagnose autism or any other condition, and its rules are not clinically validated.**

## Activities
| Activity | Construct | Measured with |
|---|---|---|
| Social Story | Social attention | Head-orientation coarse gaze after calibration |
| Name Response | Social orienting | Microphone call onset + head turn |
| Follow My Look | Joint attention | Coarse gaze + toy taps |
| Bubble Trail | Visual-motor interaction | Touch telemetry |
| Copy Me | Imitation | On-device pose detection |
| Switch It (24+ months) | Attention shifting | Touch telemetry |

English and Bangla are both supported. No video or audio is recorded, and only derived measurements are kept, on the phone, with consent.

## Repository
- `mobile/sanket_mobile/` — the Flutter app. See [MEASUREMENT.md](mobile/sanket_mobile/MEASUREMENT.md) for the pipeline, quality gates, interpretation rules and limitations.
- `CLAUDE.md` — developer notes: architecture, toolchain, conventions.

## Build
```bash
cd mobile/sanket_mobile
flutter pub get
flutter test
flutter build apk --release --target-platform android-arm,android-arm64
```
Requires Flutter 3.22.3 and JDK 17.
