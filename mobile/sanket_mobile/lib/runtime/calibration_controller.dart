import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/calibration.dart';
import '../core/measurement.dart';
import '../core/prototype_parameters.dart';
import '../core/quality.dart';
import '../core/samples.dart';
import '../sensors/sensor_hub.dart';

enum CalibrationPhase { intro, waitingForFace, running, done }

/// Runs the coarse-gaze calibration: waits until the child's face is in view,
/// shows the star at four targets while collecting real head-orientation
/// samples, then evaluates them with [GazeCalibrator].
class CalibrationController extends ChangeNotifier {
  CalibrationController(this.sensors,
      {this.calibrator = const GazeCalibrator()});
  final SensorHub sensors;
  final GazeCalibrator calibrator;

  static const sequence = [
    CalibrationTarget.center,
    CalibrationTarget.left,
    CalibrationTarget.right,
    CalibrationTarget.upper,
  ];

  CalibrationPhase phase = CalibrationPhase.intro;
  CalibrationTarget? target;
  CalibrationResult result = CalibrationResult.notRun;
  int attempts = 0;

  final _frames = <VisionFrame>[];
  final _stages = <CalibrationStage>[];
  StreamSubscription<VisionFrame>? _sub;
  Timer? _timer;
  int _faceRun = 0;
  int _stageIndex = 0;
  int _stageStart = 0;
  bool _disposed = false;

  bool get canRetry =>
      attempts < P.maxCalibrationAttempts && sensors.availability.camera;
  int get stageIndex => _stageIndex;

  /// Share of recent frames with a usable face, for live caregiver feedback.
  double recentFaceFraction() {
    final now = sensors.clock.nowMs();
    final recent = _frames.where((f) => now - f.tMs <= 1500).toList();
    if (recent.isEmpty) return 0;
    return recent.where(usableGazeFrame).length / recent.length;
  }

  void start() {
    if (phase == CalibrationPhase.waitingForFace ||
        phase == CalibrationPhase.running) return;
    attempts++;
    _frames.clear();
    _stages.clear();
    _faceRun = 0;
    _stageIndex = 0;
    target = null;
    if (!sensors.availability.camera) {
      _complete(const CalibrationResult(
          usable: false, reason: ReasonCode.cameraUnavailable));
      return;
    }
    sensors.mode = VisionMode.face;
    _sub = sensors.frames.listen(_onFrame);
    phase = CalibrationPhase.waitingForFace;
    // If the face never appears, run anyway: the evaluation reports why it failed.
    _timer = Timer(
        const Duration(milliseconds: P.calibrationFaceWaitMs), _beginStages);
    _notify();
  }

  void _onFrame(VisionFrame f) {
    _frames.add(f);
    if (phase == CalibrationPhase.waitingForFace) {
      _faceRun = usableGazeFrame(f) ? _faceRun + 1 : 0;
      if (_faceRun >= 3) _beginStages();
    }
  }

  void _beginStages() {
    if (phase != CalibrationPhase.waitingForFace) return;
    _timer?.cancel();
    phase = CalibrationPhase.running;
    _stageIndex = 0;
    _nextStage();
  }

  void _nextStage() {
    final now = sensors.clock.nowMs();
    if (_stageIndex > 0) {
      _stages
          .add(CalibrationStage(sequence[_stageIndex - 1], _stageStart, now));
    }
    if (_stageIndex >= sequence.length) {
      _sub?.cancel();
      sensors.mode = VisionMode.off;
      _complete(calibrator.evaluate(List.of(_frames), List.of(_stages)));
      return;
    }
    target = sequence[_stageIndex];
    _stageStart = now;
    _stageIndex++;
    _timer =
        Timer(const Duration(milliseconds: P.calibrationStageMs), _nextStage);
    _notify();
  }

  void _complete(CalibrationResult r) {
    result = r;
    phase = CalibrationPhase.done;
    target = null;
    _notify();
  }

  /// Stops a running calibration without a result (e.g. app backgrounded).
  void cancel() {
    _timer?.cancel();
    _sub?.cancel();
    sensors.mode = VisionMode.off;
    if (phase != CalibrationPhase.done) {
      phase = CalibrationPhase.intro;
      attempts = attempts > 0 ? attempts - 1 : 0;
      target = null;
    }
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _sub?.cancel();
    _disposed = true;
    super.dispose();
  }
}
