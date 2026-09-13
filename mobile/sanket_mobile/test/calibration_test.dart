import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanket_mobile/core/calibration.dart';
import 'package:sanket_mobile/core/measurement.dart';
import 'package:sanket_mobile/core/prototype_parameters.dart';
import 'package:sanket_mobile/runtime/calibration_controller.dart';

import 'support/fakes.dart';
import 'support/sim_child.dart';

List<CalibrationStage> stages() => [
      const CalibrationStage(CalibrationTarget.center, 0, 2200),
      const CalibrationStage(CalibrationTarget.left, 2200, 4400),
      const CalibrationStage(CalibrationTarget.right, 4400, 6600),
      const CalibrationStage(CalibrationTarget.upper, 6600, 8800),
    ];

double yawFor(int t, double c, double l, double r, {double jitter = 1}) {
  final base = t < 2200 ? c : t < 4400 ? l : t < 6600 ? r : c;
  return base + ((t ~/ 100) % 3 - 1) * jitter;
}

void main() {
  const calibrator = GazeCalibrator();

  test('clear, steady left/right head orientation is usable', () {
    final frames = [for (var t = 0; t < 8800; t += 100) face(t, yawFor(t, 0, 25, -25))];
    final r = calibrator.evaluate(frames, stages());
    expect(r.usable, isTrue);
    expect(r.separationDeg, closeTo(50, 1));
    expect(r.samples[CalibrationTarget.left], greaterThanOrEqualTo(P.minSamplesPerCalibrationTarget));
  });

  test('no face during calibration is rejected with too few samples', () {
    final frames = [for (var t = 0; t < 8800; t += 100) noFace(t)];
    final r = calibrator.evaluate(frames, stages());
    expect(r.usable, isFalse);
    expect(r.reason, ReasonCode.calibrationTooFewSamples);
  });

  test('darkness is reported as the reason', () {
    final frames = [for (var t = 0; t < 8800; t += 100) face(t, 0, lighting: .05)];
    expect(calibrator.evaluate(frames, stages()).reason, ReasonCode.tooDark);
  });

  test('a child who does not follow the star cannot be separated', () {
    final frames = [for (var t = 0; t < 8800; t += 100) face(t, yawFor(t, 0, 2, -2))];
    final r = calibrator.evaluate(frames, stages());
    expect(r.usable, isFalse);
    expect(r.reason, ReasonCode.calibrationTargetsNotSeparable);
  });

  test('unstable head orientation is rejected', () {
    final frames = [for (var t = 0; t < 8800; t += 100) face(t, yawFor(t, 0, 25, -25, jitter: 14))];
    expect(calibrator.evaluate(frames, stages()).reason, ReasonCode.calibrationUnstable);
  });

  test('eyes-closed and too-far frames are not used', () {
    final frames = [
      for (var t = 0; t < 8800; t += 100)
        t.isEven && t % 200 == 0 ? face(t, yawFor(t, 0, 25, -25), eyes: .05) : face(t, 0, width: .03)
    ];
    expect(calibrator.evaluate(frames, stages()).usable, isFalse);
  });

  test('classifier maps to regions and refuses ambiguous yaw', () {
    final c = CoarseGazeClassifier(usableCalibration);
    expect(c.classify(face(0, 22)), GazeRegion.left);
    expect(c.classify(face(0, -20)), GazeRegion.right);
    expect(c.classify(face(0, 1)), GazeRegion.center);
    expect(c.classify(face(0, 12)), GazeRegion.uncertain);
    expect(c.classify(noFace(0)), GazeRegion.uncertain);
  });

  test('controller collects real frames, supports retry and does not pass on Continue', () {
    fakeAsync((async) {
      final hub = FakeSensorHub(clock: ManualClock(() => async.elapsed.inMilliseconds))..started = true;
      final c = CalibrationController(hub);
      // A child who is not present: calibration must fail.
      final absent = SimChild(hub, const ChildBehaviour(present: false));
      c.start();
      drive(async, (t) => absent.stepCalibration(c, t), () => c.phase == CalibrationPhase.done, maxMs: 30000);
      expect(c.result.usable, isFalse);
      expect(c.canRetry, isTrue);

      // Retry with a child who watches the star.
      final present = SimChild(hub, const ChildBehaviour());
      c.start();
      expect(c.phase, CalibrationPhase.waitingForFace);
      drive(async, (t) => present.stepCalibration(c, t), () => c.phase == CalibrationPhase.done, maxMs: 30000);
      expect(c.result.usable, isTrue);
      expect(c.attempts, 2);
    });
  });

  test('without a camera, calibration reports camera unavailable', () {
    final hub = FakeSensorHub(cameraAvailable: false)..started = true;
    final c = CalibrationController(hub)..start();
    expect(c.phase, CalibrationPhase.done);
    expect(c.result.reason, ReasonCode.cameraUnavailable);
    expect(c.canRetry, isFalse);
  });

  test('result survives JSON round trip', () {
    final back = CalibrationResult.fromJson(usableCalibration.toJson());
    expect(back.usable, isTrue);
    expect(back.leftYaw, leftYaw);
    expect(back.samples[CalibrationTarget.center], 10);
  });
}
