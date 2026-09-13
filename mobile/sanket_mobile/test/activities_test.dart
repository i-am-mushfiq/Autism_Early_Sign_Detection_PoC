import 'package:flutter_test/flutter_test.dart';
import 'package:sanket_mobile/activities/bubble_trail/bubble_trail_analyzer.dart';
import 'package:sanket_mobile/activities/bubble_trail/bubble_trail_controller.dart';
import 'package:sanket_mobile/activities/copy_me/copy_me_analyzer.dart';
import 'package:sanket_mobile/activities/copy_me/copy_me_controller.dart';
import 'package:sanket_mobile/activities/copy_me/pose_actions.dart';
import 'package:sanket_mobile/activities/follow_my_look/follow_my_look_analyzer.dart';
import 'package:sanket_mobile/activities/follow_my_look/follow_my_look_controller.dart';
import 'package:sanket_mobile/activities/name_response/name_response_analyzer.dart';
import 'package:sanket_mobile/activities/name_response/name_response_controller.dart';
import 'package:sanket_mobile/activities/social_story/social_story_analyzer.dart';
import 'package:sanket_mobile/activities/social_story/social_story_controller.dart';
import 'package:sanket_mobile/activities/switch_it/switch_it_controller.dart';
import 'package:sanket_mobile/core/activity_capture.dart';
import 'package:sanket_mobile/core/activity_catalog.dart';
import 'package:sanket_mobile/core/calibration.dart';
import 'package:sanket_mobile/core/measurement.dart';
import 'package:sanket_mobile/core/prototype_parameters.dart';
import 'package:sanket_mobile/core/quality.dart';
import 'package:sanket_mobile/core/samples.dart';
import 'package:sanket_mobile/runtime/activity_controller.dart';

import 'support/fakes.dart';
import 'support/run_activity.dart';
import 'support/sim_child.dart';

