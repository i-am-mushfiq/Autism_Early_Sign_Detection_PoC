import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../core/activity_capture.dart';
import '../core/activity_catalog.dart';
import '../core/calibration.dart';
import '../core/measurement.dart';
import '../core/samples.dart';
import '../core/session.dart';
import '../sensors/sensor_hub.dart';

class ActivityContext {
  ActivityContext({
    required this.sensors,
    required this.calibration,
    required this.profile,
    this.attempt = 1,
    this.allowAutomaticFinish = true,
    math.Random? random,
  }) : random = random ?? math.Random();

  final SensorHub sensors;
  final CalibrationResult calibration;
  final ChildProfile profile;
  final int attempt;
  final bool allowAutomaticFinish;
  final math.Random random;
}

enum ActivityPhase { intro, running, done }

/// Runs one attempt of one activity: owns the timeline, records derived
/// samples and events while running, and hands the capture to the activity's
/// pure analyzer when the attempt ends.
///
/// Subclasses implement the activity's interaction; they never compute
/// results themselves.
abstract class ActivityController extends ChangeNotifier {
  ActivityController(this.ctx);
  final ActivityContext ctx;

  ActivityId get id;
  ActivityAnalyzer get analyzer;
  VisionMode get visionMode => VisionMode.face;
  bool get needsAudio => false;
  bool get requiresCamera => true;

  /// Expected running time, for progress display.
  int get expectedDurationMs;

  ActivityPhase phase = ActivityPhase.intro;
  ActivityObservation? result;

  final List<VisionFrame> frames = [];
  final List<AudioLevel> audio = [];
  final List<ActivityEvent> events = [];

  int _startMs = 0;
  final _timers = <Timer>[];
  StreamSubscription<VisionFrame>? _frameSub;
  StreamSubscription<AudioLevel>? _audioSub;
  Timer? _ticker;
  bool _disposed = false;

  int get now => ctx.sensors.clock.nowMs();
  int get elapsedMs => phase == ActivityPhase.running ? now - _startMs : 0;
  double get progress => phase == ActivityPhase.done
      ? 1
      : phase == ActivityPhase.intro
          ? 0
          : (elapsedMs / expectedDurationMs).clamp(0.0, 0.98);

  /// Whether the device can run this activity at all.
  bool get canRun => !requiresCamera || ctx.sensors.availability.camera;

  void start() {
    if (phase == ActivityPhase.running) return;
    frames.clear();
    audio.clear();
    events.clear();
    result = null;
    _startMs = now;
    phase = ActivityPhase.running;
    if (!canRun) {
      finishWith(unavailableObservation());
      return;
    }
    ctx.sensors.mode = visionMode;
    if (visionMode != VisionMode.off) {
      _frameSub = ctx.sensors.frames.listen((f) {
        if (phase != ActivityPhase.running) return;
        frames.add(f);
        onFrame(f);
      });
    }
    if (needsAudio && ctx.sensors.availability.microphone) {
      _audioSub = ctx.sensors.audio.listen((a) {
        if (phase != ActivityPhase.running) return;
        audio.add(a);
        onAudio(a);
      });
    }
    _ticker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (phase == ActivityPhase.running) {
        onTick();
        notify();
      }
    });
    onStart();
    notify();
  }

  // ── Hooks ────────────────────────────────────────────────────────────
  void onStart();
  void onFrame(VisionFrame frame) {}
  void onAudio(AudioLevel level) {}
  void onTick() {}

  // ── Helpers for subclasses ───────────────────────────────────────────
  void record(String type, [Map<String, Object> data = const {}, int? atMs]) =>
      events.add(ActivityEvent(atMs ?? now, type, data));

  /// A timer that only fires while this attempt is still running.
  void after(int ms, void Function() action) {
    final attemptStart = _startMs;
    _timers.add(Timer(Duration(milliseconds: ms), () {
      if (phase == ActivityPhase.running &&
          _startMs == attemptStart &&
          !_disposed) {
        action();
        notify();
      }
    }));
  }

  void notify() {
    if (!_disposed) notifyListeners();
  }

  ActivityCapture capture({ReasonCode? endedBy}) => ActivityCapture(
        activity: id,
        startMs: _startMs,
        endMs: now,
        sensors: ctx.sensors.availability,
        calibration: ctx.calibration,
        frames: List.unmodifiable(frames),
        audio: List.unmodifiable(audio),
        events: List.unmodifiable(events),
        attempt: ctx.attempt,
        endedBy: endedBy,
      );

  ActivityObservation unavailableObservation() {
    final denied = !ctx.sensors.availability.camera &&
        ctx.sensors.availability.cameraDenied;
    final reason = denied
        ? ReasonCode.cameraPermissionDenied
        : ReasonCode.cameraUnavailable;
    return ActivityObservation(
        activity: id,
        status: ActivityStatus.insufficient,
        reason: reason,
        quality: [
          ModalityQuality(Modality.camera, QualityStatus.unavailable,
              reason: reason)
        ],
        attempt: ctx.attempt);
  }

  /// Ends the attempt normally (or early with [endedBy]) and analyzes it.
  ActivityObservation finish({ReasonCode? endedBy}) {
    // The tour owns completion timing so an inactivity timeout cannot cut its
    // preview short or turn an example into a child observation.
    if (!ctx.allowAutomaticFinish) {
      return ActivityObservation(
          activity: id,
          status: ActivityStatus.insufficient,
          reason: ReasonCode.tooFewValidTrials);
    }
    if (phase != ActivityPhase.running) return result!;
    final c = capture(endedBy: endedBy);
    _stopCapture();
    return finishWith(analyzer.analyze(c));
  }

  @protected
  ActivityObservation finishWith(ActivityObservation observation) {
    _stopCapture();
    result = observation;
    phase = ActivityPhase.done;
    notify();
    return observation;
  }

  /// Discards the running attempt (pause, app backgrounded). Back to intro.
  void cancelAttempt() {
    if (phase != ActivityPhase.running) return;
    _stopCapture();
    frames.clear();
    audio.clear();
    events.clear();
    phase = ActivityPhase.intro;
    onCancelled();
    notify();
  }

  void onCancelled() {}

  void _stopCapture() {
    for (final t in _timers) {
      t.cancel();
    }
    _timers.clear();
    _ticker?.cancel();
    _ticker = null;
    _frameSub?.cancel();
    _frameSub = null;
    _audioSub?.cancel();
    _audioSub = null;
    ctx.sensors.mode = VisionMode.off;
  }

  @override
  void dispose() {
    _stopCapture();
    _disposed = true;
    super.dispose();
  }
}
