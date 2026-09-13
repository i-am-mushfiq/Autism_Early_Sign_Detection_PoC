import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:sanket_mobile/core/calibration.dart';
import 'package:sanket_mobile/core/measurement.dart';
import 'package:sanket_mobile/core/session.dart';
import 'package:sanket_mobile/runtime/activity_controller.dart';

import 'fakes.dart';
import 'sim_child.dart';

typedef ControllerFactory = ActivityController Function(ActivityContext ctx);

/// Runs one activity controller end to end against a simulated child.
ActivityObservation runActivity(
  ControllerFactory create, {
  ChildBehaviour behaviour = const ChildBehaviour(),
  CalibrationResult calibration = usableCalibration,
  bool camera = true,
  bool microphone = true,
  ChildProfile profile = const ChildProfile(nickname: 'Rafi', ageMonths: 28),
  void Function(ActivityController c, FakeAsync async)? during,
}) {
  late ActivityObservation result;
  fakeAsync((async) {
    final hub = FakeSensorHub(
        clock: ManualClock(() => async.elapsed.inMilliseconds), cameraAvailable: camera, microphoneAvailable: microphone)
      ..started = true;
    final controller = create(ActivityContext(
        sensors: hub, calibration: calibration, profile: profile, random: math.Random(7)));
    final sim = SimChild(hub, behaviour);
    controller.start();
    during?.call(controller, async);
    drive(async, (t) => sim.step(controller, t), () => controller.phase == ActivityPhase.done, maxMs: 180000);
    result = controller.result!;
    controller.dispose();
  });
  return result;
}
