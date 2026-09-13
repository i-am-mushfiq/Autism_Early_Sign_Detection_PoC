import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:sanket_mobile/activities/bubble_trail/bubble_trail_controller.dart';
import 'package:sanket_mobile/activities/copy_me/copy_me_controller.dart';
import 'package:sanket_mobile/activities/copy_me/pose_actions.dart';
import 'package:sanket_mobile/activities/follow_my_look/follow_my_look_controller.dart';
import 'package:sanket_mobile/activities/name_response/name_response_controller.dart';
import 'package:sanket_mobile/activities/social_story/social_story_controller.dart';
import 'package:sanket_mobile/activities/switch_it/switch_it_analyzer.dart';
import 'package:sanket_mobile/activities/switch_it/switch_it_controller.dart';
import 'package:sanket_mobile/core/calibration.dart';
import 'package:sanket_mobile/core/samples.dart';
import 'package:sanket_mobile/runtime/activity_controller.dart';
import 'package:sanket_mobile/runtime/calibration_controller.dart';

import 'fakes.dart';

/// What the simulated child does. Every behaviour produces sensor samples
/// through the fake hub; nothing bypasses the capture → analysis pipeline.
class ChildBehaviour {
  const ChildBehaviour({
    this.present = true,
    this.prefersSocial = true,
    this.respondsToName = true,
    this.followsLook = true,
    this.imitates = true,
    this.tapsBubbles = true,
    this.switchesRule = true,
    this.tapsSwitch = true,
    this.lighting = 0.5,
    this.caregiverCalls = true,
  });
  final bool present, prefersSocial, respondsToName, followsLook, imitates, tapsBubbles, switchesRule, tapsSwitch;
  final bool caregiverCalls;
  final double lighting;
}

class SimChild {
  SimChild(this.hub, this.behaviour);
  final FakeSensorHub hub;
  final ChildBehaviour behaviour;

  int? _callHeardAt;
  int? _lookCueSeenAt;
  int _lookTrial = -1;
  int _copyWindowSeenAt = -1;
  int _copyTrial = -1;
  int _promptSeenAt = -1;
  int _lastTap = -100000;
  int _lastSwitchTrial = -1;
  int _switchShownAt = 0;

  VisionFrame _face(int t, double yaw) =>
      behaviour.present ? face(t, yaw, lighting: behaviour.lighting) : noFace(t, lighting: behaviour.lighting);

  void _emitFace(int t, double yaw) => hub.emitFrame(_face(t, yaw));

  void stepCalibration(CalibrationController c, int t) {
    final yaw = switch (c.target) {
      CalibrationTarget.left => leftYaw,
      CalibrationTarget.right => rightYaw,
      _ => 0.0,
    };
    hub.emitFrame(behaviour.present
        ? face(t, yaw + (t % 3 - 1) * .8, lighting: behaviour.lighting, pitch: c.target == CalibrationTarget.upper ? 12 : 0)
        : noFace(t, lighting: behaviour.lighting));
  }

  void step(ActivityController a, int t) {
    if (a.phase != ActivityPhase.running) return;
    _calling = false;
    switch (a) {
      case SocialStoryController c:
        final social = c.socialSide == GazeRegion.left ? leftYaw : rightYaw;
        final other = c.socialSide == GazeRegion.left ? rightYaw : leftYaw;
        _emitFace(t, c.inGap ? 0 : (behaviour.prefersSocial ? social : other));
      case NameResponseController c:
        _nameStep(c, t);
      case FollowMyLookController c:
        _lookStep(c, t);
      case BubbleTrailController c:
        _bubbleStep(c, t);
      case CopyMeController c:
        _copyStep(c, t);
      case SwitchItController c:
        _switchStep(c, t);
    }
    hub.emitAudio(_calling ? loud(t) : quiet(t));
  }

  bool _calling = false;

  void _nameStep(NameResponseController c, int t) {
    switch (c.namePhase) {
      case NamePhase.waitingAttention:
        _callHeardAt = null;
        _promptSeenAt = -1;
        _emitFace(t, 0);
      case NamePhase.prompting:
        if (_promptSeenAt < 0) _promptSeenAt = t;
        _emitFace(t, 0);
        if (behaviour.caregiverCalls && t - _promptSeenAt >= 400 && t - _promptSeenAt <= 800) {
          if (c.tapFallback) {
            c.caregiverCalled();
          } else {
            _calling = true;
          }
        }
      case NamePhase.responseWindow:
        _callHeardAt ??= t;
        final turned = behaviour.respondsToName && t - _callHeardAt! >= 700;
        _emitFace(t, turned ? 38 : 0);
      case NamePhase.between:
        _emitFace(t, 0);
    }
  }

  void _lookStep(FollowMyLookController c, int t) {
    if (c.trial != _lookTrial) {
      _lookTrial = c.trial;
      _lookCueSeenAt = null;
    }
    switch (c.lookPhase) {
      case LookPhase.looking:
        _lookCueSeenAt ??= t;
        final follow = behaviour.followsLook && t - _lookCueSeenAt! >= 600;
        _emitFace(t, follow ? (c.target == GazeRegion.left ? leftYaw : rightYaw) : 0);
        if (behaviour.followsLook && t - _lookCueSeenAt! == 1500) c.tapToy(c.target!);
      default:
        _emitFace(t, 0);
    }
  }

  void _bubbleStep(BubbleTrailController c, int t) {
    c.board ??= const Size(600, 320);
    if (!behaviour.tapsBubbles || c.alive.isEmpty || t - _lastTap < 800) return;
    final b = c.alive.first;
    if (c.now - b.spawnMs < 500) return;
    _lastTap = t;
    c.touch(b.centerAt(c.now, c.board!) + const Offset(4, 3), 1);
  }

  void _copyStep(CopyMeController c, int t) {
    if (c.trial != _copyTrial) {
      _copyTrial = c.trial;
      _copyWindowSeenAt = -1;
    }
    PoseObservation? p = behaviour.present ? restingPose() : null;
    if (c.copyPhase == CopyPhase.window) {
      if (_copyWindowSeenAt < 0) _copyWindowSeenAt = t;
      final since = t - _copyWindowSeenAt;
      if (behaviour.imitates && behaviour.present && since >= 800) {
        p = switch (c.action) {
          CopyAction.handsUp => handsUpPose(),
          CopyAction.touchHead => touchHeadPose(),
          CopyAction.clap => since % 600 < 300 ? handsApartPose() : handsTogetherPose(),
        };
      }
    }
    hub.emitFrame(poseFrame(t, p, lighting: behaviour.lighting));
  }

  void _switchStep(SwitchItController c, int t) {
    if (!behaviour.tapsSwitch || c.switchPhase != SwitchPhase.showing) return;
    if (c.trial != _lastSwitchTrial) {
      _lastSwitchTrial = c.trial;
      _switchShownAt = t;
    }
    if (t - _switchShownAt == 900) {
      final choice = behaviour.switchesRule ? c.rule : SwitchRule.bird;
      c.tap(choice);
    }
  }
}

/// Advances fake time in 100 ms steps, letting [sim] react each step, until
/// [done] or [maxMs] elapses.
void drive(FakeAsync async, void Function(int t) onStep, bool Function() done, {int maxMs = 120000}) {
  final start = async.elapsed.inMilliseconds;
  while (!done() && async.elapsed.inMilliseconds - start < maxMs) {
    async.elapse(const Duration(milliseconds: 100));
    onStep(async.elapsed.inMilliseconds);
  }
  async.flushMicrotasks();
}
