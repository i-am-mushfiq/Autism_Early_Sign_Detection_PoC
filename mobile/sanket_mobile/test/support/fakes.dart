import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sanket_mobile/core/activity_capture.dart';
import 'package:sanket_mobile/core/calibration.dart';
import 'package:sanket_mobile/core/samples.dart';
import 'package:sanket_mobile/sensors/sensor_hub.dart';

class ManualClock implements SessionClock {
  ManualClock(this.read);
  final int Function() read;
  @override
  int nowMs() => read();
}

/// Sensor hub driven by tests: frames and audio are pushed explicitly.
class FakeSensorHub implements SensorHub {
  FakeSensorHub({SessionClock? clock, this.cameraAvailable = true, this.microphoneAvailable = true})
      : clock = clock ?? StopwatchClock();

  @override
  final SessionClock clock;
  bool cameraAvailable, microphoneAvailable;
  bool started = false, disposed = false;
  final _frames = StreamController<VisionFrame>.broadcast(sync: true);
  final _audio = StreamController<AudioLevel>.broadcast(sync: true);
  final modes = <VisionMode>[];

  @override
  VisionMode mode = VisionMode.off;

  @override
  SensorAvailability get availability =>
      started ? SensorAvailability(camera: cameraAvailable, microphone: microphoneAvailable) : SensorAvailability.none;

  @override
  Future<SensorAvailability> start({required bool camera, required bool microphone}) async {
    started = true;
    cameraAvailable = cameraAvailable && camera;
    microphoneAvailable = microphoneAvailable && microphone;
    return availability;
  }

  @override
  Stream<VisionFrame> get frames => _frames.stream;
  @override
  Stream<AudioLevel> get audio => _audio.stream;

  void emitFrame(VisionFrame f) {
    if (mode != VisionMode.off) _frames.add(f);
  }

  void emitAudio(AudioLevel a) => _audio.add(a);

  @override
  Widget? preview() => null;

  @override
  Future<void> dispose() async {
    disposed = true;
  }
}

class FakePermissions implements PermissionGateway {
  FakePermissions([this.result = const PermissionResult(PermissionState.granted, PermissionState.granted)]);
  PermissionResult result;
  bool requested = false;
  @override
  Future<PermissionResult> current() async =>
      requested ? result : const PermissionResult(PermissionState.denied, PermissionState.denied);
  @override
  Future<PermissionResult> request() async {
    requested = true;
    return result;
  }

  @override
  Future<void> openSettings() async {}
}

// ── Sample builders ─────────────────────────────────────────────────────

VisionFrame face(int t, double yaw,
        {double lighting = 0.5, double width = 0.3, double eyes = 0.9, double pitch = 0}) =>
    VisionFrame(
      tMs: t,
      mode: VisionMode.face,
      lighting: lighting,
      face: FaceObservation(
          yawDeg: yaw,
          pitchDeg: pitch,
          widthFraction: width,
          centerX: .5,
          centerY: .5,
          leftEyeOpen: eyes,
          rightEyeOpen: eyes),
    );

VisionFrame noFace(int t, {double lighting = 0.5}) => VisionFrame(tMs: t, mode: VisionMode.face, lighting: lighting);

/// Head orientation convention used by simulated children in tests:
/// looking at the screen's left raises yaw, right lowers it.
const leftYaw = 24.0, rightYaw = -24.0;

const usableCalibration = CalibrationResult(
  usable: true,
  centerYaw: 0,
  leftYaw: leftYaw,
  rightYaw: rightYaw,
  noiseDeg: 2,
  samples: {CalibrationTarget.center: 10, CalibrationTarget.left: 10, CalibrationTarget.right: 10},
);

PoseObservation pose({
  required double lwx,
  required double lwy,
  required double rwx,
  required double rwy,
  double likelihood = .9,
}) =>
    PoseObservation({
      PosePoint.nose: PoseLandmark(.5, .30, likelihood),
      PosePoint.leftShoulder: PoseLandmark(.40, .50, likelihood),
      PosePoint.rightShoulder: PoseLandmark(.60, .50, likelihood),
      PosePoint.leftWrist: PoseLandmark(lwx, lwy, likelihood),
      PosePoint.rightWrist: PoseLandmark(rwx, rwy, likelihood),
    });

/// Shoulder width in these poses is 0.2.
PoseObservation restingPose() => pose(lwx: .35, lwy: .75, rwx: .65, rwy: .75);
PoseObservation handsUpPose() => pose(lwx: .35, lwy: .15, rwx: .65, rwy: .15);
PoseObservation handsTogetherPose() => pose(lwx: .49, lwy: .6, rwx: .51, rwy: .6);
PoseObservation handsApartPose() => pose(lwx: .30, lwy: .6, rwx: .70, rwy: .6);
PoseObservation touchHeadPose() => pose(lwx: .35, lwy: .75, rwx: .55, rwy: .22);

VisionFrame poseFrame(int t, PoseObservation? p, {double lighting = .5}) =>
    VisionFrame(tMs: t, mode: VisionMode.pose, lighting: lighting, pose: p);

AudioLevel quiet(int t) => AudioLevel(tMs: t, rmsDb: -55, peakDb: -45);
AudioLevel loud(int t) => AudioLevel(tMs: t, rmsDb: -20, peakDb: -10);
