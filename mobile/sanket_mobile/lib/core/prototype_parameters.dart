/// Every numeric parameter used by Sanket's prototype measurement pipeline.
///
/// None of these values is clinically validated. They are engineering choices
/// that decide *whether a signal is usable* (quality gates) and how an
/// observable behaviour is detected in a single session. The submission
/// (§12) requires these to be replaced by values from technical and construct
/// validation before any screening-support claim is made.
///
/// Keeping them in one place makes every decision traceable: each stored
/// session records [rulesVersion], and interpretation can be re-run from
/// stored measurements with exactly these parameters.
library;

class PrototypeParameters {
  const PrototypeParameters._();

  static const rulesVersion = 'sanket-prototype-rules-v1';

  // ── Session ────────────────────────────────────────────────────────────
  /// Spec §10: "Maximum session duration is enforced." Activities stage only.
  static const maxActivityStageMs = 11 * 60 * 1000;

  /// Spec §10: "Session stops if the child ... repeatedly disengages."
  /// Consecutive activities ending without participation before the
  /// caregiver is offered to end the session.
  static const disengagedActivitiesBeforeBreak = 2;

  /// An optional, caregiver-initiated retry per activity. Never forced (§10).
  static const maxRetriesPerActivity = 1;

  static const minAgeMonths = 18;
  static const maxAgeMonths = 36;

  // ── Camera quality gates ──────────────────────────────────────────────
  /// Mean luma (0–1) below which the scene is too dark to trust vision.
  static const minLighting = 0.16;

  /// Mean luma above which the image is washed out.
  static const maxLighting = 0.94;

  /// Face bounding-box width as a fraction of the image width.
  static const minFaceWidthFraction = 0.10;
  static const maxFaceWidthFraction = 0.75;

  /// A face frame with both eyes this likely closed is not used for gaze.
  static const minEyeOpenProbability = 0.25;

  /// Minimum vision frames per second for timing features to be meaningful.
  static const minVisionFps = 4.0;

  // ── Coarse gaze calibration (head orientation based) ──────────────────
  static const calibrationStageMs = 2200;

  /// Samples in the first part of each stage are discarded (child re-orienting).
  static const calibrationSettleMs = 700;
  static const calibrationFaceWaitMs = 8000;
  static const maxCalibrationAttempts = 3;
  static const minSamplesPerCalibrationTarget = 5;

  /// Minimum yaw separation between the left and right targets, in degrees.
  static const minLeftRightSeparationDeg = 8.0;

  /// Separation must also exceed this multiple of the pooled within-target SD.
  static const separationToNoiseRatio = 2.5;

  /// Pooled within-target yaw SD above which head orientation is too unstable.
  static const maxCalibrationNoiseDeg = 9.0;

  // ── Audio ─────────────────────────────────────────────────────────────
  /// Background noise (median RMS dBFS) above which call timing is unreliable.
  static const maxNoiseFloorDb = -32.0;

  /// A caregiver call must rise this far above the noise floor.
  static const callOnsetAboveFloorDb = 12.0;

  /// ... and be at least this loud in absolute terms.
  static const callOnsetMinDb = -42.0;

  /// Consecutive 100 ms windows above threshold that count as a call onset.
  static const callOnsetWindows = 2;

  // ── Activity: Social Story ────────────────────────────────────────────
  static const socialStorySegmentMs = 20000;

  /// Fraction of segment samples that must be classified to a side.
  static const minClassifiedFractionPerSegment = 0.45;

  // ── Activity: Name Response ───────────────────────────────────────────
  static const nameTrials = 3;
  static const nameMaxAttempts = 5;

  /// The child must be facing the screen for this long before the prompt.
  static const nameAttentionMs = 1500;
  static const nameAttentionTimeoutMs = 9000;

  /// Head yaw (from the calibrated centre, or 0) within which the child counts
  /// as facing the screen before the prompt.
  static const nameFacingMaxYawDeg = 20.0;

  /// Consecutive attention timeouts after which the activity ends as
  /// non-participation instead of repeating.
  static const nameStopAfterAttentionTimeouts = 3;

  /// How long the caregiver prompt waits for a detected call.
  static const nameCallTimeoutMs = 7000;

  /// Window after the call in which an orienting head turn is looked for.
  static const nameResponseWindowMs = 5000;

  /// Yaw change from the pre-call baseline that counts as a head turn.
  static const nameHeadTurnDeg = 22.0;

  /// A smaller turn followed by the face leaving view (turning away) also counts.
  static const nameTurnAwayTrendDeg = 10.0;
  static const nameFaceLostMs = 400;

  // ── Activity: Follow My Look ──────────────────────────────────────────
  static const lookTrials = 4;
  static const lookPreCueMs = 1500;
  static const lookCueMs = 700;
  static const lookWindowMs = 4000;
  static const lookCenterTimeoutMs = 7000;
  static const lookRewardMs = 900;
  static const minFaceFractionInWindow = 0.5;

  // ── Activity: Bubble Trail ────────────────────────────────────────────
  static const bubbleDurationMs = 40000;
  static const bubbleLifetimeMs = 4200;
  static const bubbleSpawnEveryMs = 1300;
  static const bubbleMaxConcurrent = 3;

  /// Extra touch tolerance around a bubble, in logical pixels.
  static const bubbleHitSlopPx = 14.0;

  /// A miss followed by a hit within this time is a correction.
  static const bubbleCorrectionMs = 1000;
  static const bubbleInactivityHintMs = 10000;
  static const bubbleInactivityStopMs = 22000;

  /// More simultaneous pointers than this is treated as a palm/contact artefact.
  static const maxSimultaneousPointers = 2;
  static const bubbleMinHits = 3;
  static const bubbleMinTouches = 5;

  // ── Activity: Copy Me ─────────────────────────────────────────────────
  static const copyDemoMs = 3500;
  static const copyWindowMs = 6500;
  static const copyFramingTimeoutMs = 9000;
  static const minPoseLikelihood = 0.5;

  /// Consecutive pose frames that must agree before an action is detected.
  static const copyActionFrames = 2;

  /// Distances below are in units of the child's shoulder width.
  /// Wrists this far apart then this close within [clapWindowMs] = a clap.
  static const clapOpenRatio = 0.95;
  static const clapClosedRatio = 0.55;
  static const clapWindowMs = 1500;

  /// Both wrists at least this far above the nose = hands up.
  static const handsUpAboveNoseRatio = 0.35;

  /// A wrist within this distance of the nose and not below it = touching head.
  static const touchHeadDistanceRatio = 1.0;
  static const touchHeadBelowNoseTolerance = 0.15;

  // ── Activity: Switch It ───────────────────────────────────────────────
  static const switchMinAgeMonths = 24;
  static const switchTrialsPerRule = 5;
  static const switchTrialTimeoutMs = 6000;
  static const switchStopAfterOmissions = 4;
  static const switchMinResponsesPerRule = 3;

  // ── Interpretation ────────────────────────────────────────────────────
  /// Spec §8: too few valid activities → inconclusive.
  static const minValidActivities = 3;

  /// Of the evidence-backed constructs (Social Story, Name Response,
  /// Follow My Look), at least this many must be valid.
  static const minValidEvidenceBackedActivities = 2;
  static const minValidTrialsForPattern = 2;
}

/// Short alias used throughout the measurement code.
typedef P = PrototypeParameters;