ActivityCapture capture(ActivityId id,
        {List<VisionFrame> frames = const [],
        List<AudioLevel> audio = const [],
        List<ActivityEvent> events = const [],
        int end = 60000,
        CalibrationResult calibration = usableCalibration,
        SensorAvailability sensors = SensorAvailability.all}) =>
    ActivityCapture(
        activity: id,
        startMs: 0,
        endMs: end,
        sensors: sensors,
        calibration: calibration,
        frames: frames,
        audio: audio,
        events: events);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Social Story', () {
    test('child watching the talking guide: valid, measured, no pattern', () {
      final o = runActivity(SocialStoryController.new);
      expect(o.status, ActivityStatus.valid);
      expect(o.trials, hasLength(2));
      expect(o.feature('social_share')!.value, greaterThan(.9));
      expect(o.notes, isEmpty);
    });

    test('child watching the toy in both counterbalanced segments: pattern noted', () {
      final o = runActivity(SocialStoryController.new, behaviour: const ChildBehaviour(prefersSocial: false));
      expect(o.status, ActivityStatus.valid);
      expect(o.feature('social_share')!.value, lessThan(.1));
      expect(o.notes, [PatternNote.storyNonSocialPreference]);
    });

    test('sides really swap between segments', () {
      final o = runActivity(SocialStoryController.new);
      expect(o.trials[0].measures['socialSide'], isNot(o.trials[1].measures['socialSide']));
    });

    test('child not in view: non-participation, never a pattern', () {
      final o = runActivity(SocialStoryController.new, behaviour: const ChildBehaviour(present: false));
      expect(o.status, ActivityStatus.nonParticipation);
      expect(o.notes, isEmpty);
    });

    test('unusable gaze calibration excludes the construct', () {
      final o = runActivity(SocialStoryController.new, calibration: CalibrationResult.notRun);
      expect(o.status, ActivityStatus.insufficient);
      expect(o.qualityOf(Modality.gaze)!.status, QualityStatus.excluded);
      expect(o.feature('social_share'), isNull);
    });

    test('too dark: excluded by lighting quality gate', () {
      final o = runActivity(SocialStoryController.new, behaviour: const ChildBehaviour(lighting: .05));
      expect(o.status, ActivityStatus.insufficient);
      expect(o.reason, ReasonCode.tooDark);
    });

    test('no camera: not run, marked unavailable', () {
      final o = runActivity(SocialStoryController.new, camera: false);
      expect(o.status, ActivityStatus.insufficient);
      expect(o.reason, ReasonCode.cameraUnavailable);
    });

    test('one segment only (stopped early): insufficient, no pattern', () {
      final frames = [for (var t = 0; t < 20000; t += 100) face(t, rightYaw)];
      final o = const SocialStoryAnalyzer().analyze(capture(ActivityId.socialStory, frames: frames, end: 20000, events: [
        const ActivityEvent(0, SocialStoryAnalyzer.segmentStart, {'index': 0, 'socialSide': 'left'}),
        const ActivityEvent(20000, SocialStoryAnalyzer.segmentEnd, {'index': 0}),
      ]));
      expect(o.status, ActivityStatus.insufficient);
      expect(o.notes, isEmpty);
    });
  });

  group('Name Response', () {
    test('call detected by microphone and head turns: valid with latency', () {
      final o = runActivity(NameResponseController.new);
      expect(o.status, ActivityStatus.valid);
      expect(o.validTrials, P.nameTrials);
      expect(o.feature('response_rate')!.value, 1);
      expect(o.feature('median_latency_ms')!.value, inInclusiveRange(500, 1500));
      expect(o.qualityOf(Modality.audio)!.status, QualityStatus.valid);
      expect(o.notes, isEmpty);
    });

    test('no head turn in any measured call: pattern noted', () {
      final o = runActivity(NameResponseController.new, behaviour: const ChildBehaviour(respondsToName: false));
      expect(o.status, ActivityStatus.valid);
      expect(o.feature('response_rate')!.value, 0);
      expect(o.notes, [PatternNote.nameNoOrienting]);
    });

    test('caregiver never calls: calls not detected, retried, then insufficient', () {
      final o = runActivity(NameResponseController.new, behaviour: const ChildBehaviour(caregiverCalls: false));
      expect(o.status, ActivityStatus.insufficient);
      expect(o.trials.length, P.nameMaxAttempts);
      expect(o.trials.every((t) => t.reason == ReasonCode.callNotDetected), isTrue);
      expect(o.notes, isEmpty);
    });

    test('child not watching: stops after repeated attention timeouts as non-participation', () {
      final o = runActivity(NameResponseController.new, behaviour: const ChildBehaviour(present: false));
      expect(o.status, ActivityStatus.nonParticipation);
      expect(o.trials.length, P.nameStopAfterAttentionTimeouts);
    });

    test('no microphone: caregiver taps, timing marked limited, no latency claimed', () {
      final o = runActivity(NameResponseController.new, microphone: false);
      expect(o.status, ActivityStatus.valid);
      expect(o.qualityOf(Modality.audio)!.status, QualityStatus.unavailable);
      expect(o.feature('median_latency_ms'), isNull);
      expect(o.trials.first.measures['timing'], 'caregiver');
    });

    test('call onset needs sustained loudness above the noise floor', () {
      final levels = [quiet(0), loud(100), quiet(200), loud(300), loud(400), quiet(500)];
      expect(detectCallOnset(levels, -55), 300);
      expect(detectCallOnset([quiet(0), quiet(100)], -55), isNull);
    });

    test('face leaving view after turning counts; leaving without turning does not', () {
      final turnAway = [face(100, 3), face(200, 14), noFace(300), noFace(500), noFace(800)];
      expect(detectOrientingTurn(turnAway, 0), 300);
      final walkedOff = [face(100, 1), noFace(200), noFace(700)];
      expect(detectOrientingTurn(walkedOff, 0), isNull);
      final darkened = [face(100, 14), noFace(200, lighting: .02), noFace(800, lighting: .02)];
      expect(detectOrientingTurn(darkened, 0), isNull);
    });

    test('face lost without a turn invalidates the trial rather than recording no response', () {
      final frames = [
        for (var t = 0; t < 2000; t += 100) face(t, 0),
        for (var t = 2000; t < 7000; t += 100) noFace(t),
      ];
      final o = const NameResponseAnalyzer().analyze(capture(ActivityId.nameResponse, frames: frames, end: 7000, events: [
        const ActivityEvent(0, NameResponseAnalyzer.trialStart, {'index': 1}),
        const ActivityEvent(2000, NameResponseAnalyzer.call, {'source': 'audio', 'floorDb': -55.0}),
        const ActivityEvent(7000, NameResponseAnalyzer.trialEnd),
      ]));
      expect(o.trials.single.reason, ReasonCode.faceLostWithoutTurn);
      expect(o.notes, isEmpty);
    });
  });

  group('Follow My Look', () {
    test('child follows the guide: valid, follow rate and tap accuracy measured', () {
      final o = runActivity(FollowMyLookController.new);
      expect(o.status, ActivityStatus.valid);
      expect(o.validTrials, P.lookTrials);
      expect(o.feature('follow_rate')!.value, 1);
      expect(o.feature('tap_correct_rate')!.value, 1);
      expect(o.notes, isEmpty);
    });

    test('child keeps looking at the guide: valid trials, pattern noted', () {
      final o = runActivity(FollowMyLookController.new, behaviour: const ChildBehaviour(followsLook: false));
      expect(o.status, ActivityStatus.valid);
      expect(o.feature('follow_rate')!.value, 0);
      expect(o.notes, [PatternNote.lookNoFollow]);
    });

    test('without calibrated gaze: runs for taps only and is insufficient', () {
      final o = runActivity(FollowMyLookController.new, calibration: CalibrationResult.notRun);
      expect(o.status, ActivityStatus.insufficient);
      expect(o.reason, ReasonCode.gazeNotCalibrated);
      expect(o.feature('follow_rate'), isNull);
      expect(o.feature('tap_correct_rate')!.reliability, Reliability.limited);
    });

    test('child absent: centre timeouts, non-participation', () {
      final o = runActivity(FollowMyLookController.new, behaviour: const ChildBehaviour(present: false));
      expect(o.status, ActivityStatus.nonParticipation);
    });

    test('already looking at the target before the cue is not counted as following', () {
      final frames = [
        for (var t = 0; t < 1000; t += 100) face(t, leftYaw),
        for (var t = 1000; t < 5000; t += 100) face(t, leftYaw),
      ];
      final o = const FollowMyLookAnalyzer().analyze(capture(ActivityId.followMyLook, frames: frames, end: 5000, events: [
        const ActivityEvent(0, FollowMyLookAnalyzer.trialStart, {'index': 1, 'side': 'left'}),
        const ActivityEvent(1000, FollowMyLookAnalyzer.cue, {'side': 'left'}),
        const ActivityEvent(5000, FollowMyLookAnalyzer.trialEnd),
      ]));
      expect(o.trials.single.reason, ReasonCode.alreadyLookingAtTarget);
    });
  });

  group('Bubble Trail', () {
    test('child pops bubbles: valid with reaction time, error and variability', () {
      final o = runActivity(BubbleTrailController.new);
      expect(o.status, ActivityStatus.valid);
      expect(o.feature('bubbles_popped')!.value, greaterThanOrEqualTo(P.bubbleMinHits));
      expect(o.feature('median_reaction_ms')!.value, greaterThan(400));
      expect(o.feature('mean_endpoint_error')!.value, lessThan(1));
      expect(o.feature('reaction_time_cv'), isNotNull);
      expect(o.durationMs, closeTo(P.bubbleDurationMs, 300));
    });

    test('no taps: hint shown, then ends early as non-participation', () {
      var hinted = false;
      final o = runActivity(BubbleTrailController.new, behaviour: const ChildBehaviour(tapsBubbles: false),
          during: (c, async) {
        async.elapse(const Duration(milliseconds: P.bubbleInactivityHintMs + 300));
        hinted = (c as BubbleTrailController).showHint;
      });
      expect(hinted, isTrue);
      expect(o.status, ActivityStatus.nonParticipation);
      expect(o.durationMs, lessThan(P.bubbleDurationMs));
    });

    test('touch hit-testing, misses, corrections and palm rejection', () {
      final events = [
        const ActivityEvent(1000, BubbleTrailAnalyzer.miss, {'distanceNorm': 2.0}),
        const ActivityEvent(1500, BubbleTrailAnalyzer.pop, {'id': 0, 'rtMs': 900, 'errorNorm': .3}),
        const ActivityEvent(2500, BubbleTrailAnalyzer.pop, {'id': 1, 'rtMs': 1100, 'errorNorm': .5}),
        const ActivityEvent(3000, BubbleTrailAnalyzer.rejected, {'pointers': 4}),
        const ActivityEvent(4000, BubbleTrailAnalyzer.expire, {'id': 2}),
      ];
      final o = const BubbleTrailAnalyzer().analyze(capture(ActivityId.bubbleTrail, events: events));
      expect(o.feature('corrections')!.value, 1);
      expect(o.feature('rejected_touches')!.value, 1);
      expect(o.feature('bubbles_missed')!.value, 1);
      expect(o.feature('median_reaction_ms')!.value, 1000);
      expect(o.status, ActivityStatus.insufficient); // 3 touches < minimum
    });
  });

  group('Copy Me', () {
    const detector = PoseActionDetector();

    test('pose rules recognise each action and resting', () {
      expect(detector.posture(handsUpPose()), CopyAction.handsUp);
      expect(detector.posture(touchHeadPose()), CopyAction.touchHead);
      expect(detector.posture(restingPose()), isNull);
      final clap = [
        poseFrame(0, handsApartPose()),
        poseFrame(300, handsTogetherPose()),
      ];
      expect(detector.detect(clap)!.action, CopyAction.clap);
      expect(detector.detect([poseFrame(0, handsTogetherPose()), poseFrame(300, handsTogetherPose())]), isNull);
    });

    test('low-likelihood landmarks are ignored', () {
      expect(PoseActionDetector.framingOk(pose(lwx: .35, lwy: .15, rwx: .65, rwy: .15, likelihood: .2)), isFalse);
      expect(detector.posture(pose(lwx: .35, lwy: .15, rwx: .65, rwy: .15, likelihood: .2)), isNull);
    });

    test('child copies all three actions: valid, no pattern', () {
      final o = runActivity(CopyMeController.new);
      expect(o.status, ActivityStatus.valid);
      expect(o.validTrials, 3);
      expect(o.feature('imitation_rate')!.value, 1);
      expect(o.feature('median_onset_ms'), isNotNull);
      expect(o.notes, isEmpty);
    });

    test('child visible but not copying: pattern noted', () {
      final o = runActivity(CopyMeController.new, behaviour: const ChildBehaviour(imitates: false));
      expect(o.status, ActivityStatus.valid);
      expect(o.notes, [PatternNote.copyNoImitation]);
    });

    test('body not in view: framing timeouts, insufficient, never "no imitation"', () {
      final o = runActivity(CopyMeController.new, behaviour: const ChildBehaviour(present: false));
      expect(o.status, ActivityStatus.insufficient);
      expect(o.reason, ReasonCode.bodyNotVisible);
      expect(o.notes, isEmpty);
    });

    test('analyzer: a trial with the body out of view is excluded', () {
      final o = const CopyMeAnalyzer().analyze(capture(ActivityId.copyMe, end: 8000, frames: [
        for (var t = 0; t < 8000; t += 100) poseFrame(t, null),
      ], events: [
        const ActivityEvent(0, CopyMeAnalyzer.trialStart, {'index': 1, 'action': 'clap'}),
        const ActivityEvent(1000, CopyMeAnalyzer.windowStart),
        const ActivityEvent(7000, CopyMeAnalyzer.windowEnd),
      ]));
      expect(o.trials.single.reason, ReasonCode.bodyNotVisible);
    });
  });

  group('Switch It', () {
    test('child follows both rules: valid with switch cost and accuracy', () {
      final o = runActivity(SwitchItController.new);
      expect(o.status, ActivityStatus.valid);
      expect(o.trials, hasLength(10));
      expect(o.feature('accuracy_before_switch')!.value, 1);
      expect(o.feature('accuracy_after_switch')!.value, 1);
      expect(o.feature('perseverative_taps')!.value, 0);
      expect(o.feature('switch_cost_ms'), isNotNull);
      expect(o.notes, isEmpty, reason: 'supportive-only construct never produces a pattern');
    });

    test('child keeps tapping the bird after the switch: perseveration measured', () {
      final o = runActivity(SwitchItController.new, behaviour: const ChildBehaviour(switchesRule: false));
      expect(o.feature('perseverative_taps')!.value, 5);
      expect(o.feature('accuracy_after_switch')!.value, 0);
      expect(o.notes, isEmpty);
    });

    test('no taps: stops after consecutive omissions as non-participation', () {
      final o = runActivity(SwitchItController.new, behaviour: const ChildBehaviour(tapsSwitch: false));
      expect(o.status, ActivityStatus.nonParticipation);
      expect(o.trials.length, P.switchStopAfterOmissions);
    });

    test('the bird side changes across trials', () {
      final sides = <String>{};
      runActivity(SwitchItController.new, during: (c, async) {
        for (var i = 0; i < 40; i++) {
          async.elapse(const Duration(milliseconds: 250));
          sides.add((c as SwitchItController).birdOnLeft ? 'l' : 'r');
        }
      });
      expect(sides, hasLength(2));
    });

    test('age gate is 24 months', () {
      expect(ActivityId.switchIt.definition.offeredFor(23), isFalse);
      expect(ActivityId.switchIt.definition.offeredFor(24), isTrue);
    });
  });

  group('Activity lifecycle', () {
    test('pausing discards the attempt and restarting runs cleanly', () {
      final o = runActivity(SwitchItController.new, during: (c, async) {
        async.elapse(const Duration(seconds: 3));
        c.cancelAttempt();
        expect(c.phase, ActivityPhase.intro);
        expect(c.events, isEmpty);
        c.start();
      });
      expect(o.status, ActivityStatus.valid);
      expect(o.trials, hasLength(10));
    });

    test('stopping mid-activity keeps measured data and records why it ended', () {
      final o = runActivity(BubbleTrailController.new, during: (c, async) {
        async.elapse(const Duration(seconds: 1));
        c.finish(endedBy: ReasonCode.stoppedEarly);
      });
      expect(o.durationMs, lessThan(5000));
      expect(o.status, isNot(ActivityStatus.valid));
    });

    test('every activity has a distinct evidence role from the specification', () {
      expect(ActivityId.socialStory.definition.role, InterpretationRole.escalating);
      expect(ActivityId.copyMe.definition.role, InterpretationRole.monitorOnly);
      expect(ActivityId.bubbleTrail.definition.role, InterpretationRole.descriptive);
      expect(ActivityId.switchIt.definition.role, InterpretationRole.descriptive);
    });

    test('quality helpers report the dominant face problem', () {
      final frames = [for (var t = 0; t < 1000; t += 100) face(t, 0, width: .02)];
      expect(assessFace(frames).reason, ReasonCode.faceTooFar);
    });
  });
}
