import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/measurement.dart';
import '../../core/prototype_parameters.dart';

/// Bubble Trail — visual-motor interaction (spec §7, "Promising").
///
/// Bubbles drift across the board and the child pops them by touch. Measured
/// from real touch telemetry: reaction time, endpoint error, missed targets,
/// corrections and reaction-time variability. Palm-like multi-touch contacts
/// are rejected before measurement.
class BubbleTrailAnalyzer implements ActivityAnalyzer {
  const BubbleTrailAnalyzer();

  static const spawn = 'bubble_spawn'; // {id}
  static const pop = 'bubble_pop'; // {id, rtMs, errorNorm}
  static const miss = 'tap_miss'; // {distanceNorm}
  static const expire = 'bubble_expire'; // {id}
  static const rejected = 'touch_rejected'; // {pointers}
  static const inactivityStop = 'inactivity_stop';

  @override
  ActivityObservation analyze(ActivityCapture c) {
    final pops = c.eventsOf(pop).toList();
    final misses = c.eventsOf(miss).toList();
    final rejectedCount = c.eventsOf(rejected).length;
    final touches = pops.length + misses.length;
    final rts = [for (final p in pops) p.get<int>('rtMs')];
    final errors = [
      for (final p in pops) (p.data['errorNorm'] as num).toDouble()
    ];

    var corrections = 0;
    for (final m in misses) {
      if (pops
          .any((p) => p.tMs > m.tMs && p.tMs - m.tMs <= P.bubbleCorrectionMs)) {
        corrections++;
      }
    }

    final allTouches = touches + rejectedCount;
    final palmShare = allTouches == 0 ? 0.0 : rejectedCount / allTouches;
    final touch = ModalityQuality(
        Modality.touch,
        touches == 0
            ? QualityStatus.excluded
            : palmShare > 0.5
                ? QualityStatus.limited
                : QualityStatus.valid,
        reason: touches == 0
            ? ReasonCode.noTouches
            : palmShare > 0.5
                ? ReasonCode.palmContact
                : null,
        value: touches.toDouble());

    final enough =
        touches >= P.bubbleMinTouches && pops.length >= P.bubbleMinHits;
    final rel = enough && touch.status == QualityStatus.valid
        ? Reliability.adequate
        : Reliability.limited;
    final rtMean = mean(rts);
    final rtSd = standardDeviation(rts);
    final features = <Feature>[
      Feature('bubbles_popped', pops.length.toDouble(), Modality.touch,
          unit: 'count'),
      Feature('touches', touches.toDouble(), Modality.touch, unit: 'count'),
      Feature('bubbles_missed', c.eventsOf(expire).length.toDouble(),
          Modality.touch,
          unit: 'count'),
      if (touches > 0)
        Feature('hit_rate', pops.length / touches, Modality.touch,
            unit: 'ratio', reliability: rel),
      if (rts.isNotEmpty)
        Feature('median_reaction_ms', median(rts)!, Modality.touch,
            unit: 'ms', reliability: rel),
      if (rtMean != null && rtSd != null && rts.length >= 3 && rtMean > 0)
        Feature('reaction_time_cv', rtSd / rtMean, Modality.touch,
            unit: 'ratio', reliability: rel),
      if (errors.isNotEmpty)
        Feature('mean_endpoint_error', mean(errors)!, Modality.touch,
            unit: 'bubble radii', reliability: rel),
      Feature('corrections', corrections.toDouble(), Modality.touch,
          unit: 'count'),
      if (rejectedCount > 0)
        Feature('rejected_touches', rejectedCount.toDouble(), Modality.touch,
            unit: 'count'),
    ];

    final status = touches == 0
        ? ActivityStatus.nonParticipation
        : enough
            ? ActivityStatus.valid
            : ActivityStatus.insufficient;
    return ActivityObservation(
      activity: ActivityId.bubbleTrail,
      status: status,
      reason: switch (status) {
        ActivityStatus.nonParticipation => ReasonCode.noParticipation,
        ActivityStatus.insufficient => c.endedBy ?? ReasonCode.tooFewTouches,
        _ => null,
      },
      quality: [touch],
      features: features,
      attempt: c.attempt,
      durationMs: c.durationMs,
    );
  }
}
