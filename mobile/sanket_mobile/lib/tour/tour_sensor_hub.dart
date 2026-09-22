import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/activity_capture.dart';
import '../core/samples.dart';
import '../presentation/widgets/guide_figure.dart';
import '../sensors/sensor_hub.dart';

/// A sensor hub that plays back a well-behaved simulated child instead of a
/// real camera and microphone, so the caregiver-facing app can be walked
/// through end to end for a demo audience without needing an actual child in
/// front of the device (spec §16 demo conditions). Every activity's own
/// quality gates, calibration and timing still run unmodified — this only
/// supplies the underlying signal they measure.
class TourSensorHub implements SensorHub {
  TourSensorHub({this.scripted = false});
  final bool scripted;

  @override
  final SessionClock clock = StopwatchClock();

  final _frames = StreamController<VisionFrame>.broadcast();
  late final StreamController<AudioLevel> _audio =
      StreamController<AudioLevel>.broadcast(
          onListen: _startAudio, onCancel: _stopAudio);

  Timer? _frameTimer;
  Timer? _audioTimer;
  VisionMode _mode = VisionMode.off;
  SensorAvailability _availability = SensorAvailability.none;

  @override
  SensorAvailability get availability => _availability;

  @override
  VisionMode get mode => _mode;
  @override
  set mode(VisionMode value) {
    _mode = value;
    _frameTimer?.cancel();
    if (value != VisionMode.off && !scripted) {
      _frameTimer =
          Timer.periodic(const Duration(milliseconds: 66), (_) => _emitFrame());
    }
  }

  @override
  Stream<VisionFrame> get frames => _frames.stream;
  @override
  Stream<AudioLevel> get audio => _audio.stream;

  @override
  Future<SensorAvailability> start(
      {required bool camera, required bool microphone}) async {
    _availability = SensorAvailability(camera: camera, microphone: microphone);
    return _availability;
  }

  @override
  Widget? preview() => const TourChildPreview();

  @override
  Future<void> refreshAfterOrientationChange() async {}

  void _startAudio() {
    if (scripted) return;
    _audioTimer ??=
        Timer.periodic(const Duration(milliseconds: 100), (_) => _emitAudio());
  }

  void _stopAudio() {
    _audioTimer?.cancel();
    _audioTimer = null;
  }

  // ── Simulated head orientation ──────────────────────────────────────────
  // A repeating look pattern that holds centre, left, right and up (for
  // calibration) each long enough for calibration and the cued activities to
  // register a clear response.
  static const _gazeCycle = [
    (yaw: 0.0, pitch: 0.0, ms: 2200),
    (yaw: 24.0, pitch: 0.0, ms: 2200),
    (yaw: -24.0, pitch: 0.0, ms: 2200),
    (yaw: 0.0, pitch: -20.0, ms: 2200),
    (yaw: 0.0, pitch: 0.0, ms: 1800),
    (yaw: 24.0, pitch: 0.0, ms: 1800),
    (yaw: -24.0, pitch: 0.0, ms: 1800),
  ];
  static final int _gazeCycleMs = _gazeCycle.fold(0, (sum, s) => sum + s.ms);

  (double, double) _gazeAt(int t) {
    var pos = t % _gazeCycleMs;
    for (final stage in _gazeCycle) {
      if (pos < stage.ms) return (stage.yaw, stage.pitch);
      pos -= stage.ms;
    }
    return (0, 0);
  }

  // ── Simulated pose ───────────────────────────────────────────────────────
  static PoseObservation _pose(
          {required double lwx,
          required double lwy,
          required double rwx,
          required double rwy}) =>
      PoseObservation({
        PosePoint.nose: const PoseLandmark(.5, .30, .95),
        PosePoint.leftShoulder: const PoseLandmark(.40, .50, .95),
        PosePoint.rightShoulder: const PoseLandmark(.60, .50, .95),
        PosePoint.leftWrist: PoseLandmark(lwx, lwy, .9),
        PosePoint.rightWrist: PoseLandmark(rwx, rwy, .9),
      });

  static final _resting = _pose(lwx: .35, lwy: .75, rwx: .65, rwy: .75);
  static final _handsUp = _pose(lwx: .35, lwy: .15, rwx: .65, rwy: .15);
  static final _handsApart = _pose(lwx: .30, lwy: .6, rwx: .70, rwy: .6);
  static final _handsTogether = _pose(lwx: .49, lwy: .6, rwx: .51, rwy: .6);
  static final _touchHead = _pose(lwx: .35, lwy: .75, rwx: .55, rwy: .22);

  static final _poseCycle = [
    (pose: _resting, ms: 1500),
    (pose: _handsUp, ms: 1500),
    (pose: _handsApart, ms: 700),
    (pose: _handsTogether, ms: 700),
    (pose: _touchHead, ms: 1500),
    (pose: _resting, ms: 1500),
  ];
  static final int _poseCycleMs = _poseCycle.fold(0, (sum, s) => sum + s.ms);

  PoseObservation _poseAt(int t) {
    var pos = t % _poseCycleMs;
    for (final stage in _poseCycle) {
      if (pos < stage.ms) return stage.pose;
      pos -= stage.ms;
    }
    return _resting;
  }

  void _emitFrame() {
    if (_frames.isClosed) return;
    final t = clock.nowMs();
    FaceObservation? face;
    PoseObservation? pose;
    if (_mode == VisionMode.face) {
      final (baseYaw, basePitch) = _gazeAt(t);
      final jitter = 2 * math.sin(t / 97);
      final blinking = t % 4000 < 120;
      face = FaceObservation(
        yawDeg: baseYaw + jitter,
        pitchDeg: basePitch,
        widthFraction: 0.28,
        centerX: .5,
        centerY: .5,
        leftEyeOpen: blinking ? 0.05 : 0.9,
        rightEyeOpen: blinking ? 0.05 : 0.9,
      );
    } else if (_mode == VisionMode.pose) {
      pose = _poseAt(t);
    }
    _frames.add(VisionFrame(
        tMs: t, mode: _mode, lighting: 0.5, face: face, pose: pose));
  }

  void _emitAudio() {
    if (_audio.isClosed) return;
    final t = clock.nowMs();
    final loud = t % 3600 < 260;
    _audio.add(
        AudioLevel(tMs: t, rmsDb: loud ? -20 : -55, peakDb: loud ? -10 : -45));
  }

  @override
  Future<void> dispose() async {
    _mode = VisionMode.off;
    _frameTimer?.cancel();
    _stopAudio();
    await _frames.close();
    await _audio.close();
  }
}

/// Shown instead of a real camera preview during the tour: a friendly
/// character standing in for the child, so the caregiver panel never shows a
/// blank box while the simulated signal drives the activity underneath.
class TourChildPreview extends StatefulWidget {
  const TourChildPreview({super.key});
  @override
  State<TourChildPreview> createState() => _TourChildPreviewState();
}

class _TourChildPreviewState extends State<TourChildPreview>
    with SingleTickerProviderStateMixin {
  late final _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 2))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ColoredBox(
        color: const Color(0xff123d35),
        child: Center(
          child: AnimatedBuilder(
            animation: _c,
            builder: (context, _) => GuideFigure(
              talking: true,
              arms: ArmPose.wave,
              phase: _c.value,
              size: 120,
            ),
          ),
        ),
      );
}
