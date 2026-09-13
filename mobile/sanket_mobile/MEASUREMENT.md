# Sanket measurement pipeline (prototype)

Sanket measures behaviour in guided activities. It never diagnoses. Everything here implements the ideathon submission (`docs/ideathon/Sanket_National_Ideathon_Submission_JUDGE_READY(1).docx`, §5–§10, §16–§17). Every numeric value comes from `lib/core/prototype_parameters.dart` and is **not clinically validated**.

```
Capture (sensors/)  →  Quality check (core/quality.dart, calibration.dart)
   →  Feature extraction (activities/*/…_analyzer.dart)  →  Interpretation (core/interpretation.dart)
```

## Capture
| Signal | Source | What enters the app |
|---|---|---|
| Head orientation | Front camera → ML Kit face detection, on device | yaw, pitch, face size and position, eye-open probability per frame |
| Upper-body pose | Front camera → ML Kit pose detection (Copy Me only) | nose, eyes, ears, shoulders and wrists with likelihoods |
| Lighting | Camera luma plane | mean brightness (0–1) per frame |
| Sound level | Native `AudioRecord` (`MainActivity.kt`) | RMS/peak dBFS per 100 ms; raw audio is discarded in the native buffer |
| Touch | Flutter pointer events | position, time, simultaneous pointer count |

No image, video or audio is stored or sent. Only the derived numbers above are kept, and only while the activity runs.

## Quality gates (applied before any feature is used)
* **Camera:** processed frame rate ≥ 4 fps, otherwise *excluded (too slow)*.
* **Lighting:** median luma 0.16–0.94, otherwise *too dark* / *too bright*.
* **Face:** detected, with width 10–75% of the image (*too far* / *too close*). Frames with eyes closed are not used for gaze.
* **Coarse gaze:** usable only after a passed calibration (below).
* **Audio:** background noise ≤ −32 dBFS. When the microphone is unavailable or too noisy, the caregiver taps "I called", and timing is marked *limited* (no latency is reported).
* **Pose:** shoulders, nose and at least one wrist with likelihood ≥ 0.5.
* **Touch:** contacts with more than 2 simultaneous pointers are rejected as palm contact.

An excluded modality is never replaced by a guess. A trial or activity without enough usable signal is *invalid / insufficient*. Nothing happening while the child is not taking part is *non-participation*, and that is never interpreted.

## Gaze calibration (`core/calibration.dart`)
The child watches a star at centre, left, right and up (2.2 s each, first 0.7 s discarded). Calibration passes only if there are ≥ 5 usable face samples at each of centre, left and right; left and right median head yaw differ by ≥ 8° and ≥ 2.5 × the within-target SD; the SD is ≤ 9°; and centre lies between left and right. Otherwise gaze is excluded, with the reason shown. It can be retried up to 3 times or skipped. Classification maps yaw to left / centre / right and returns *uncertain* when two regions are close.

**Limitation:** this is head-orientation-based coarse gaze, with no iris tracking. It can only tell apart large screen regions.

## Activities
| Activity (spec evidence) | Stimulus & timeline | Features | Valid when | Pattern note (prototype rule) |
|---|---|---|---|---|
| Social Story (evidence-backed) | Talking, waving guide on one side, turning pinwheel on the other. 2 × 20 s segments with sides swapped | share of classified gaze on the social side, side transitions/min, on-screen attention | camera, lighting and gaze usable; ≥ 45% of frames classified in **both** segments | looked more at the pinwheel in both segments |
| Name Response (evidence-backed) | Calm scene. Once the child has faced the screen for 1.5 s, the caregiver is prompted to call the name once. Up to 5 attempts for 3 valid trials | head turn ≥ 22° from the pre-call baseline (or turning ≥ 10° then leaving view) within 5 s; latency from the audio onset; re-engagement | ≥ 2 valid trials (attending before the call, call detected, face measurable) | no head turn in any valid trial |
| Follow My Look (evidence-backed) | Guide looks at the child, then turns eyes and head to one of two static toys. 4 balanced trials | first side held for 2 frames after the cue, acquisition latency; which toy is tapped (secondary, limited) | calibrated gaze; child attending and not already on the target; ≥ 50% face frames; ≥ 2 valid trials | never looked toward the cued toy |
| Bubble Trail (promising) | 40 s of drifting bubbles, max 3 at a time | pops, touches, hit rate, median reaction time, RT coefficient of variation, endpoint error (in bubble radii), missed bubbles, corrections | ≥ 5 touches and ≥ 3 pops | none (descriptive only) |
| Copy Me (emerging) | Guide demonstrates hands up, clap and touch head (3.5 s), then a 6.5 s response window | detected action and onset latency, imitation rate, rough fidelity (1 = same action, 0.5 = another action, 0 = none) | upper body framed in ≥ 50% of the window; ≥ 2 valid trials | no copied action in any valid trial |
| Switch It (supportive only, 24+ months) | Tap the bird ×5, rule-change screen, tap the ball ×5. Sides shuffled | accuracy before and after the switch, perseverative taps, switch cost (median RT difference), RT variability, omissions | ≥ 3 responses under each rule | none (descriptive only) |

Timeouts: attention 9 s, call 7 s, centre 7 s, framing 9 s, touch inactivity hint 10 s / stop 22 s, 6 s per Switch It trial (stops after 4 omissions in a row). The caregiver can pause (the attempt restarts), skip, retry once when a retry can help, or end the session. The session stops at 11 minutes, and 2 disengaged activities in a row prompt a break suggestion.

## Interpretation (`core/interpretation.dart`, `sanket-prototype-rules-v1`)
1. **Inconclusive** if fewer than 3 activities are valid, or fewer than 2 of the evidence-backed ones.
2. Patterns count only from valid activities.
3. A reported hearing concern suppresses Name Response, a vision concern suppresses Social Story and Follow My Look, and a motor difficulty suppresses Copy Me. Suppressed patterns are shown but not interpreted.
4. Spec wording: *several* (≥ 2) patterns from evidence-backed activities → **Discuss with a professional**. *One or more* (1 evidence-backed, or any from an emerging activity) → **Monitor**. None → **No strong follow-up signal observed** (which never rules out a condition).

The outcome is a pure function of the stored observations, profile and rules version, so it can be recomputed from a saved session (see `test/session_test.dart`).

## Honest limits of this prototype
* Thresholds, windows and the rule-to-state mapping are engineering choices for a demonstrable prototype. Spec §12 requires technical, construct and clinical validation before any screening-support claim.
* Head yaw is a proxy for looking direction, and toddlers also move their eyes without turning the head.
* Name-call timing uses loudness onset, not speech recognition; other loud sounds can be mistaken for the call.
* Pose detection is trained mostly on adults. Toddler framing, and an adult in view, can reduce accuracy.
* Touch cannot tell the child's taps from a caregiver's.
* ML Kit's bundled models run on device; the SDK may still fetch its own configuration from Google services.
