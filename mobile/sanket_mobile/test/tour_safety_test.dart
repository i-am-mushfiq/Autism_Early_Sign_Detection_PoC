import 'package:flutter_test/flutter_test.dart';
import 'package:sanket_mobile/activities/bubble_trail/bubble_trail_controller.dart';
import 'package:sanket_mobile/core/calibration.dart';
import 'package:sanket_mobile/core/session.dart';
import 'package:sanket_mobile/core/samples.dart';
import 'package:sanket_mobile/runtime/activity_controller.dart';
import 'package:sanket_mobile/tour/tour_activity_completion.dart';
import 'package:sanket_mobile/tour/tour_sensor_hub.dart';
import 'support/fakes.dart';

void main() {
  test('scripted tour never collects frame or audio samples', () async {
    final hub = TourSensorHub(scripted: true);
    await hub.start(camera: true, microphone: true);
    var frames = 0;
    var audio = 0;
    final visionSub = hub.frames.listen((_) => frames++);
    final audioSub = hub.audio.listen((_) => audio++);
    hub.mode = VisionMode.face;
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(frames, 0);
    expect(audio, 0);
    await visionSub.cancel();
    await audioSub.cancel();
    await hub.dispose();
  });

  test('tour completion cannot replace a real activity observation', () {
    final hub = FakeSensorHub();
    final controller = BubbleTrailController(ActivityContext(
      sensors: hub,
      calibration: CalibrationResult.notRun,
      profile: const ChildProfile(nickname: 'Real child', ageMonths: 30),
    ));
    expect(() => completeTourActivity(controller), throwsStateError);
    expect(controller.result, isNull);
    expect(controller.phase, ActivityPhase.intro);
    controller.dispose();
  });
}
