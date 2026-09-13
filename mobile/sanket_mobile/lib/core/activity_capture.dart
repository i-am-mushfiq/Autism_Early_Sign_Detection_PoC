import 'activity_catalog.dart';
import 'calibration.dart';
import 'measurement.dart';
import 'samples.dart';

/// Which input hardware the session can use. Decided once, after consent and
/// permission requests.
class SensorAvailability {
  const SensorAvailability({
    required this.camera,
    required this.microphone,
    this.cameraDenied = false,
    this.microphoneDenied = false,
  });
  final bool camera, microphone, cameraDenied, microphoneDenied;

  static const none = SensorAvailability(camera: false, microphone: false);
  static const all = SensorAvailability(camera: true, microphone: true);
}

/// Everything recorded while one activity attempt ran: derived sensor samples
/// and the activity's own timeline events. Analyzers are pure functions of this.
class ActivityCapture {
  ActivityCapture({
    required this.activity,
    required this.startMs,
    required this.endMs,
    required this.sensors,
    required this.calibration,
    this.frames = const [],
    this.audio = const [],
    this.events = const [],
    this.attempt = 1,
    this.endedBy,
  });

  final ActivityId activity;
  final int startMs, endMs;
  final SensorAvailability sensors;
  final CalibrationResult calibration;
  final List<VisionFrame> frames;
  final List<AudioLevel> audio;
  final List<ActivityEvent> events;
  final int attempt;

  /// Set when the attempt did not run to its natural end.
  final ReasonCode? endedBy;

  int get durationMs => endMs - startMs;

  Iterable<ActivityEvent> eventsOf(String type) =>
      events.where((e) => e.type == type);

  /// Events grouped by trial: each group starts at a [startType] event and
  /// runs until the next one (or the end of the capture).
  List<List<ActivityEvent>> trials(String startType) {
    final groups = <List<ActivityEvent>>[];
    for (final e in events) {
      if (e.type == startType) {
        groups.add([e]);
      } else if (groups.isNotEmpty) {
        groups.last.add(e);
      }
    }
    return groups;
  }
}

abstract class ActivityAnalyzer {
  ActivityObservation analyze(ActivityCapture capture);
}

ActivityEvent? firstOf(List<ActivityEvent> events, String type) {
  for (final e in events) {
    if (e.type == type) return e;
  }
  return null;
}
