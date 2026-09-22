import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/measurement.dart';
import '../../core/prototype_parameters.dart';
import '../../core/quality.dart';
import '../../core/samples.dart';
import 'pose_actions.dart';

/// Copy Me — imitation (spec §7, "Emerging").
///
/// The guide demonstrates an action (hands up, clap, touch head); the child's
/// upper-body pose is then tracked on-device during a response window.
/// Measured: whether the demonstrated action (or another action) appears,
/// onset latency and rough fidelity. Trials where the child's upper body is not
/// visible are excluded rather than treated as "no imitation".
class CopyMeAnalyzer implements ActivityAnalyzer {
  const CopyMeAnalyzer({this.detector = const PoseActionDetector()});
  final PoseActionDetector detector;

  static const trialStart = 'trial_start'; // {index, action}
  static const framingTimeout = 'framing_timeout';
  static const windowStart = 'window_start';
  static const windowEnd = 'window_end';

  @override
  ActivityObservation analyze(ActivityCapture c) {
    final camera =
        assessCamera(c.frames, c.durationMs, available: c.sensors.camera);
    final lighting = assessLighting(c.frames);
    final trials = [for (final g in c.trials(trialStart)) _trial(c, g)];
    final windowsFramed = [
      for (final t in trials)
        if (t.measures['framedFraction'] != null)
          (t.measures['framedFraction'] as num).toDouble()
    ];
    final framed = mean(windowsFramed);
    final pose = ModalityQuality(
        Modality.pose,
        framed == null
            ? QualityStatus.unavailable
            : framed >= 0.5
                ? QualityStatus.valid
                : QualityStatus.excluded,
        reason:
            framed == null || framed < 0.5 ? ReasonCode.bodyNotVisible : null,
        value: framed);
    final quality = [camera, lighting, pose];

    final valid = trials.where((t) => t.valid).toList();
    final matched = valid.where((t) => t.measures['matched'] == true).toList();
    final anyAction =
        valid.where((t) => t.measures['detected'] != null).toList();
    final latencies = [for (final t in matched) t.measures['latencyMs'] as int];
    final features = <Feature>[
      Feature('valid_trials', valid.length.toDouble(), Modality.pose,
          unit: 'count'),
      if (valid.isNotEmpty) ...[
        Feature('imitation_rate', matched.length / valid.length, Modality.pose,
            unit: 'ratio',
            reliability: valid.length >= P.minValidTrialsForPattern
                ? Reliability.adequate
                : Reliability.limited),
        Feature(
            'any_action_rate', anyAction.length / valid.length, Modality.pose,
            unit: 'ratio'),
        Feature(
            'rough_fidelity',
            mean(valid.map((t) => (t.measures['fidelity'] as num).toDouble()))!,
            Modality.pose,
            unit: '0–1',
            reliability: Reliability.limited),
      ],
      if (latencies.isNotEmpty)
        Feature('median_onset_ms', median(latencies)!, Modality.pose,
            unit: 'ms',
            reliability: latencies.length >= 2
                ? Reliability.adequate
                : Reliability.limited),
    ];

    ActivityObservation result(ActivityStatus s,
            {ReasonCode? reason, List<PatternNote> notes = const []}) =>
        ActivityObservation(
            activity: ActivityId.copyMe,
            status: s,
            reason: reason,
            quality: quality,
            features: features,
            trials: trials,
            notes: notes,
            attempt: c.attempt,
            durationMs: c.durationMs);

    if (!camera.usable)
      return result(ActivityStatus.insufficient, reason: camera.reason);
    if (valid.length >= P.minValidTrialsForPattern) {
      return result(ActivityStatus.valid,
          notes:
              matched.isEmpty ? const [PatternNote.copyNoImitation] : const []);
    }
    if (!lighting.usable)
      return result(ActivityStatus.insufficient, reason: lighting.reason);
    return result(ActivityStatus.insufficient,
        reason: c.endedBy ??
            (trials.isNotEmpty &&
                    trials.every((t) => t.reason == ReasonCode.bodyNotVisible)
                ? ReasonCode.bodyNotVisible
                : ReasonCode.tooFewValidTrials));
  }

  TrialResult _trial(ActivityCapture c, List<ActivityEvent> group) {
    final index = group.first.get<int>('index');
    final target = CopyAction.values.byName(group.first.get<String>('action'));
    if (firstOf(group, framingTimeout) != null) {
      return TrialResult(index, TrialStatus.invalid,
          reason: ReasonCode.bodyNotVisible, measures: {'action': target.name});
    }
    final start = firstOf(group, windowStart);
    final end = firstOf(group, windowEnd);
    if (start == null || end == null) {
      return TrialResult(index, TrialStatus.invalid,
          reason: c.endedBy ?? ReasonCode.stoppedEarly,
          measures: {'action': target.name});
    }
    final window = framesBetween(c.frames, start.tMs, end.tMs);
    final framed = window.isEmpty
        ? 0.0
        : window.where((f) => PoseActionDetector.framingOk(f.pose)).length /
            window.length;
    final detected = detector.detect(window);
    // A detected action proves the body was measurable even if framing dipped.
    if (detected == null && framed < 0.5) {
      return TrialResult(index, TrialStatus.invalid,
          reason: ReasonCode.bodyNotVisible,
          measures: {'action': target.name, 'framedFraction': framed});
    }
    final matched = detected?.action == target;
    return TrialResult(index, TrialStatus.valid, measures: {
      'action': target.name,
      'framedFraction': framed,
      'detected': detected?.action.name,
      'matched': matched,
      'latencyMs': detected == null ? null : detected.tMs - start.tMs,
      'fidelity': matched
          ? 1.0
          : detected != null
              ? 0.5
              : 0.0,
    });
  }
}
