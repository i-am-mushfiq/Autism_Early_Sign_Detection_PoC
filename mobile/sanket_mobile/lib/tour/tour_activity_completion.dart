import '../core/measurement.dart';
import '../core/activity_catalog.dart';
import '../runtime/activity_controller.dart';
import 'tour_sensor_hub.dart';

/// Complete only a scripted demonstration, never a real child observation.
/// With no measured data all modalities remain excluded and the example
/// summary is Inconclusive, rather than interpreting non-participation.
void completeTourActivity(ActivityController activity) {
  final hub = activity.ctx.sensors;
  if (hub is! TourSensorHub || !hub.scripted) {
    throw StateError('Tour completion requires scripted sensors');
  }
  activity.cancelAttempt();
  activity.result = ActivityObservation(
    activity: activity.id,
    status: ActivityStatus.insufficient,
    reason: ReasonCode.tooFewValidTrials,
    attempt: activity.ctx.attempt,
    quality: [
      for (final modality in activity.id.definition.modalities)
        ModalityQuality(modality, QualityStatus.excluded,
            reason: ReasonCode.tooFewValidTrials),
    ],
  );
  activity.phase = ActivityPhase.done;
  activity.notify();
}
