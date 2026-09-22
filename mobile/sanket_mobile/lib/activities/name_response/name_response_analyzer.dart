import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/measurement.dart';
import '../../core/prototype_parameters.dart';
import '../../core/quality.dart';
import '../../core/samples.dart';

/// Name Response — social orienting (spec §7).
///
/// While the child watches a calm scene, the caregiver (off-axis, beside the
/// child) is prompted to call the child's familiar name once. The microphone
/// times the call; the front camera measures whether and when the head turns
/// away from the screen toward the caregiver, and whether the child re-engages.
class NameResponseAnalyzer implements ActivityAnalyzer {
  const NameResponseAnalyzer();

  static const trialStart = 'trial_start'; // {index}
  static const attentionTimeout = 'attention_timeout';

  /// {source: audio|caregiver, floorDb?}
  static const call = 'call';
  static const callTimeout = 'call_timeout';
  static const trialEnd = 'trial_end';

  @override
  ActivityObservation analyze(ActivityCapture c) {
    final camera =
        assessCamera(c.frames, c.durationMs, available: c.sensors.camera);
    final lighting = assessLighting(c.frames);
    final face = assessFace(c.frames, minFraction: 0.35);
    final floors = [
      for (final e in c.eventsOf(call))
        if (e.data['floorDb'] != null) (e.data['floorDb'] as num).toDouble()
    ];
    final audio = !c.sensors.microphone
        ? ModalityQuality(Modality.audio, QualityStatus.unavailable,
            reason: c.sensors.microphoneDenied
                ? ReasonCode.microphonePermissionDenied
                : ReasonCode.microphoneUnavailable)
        : floors.isEmpty
            ? const ModalityQuality(Modality.audio, QualityStatus.excluded,
                reason: ReasonCode.callNotDetected)
            : ModalityQuality(
                Modality.audio,
                c.eventsOf(call).every((e) => e.data['source'] == 'audio')
                    ? QualityStatus.valid
                    : QualityStatus.limited,
                reason:
                    c.eventsOf(call).every((e) => e.data['source'] == 'audio')
                        ? null
                        : ReasonCode.callTimedByCaregiver,
                value: median(floors));
    final quality = [camera, lighting, face, audio];

    final trials = <TrialResult>[];
    for (final group in c.trials(trialStart)) {
      trials.add(_trial(c, group));
    }

    final valid = trials.where((t) => t.valid).toList();
    final responded =
        valid.where((t) => t.measures['responded'] == true).toList();
    final audioLatencies = [
      for (final t in responded)
        if (t.measures['timing'] == 'audio') t.measures['latencyMs'] as int
    ];
    final features = <Feature>[
      Feature('valid_trials', valid.length.toDouble(), Modality.face,
          unit: 'count'),
      if (valid.isNotEmpty)
        Feature('response_rate', responded.length / valid.length, Modality.face,
            unit: 'ratio',
            reliability: valid.length >= P.minValidTrialsForPattern
                ? Reliability.adequate
                : Reliability.limited),
      if (audioLatencies.isNotEmpty)
        Feature('median_latency_ms', median(audioLatencies)!, Modality.audio,
            unit: 'ms',
            reliability: audioLatencies.length >= 2
                ? Reliability.adequate
                : Reliability.limited),
      if (responded.isNotEmpty)
        Feature(
            'reengaged_rate',
            responded.where((t) => t.measures['reengaged'] == true).length /
                responded.length,
            Modality.face,
            unit: 'ratio'),
    ];

    ActivityObservation result(ActivityStatus s,
            {ReasonCode? reason, List<PatternNote> notes = const []}) =>
        ActivityObservation(
            activity: ActivityId.nameResponse,
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
          notes: responded.isEmpty
              ? const [PatternNote.nameNoOrienting]
              : const []);
    }
    if (trials.isNotEmpty &&
        trials.every((t) => t.reason == ReasonCode.notAttendingBeforePrompt)) {
      return result(ActivityStatus.nonParticipation,
          reason: ReasonCode.noParticipation);
    }
    return result(ActivityStatus.insufficient,
        reason: c.endedBy ??
            _dominantReason(trials) ??
            ReasonCode.tooFewValidTrials);
  }

  TrialResult _trial(ActivityCapture c, List<ActivityEvent> group) {
    final index = group.first.get<int>('index');
    TrialResult invalid(ReasonCode r) =>
        TrialResult(index, TrialStatus.invalid, reason: r);
    if (firstOf(group, attentionTimeout) != null) {
      return invalid(ReasonCode.notAttendingBeforePrompt);
    }
    if (firstOf(group, callTimeout) != null)
      return invalid(ReasonCode.callNotDetected);
    final callEvent = firstOf(group, call);
    if (callEvent == null) return invalid(c.endedBy ?? ReasonCode.stoppedEarly);
    final tCall = callEvent.tMs;
    final source = callEvent.get<String>('source');

    final pre = framesBetween(c.frames, tCall - P.nameAttentionMs, tCall);
    final preUsable = pre.where(usableFaceFrame).toList();
    if (pre.isEmpty ||
        preUsable.length / pre.length < P.nameMinAttentionFraction) {
      return invalid(ReasonCode.notAttendingBeforePrompt);
    }
    final baseline = median(preUsable.map((f) => f.face!.yawDeg))!;

    final window = [
      for (final f in c.frames)
        if (f.tMs > tCall && f.tMs <= tCall + P.nameResponseWindowMs) f
    ];
    final response = detectOrientingTurn(window, baseline);
    if (response == null) {
      final usable = window.where(usableFaceFrame).length;
      if (window.isEmpty ||
          usable / window.length < P.minFaceFractionInWindow) {
        return invalid(ReasonCode.faceLostWithoutTurn);
      }
    }
    var reengaged = false;
    if (response != null) {
      reengaged = window.any((f) =>
          f.tMs > response &&
          usableFaceFrame(f) &&
          (f.face!.yawDeg - baseline).abs() < P.nameTurnAwayTrendDeg);
    }
    return TrialResult(index, TrialStatus.valid, measures: {
      'responded': response != null,
      'latencyMs': response == null ? null : response - tCall,
      'timing': source,
      'reengaged': reengaged,
      'baselineYaw': baseline,
    });
  }

  ReasonCode? _dominantReason(List<TrialResult> trials) {
    final counts = <ReasonCode, int>{};
    for (final t in trials) {
      if (t.reason != null) counts[t.reason!] = (counts[t.reason!] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

/// Time of an orienting head turn after a call, or null.
///
/// A turn is a usable frame whose yaw departs from the pre-call [baselineYaw] by
/// [P.nameHeadTurnDeg], or the face leaving view for [P.nameFaceLostMs] right
/// after turning at least [P.nameTurnAwayTrendDeg] (a turn beyond the range
/// the face tracker can follow). Losing the face without a preceding turn —
/// e.g. the child leaving or the camera being covered — is not a response.
int? detectOrientingTurn(List<VisionFrame> window, double baselineYaw) {
  double lastDelta = 0;
  int? lostSince;
  double deltaBeforeLoss = 0;
  for (final f in window) {
    final lit = f.lighting >= P.minLighting && f.lighting <= P.maxLighting;
    if (f.face == null && lit) {
      if (lostSince == null) {
        lostSince = f.tMs;
        deltaBeforeLoss = lastDelta;
      }
      if (f.tMs - lostSince >= P.nameFaceLostMs &&
          deltaBeforeLoss >= P.nameTurnAwayTrendDeg) {
        return lostSince;
      }
      continue;
    }
    lostSince = null;
    if (!usableFaceFrame(f)) continue;
    lastDelta = (f.face!.yawDeg - baselineYaw).abs();
    if (lastDelta >= P.nameHeadTurnDeg) return f.tMs;
  }
  return null;
}
