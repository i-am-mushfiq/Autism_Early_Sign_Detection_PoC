import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/calibration.dart';
import '../../core/measurement.dart';
import '../../core/prototype_parameters.dart';
import '../../core/quality.dart';
import '../../core/samples.dart';

/// Follow My Look — joint attention (spec §7).
///
/// The guide in the centre looks toward one of two distant, static toys. The
/// target never moves or sounds, so a look toward it follows the guide's gaze
/// rather than an attention-grabbing cue. Measured: first coarse-gaze target
/// after the cue, acquisition latency, and (secondary) which toy the child taps.
class FollowMyLookAnalyzer implements ActivityAnalyzer {
  const FollowMyLookAnalyzer();

  static const trialStart = 'trial_start'; // {index, side: left|right}
  static const centerTimeout = 'center_timeout';
  static const cue = 'cue'; // {side}
  static const tap = 'tap'; // {side}
  static const trialEnd = 'trial_end';

  @override
  ActivityObservation analyze(ActivityCapture c) {
    final camera =
        assessCamera(c.frames, c.durationMs, available: c.sensors.camera);
    final lighting = assessLighting(c.frames);
    final face = assessFace(c.frames, minFraction: 0.35);
    final gaze = c.calibration.quality;
    final taps = c.eventsOf(tap).length;
    final touch = ModalityQuality(Modality.touch,
        taps > 0 ? QualityStatus.valid : QualityStatus.unavailable,
        reason: taps > 0 ? null : ReasonCode.noTouches, value: taps.toDouble());
    final quality = [camera, lighting, face, gaze, touch];

    final classifier = gaze.usable && camera.usable
        ? CoarseGazeClassifier(c.calibration)
        : null;
    final trials = [
      for (final g in c.trials(trialStart)) _trial(c, g, classifier)
    ];
    final valid = trials.where((t) => t.valid).toList();
    final followed =
        valid.where((t) => t.measures['followed'] == true).toList();
    final latencies = [
      for (final t in followed) t.measures['latencyMs'] as int
    ];
    final tapTrials =
        trials.where((t) => t.measures['tapCorrect'] != null).toList();

    final features = <Feature>[
      Feature('valid_trials', valid.length.toDouble(), Modality.gaze,
          unit: 'count'),
      if (valid.isNotEmpty)
        Feature('follow_rate', followed.length / valid.length, Modality.gaze,
            unit: 'ratio',
            reliability: valid.length >= P.minValidTrialsForPattern
                ? Reliability.adequate
                : Reliability.limited),
      if (latencies.isNotEmpty)
        Feature('median_latency_ms', median(latencies)!, Modality.gaze,
            unit: 'ms',
            reliability: latencies.length >= 2
                ? Reliability.adequate
                : Reliability.limited),
      if (tapTrials.isNotEmpty)
        Feature(
            'tap_correct_rate',
            tapTrials.where((t) => t.measures['tapCorrect'] == true).length /
                tapTrials.length,
            Modality.touch,
            unit: 'ratio',
            reliability: Reliability.limited),
    ];

    ActivityObservation result(ActivityStatus s,
            {ReasonCode? reason, List<PatternNote> notes = const []}) =>
        ActivityObservation(
            activity: ActivityId.followMyLook,
            status: s,
            reason: reason,
            quality: quality,
            features: features,
            trials: trials,
            notes: notes,
            attempt: c.attempt,
            durationMs: c.durationMs);

    if (valid.length >= P.minValidTrialsForPattern) {
      return result(ActivityStatus.valid,
          notes:
              followed.isEmpty ? const [PatternNote.lookNoFollow] : const []);
    }
    if (trials.isNotEmpty &&
        taps == 0 &&
        trials.every((t) => t.reason == ReasonCode.notAttendingBeforePrompt)) {
      return result(ActivityStatus.nonParticipation,
          reason: ReasonCode.noParticipation);
    }
    final reason = !camera.usable
        ? camera.reason
        : !lighting.usable
            ? lighting.reason
            : !gaze.usable
                ? gaze.reason
                : c.endedBy ?? ReasonCode.tooFewValidTrials;
    return result(ActivityStatus.insufficient, reason: reason);
  }

  TrialResult _trial(ActivityCapture c, List<ActivityEvent> group,
      CoarseGazeClassifier? classifier) {
    final index = group.first.get<int>('index');
    final side = group.first.get<String>('side');
    final tapEvent = firstOf(group, tap);
    final tapMeasures = <String, Object?>{
      'side': side,
      'tapCorrect':
          tapEvent == null ? null : tapEvent.get<String>('side') == side,
    };
    TrialResult invalid(ReasonCode r) => TrialResult(index, TrialStatus.invalid,
        reason: r, measures: tapMeasures);

    if (firstOf(group, centerTimeout) != null)
      return invalid(ReasonCode.notAttendingBeforePrompt);
    final cueEvent = firstOf(group, cue);
    if (cueEvent == null) return invalid(c.endedBy ?? ReasonCode.stoppedEarly);
    if (classifier == null)
      return invalid(
          c.calibration.reason ?? ReasonCode.gazeCalibrationUnusable);
    final tCue = cueEvent.tMs;

    final pre = framesBetween(c.frames, tCue - 800, tCue);
    final preUsable = pre.where(usableGazeFrame).toList();
    if (pre.isEmpty || preUsable.length / pre.length < 0.5) {
      return invalid(ReasonCode.notAttendingBeforePrompt);
    }
    final preRegions = [
      for (final f in preUsable)
        if (classifier.classify(f) != GazeRegion.uncertain)
          classifier.classify(f)
    ];
    if (preRegions.isNotEmpty && preRegions.last.name == side) {
      return invalid(ReasonCode.alreadyLookingAtTarget);
    }

    final window = [
      for (final f in c.frames)
        if (f.tMs > tCue && f.tMs <= tCue + P.lookWindowMs) f
    ];
    final look = firstSideLook(window, classifier);
    if (look == null) {
      final usable = window.where(usableGazeFrame).length;
      if (window.isEmpty ||
          usable / window.length < P.minFaceFractionInWindow) {
        return invalid(ReasonCode.faceNotVisible);
      }
    }
    return TrialResult(index, TrialStatus.valid, measures: {
      ...tapMeasures,
      'firstLook': look?.$1.name,
      'followed': look != null && look.$1.name == side,
      'latencyMs': look == null ? null : look.$2 - tCue,
    });
  }
}

/// First left/right region held for two consecutive classified frames, with
/// the time of the first of them.
(GazeRegion, int)? firstSideLook(
    List<VisionFrame> window, CoarseGazeClassifier classifier) {
  GazeRegion? previous;
  int? previousT;
  for (final f in window) {
    final r = classifier.classify(f);
    if (r == GazeRegion.uncertain) continue;
    if ((r == GazeRegion.left || r == GazeRegion.right) && r == previous) {
      return (r, previousT!);
    }
    previous = r;
    previousT = f.tMs;
  }
  return null;
}
