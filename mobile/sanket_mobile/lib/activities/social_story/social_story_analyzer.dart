import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/calibration.dart';
import '../../core/measurement.dart';
import '../../core/prototype_parameters.dart';
import '../../core/quality.dart';

/// Social Story — social attention (spec §7).
///
/// A short story shows a talking, waving guide (social area) on one side and a
/// turning toy (non-social area) on the other. Sides swap between the two
/// segments so a side preference is not mistaken for a social preference.
/// Measured: share of calibrated coarse-gaze samples on the social side,
/// side transitions, and on-screen attention.
class SocialStoryAnalyzer implements ActivityAnalyzer {
  const SocialStoryAnalyzer();

  static const segmentStart =
      'segment_start'; // {index, socialSide: left|right}
  static const segmentEnd = 'segment_end';

  @override
  ActivityObservation analyze(ActivityCapture c) {
    final camera =
        assessCamera(c.frames, c.durationMs, available: c.sensors.camera);
    final lighting = assessLighting(c.frames);
    final face = assessFace(c.frames, minFraction: 0.35);
    final gaze = c.calibration.quality;
    final quality = [camera, lighting, face, gaze];

    ActivityObservation result(ActivityStatus s,
            {ReasonCode? reason,
            List<Feature> features = const [],
            List<TrialResult> trials = const [],
            List<PatternNote> notes = const []}) =>
        ActivityObservation(
            activity: ActivityId.socialStory,
            status: s,
            reason: reason ?? c.endedBy,
            quality: quality,
            features: features,
            trials: trials,
            notes: notes,
            attempt: c.attempt,
            durationMs: c.durationMs);

    if (!camera.usable)
      return result(ActivityStatus.insufficient, reason: camera.reason);
    if (!lighting.usable)
      return result(ActivityStatus.insufficient, reason: lighting.reason);

    final attention = c.frames.isEmpty
        ? 0.0
        : c.frames.where(usableFaceFrame).length / c.frames.length;
    final attentionFeature = Feature(
        'screen_attention_fraction', attention, Modality.face,
        unit: 'ratio',
        reliability: gaze.usable ? Reliability.adequate : Reliability.limited);
    if (attention < 0.15) {
      return result(ActivityStatus.nonParticipation,
          reason: ReasonCode.noParticipation, features: [attentionFeature]);
    }
    if (!gaze.usable) {
      return result(ActivityStatus.insufficient,
          reason: gaze.reason, features: [attentionFeature]);
    }

    final classifier = CoarseGazeClassifier(c.calibration);
    final trials = <TrialResult>[];
    var socialTotal = 0, transitions = 0, classifiedFrames = 0;
    var framesTotal = 0, measuredMs = 0;
    final shares = <double>[];

    for (final group in c.trials(segmentStart)) {
      final start = group.first;
      final end = firstOf(group, segmentEnd);
      if (end == null) continue; // segment interrupted
      final index = start.get<int>('index');
      final socialSide = start.get<String>('socialSide') == 'left'
          ? GazeRegion.left
          : GazeRegion.right;
      final frames = framesBetween(c.frames, start.tMs, end.tMs);
      var social = 0, nonSocial = 0;
      GazeRegion? last;
      for (final f in frames) {
        final region = classifier.classify(f);
        if (region != GazeRegion.left && region != GazeRegion.right) continue;
        region == socialSide ? social++ : nonSocial++;
        if (last != null && last != region) transitions++;
        last = region;
      }
      final classified =
          frames.isEmpty ? 0.0 : (social + nonSocial) / frames.length;
      framesTotal += frames.length;
      measuredMs += end.tMs - start.tMs;
      final segmentValid = classified >= P.minClassifiedFractionPerSegment;
      final share =
          social + nonSocial == 0 ? null : social / (social + nonSocial);
      if (segmentValid) {
        socialTotal += social;
        classifiedFrames += social + nonSocial;
        shares.add(share!);
      }
      trials.add(TrialResult(
          index, segmentValid ? TrialStatus.valid : TrialStatus.invalid,
          reason: segmentValid ? null : ReasonCode.faceNotVisible,
          measures: {
            'socialSide': socialSide.name,
            'socialShare': share,
            'classifiedFraction': classified,
          }));
    }

    final valid = trials.where((t) => t.valid).length;
    final features = <Feature>[attentionFeature];
    if (classifiedFrames > 0) {
      features.add(Feature(
          'social_share', socialTotal / classifiedFrames, Modality.gaze,
          unit: 'ratio',
          reliability:
              valid == 2 ? Reliability.adequate : Reliability.limited));
      features.add(Feature('classified_fraction',
          framesTotal == 0 ? 0 : classifiedFrames / framesTotal, Modality.gaze,
          unit: 'ratio'));
      if (measuredMs > 0) {
        features.add(Feature('side_transitions_per_min',
            transitions * 60000 / measuredMs, Modality.gaze,
            unit: '/min'));
      }
    }

    // Both side-counterbalanced segments are required for a pattern.
    if (valid < 2) {
      return result(ActivityStatus.insufficient,
          reason: c.endedBy ?? ReasonCode.tooFewValidTrials,
          features: features,
          trials: trials);
    }
    final notes = shares.every((s) => s < 0.5)
        ? const [PatternNote.storyNonSocialPreference]
        : const <PatternNote>[];
    return result(ActivityStatus.valid,
        features: features, trials: trials, notes: notes);
  }
}
