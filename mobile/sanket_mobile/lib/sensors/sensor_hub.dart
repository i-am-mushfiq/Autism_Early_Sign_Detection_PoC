import 'package:flutter/widgets.dart';

import '../core/activity_capture.dart';
import '../core/samples.dart';

/// Monotonic session time in milliseconds, shared by sensors and activities.
abstract class SessionClock {
  int nowMs();
}

class StopwatchClock implements SessionClock {
  final _watch = Stopwatch()..start();
  @override
  int nowMs() => _watch.elapsedMilliseconds;
}

enum PermissionState { granted, denied, permanentlyDenied }

class PermissionResult {
  const PermissionResult(this.camera, this.microphone);
  final PermissionState camera, microphone;
}

/// Isolates platform permission handling so flows are testable.
abstract class PermissionGateway {
  Future<PermissionResult> current();
  Future<PermissionResult> request();
  Future<void> openSettings();
}

/// Isolates all sensor capture. Implementations must only emit derived
/// samples ([VisionFrame], [AudioLevel]); raw media never leaves the hub.
abstract class SensorHub {
  SessionClock get clock;
  SensorAvailability get availability;

  /// Starts the sensors the caregiver allowed. Safe to call again.
  Future<SensorAvailability> start({required bool camera, required bool microphone});

  /// Which detector runs on camera frames. [VisionMode.off] emits no frames.
  VisionMode get mode;
  set mode(VisionMode mode);

  /// Processed camera frames (only while [mode] is not off).
  Stream<VisionFrame> get frames;

  /// Microphone loudness windows. The microphone only runs while listened to.
  Stream<AudioLevel> get audio;

  /// A live camera preview for the caregiver, or null without a camera.
  Widget? preview();

  Future<void> dispose();
}
