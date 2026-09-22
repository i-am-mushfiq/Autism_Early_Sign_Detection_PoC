/// Derived sensor samples. These are the only form in which sensor data enters
/// the measurement pipeline: numbers extracted on-device from a frame or an
/// audio window. No image, video or audio is ever represented here.
library;

import 'prototype_parameters.dart';

/// Head/face measurement from one camera frame.
class FaceObservation {
  const FaceObservation({
    required this.yawDeg,
    required this.pitchDeg,
    required this.widthFraction,
    required this.centerX,
    required this.centerY,
    this.leftEyeOpen,
    this.rightEyeOpen,
  });

  /// Head rotation around the vertical axis, degrees (ML Kit Euler Y).
  final double yawDeg;

  /// Head rotation around the horizontal axis, degrees (ML Kit Euler X).
  final double pitchDeg;

  /// Face bounding-box width / image width.
  final double widthFraction;

  /// Face centre in normalised image coordinates (0–1).
  final double centerX, centerY;
  final double? leftEyeOpen, rightEyeOpen;

  bool get eyesLikelyClosed {
    final l = leftEyeOpen, r = rightEyeOpen;
    if (l == null || r == null) return false;
    const min = PrototypeParameters.minEyeOpenProbability;
    return l < min && r < min;
  }
}

enum PosePoint {
  nose,
  leftEye,
  rightEye,
  leftEar,
  rightEar,
  leftShoulder,
  rightShoulder,
  leftWrist,
  rightWrist,
}

class PoseLandmark {
  const PoseLandmark(this.x, this.y, this.likelihood);

  /// Both coordinates are divided by the image *width* so distances are isotropic.
  final double x, y;
  final double likelihood;
}

class PoseObservation {
  const PoseObservation(this.points);
  final Map<PosePoint, PoseLandmark> points;

  PoseLandmark? reliable(PosePoint p, double minLikelihood) {
    final l = points[p];
    return l != null && l.likelihood >= minLikelihood ? l : null;
  }
}

/// One processed camera frame. [face]/[pose] are null when the detector ran and
/// found nothing, or was not running for this frame (see [mode]).
class VisionFrame {
  const VisionFrame({
    required this.tMs,
    required this.mode,
    required this.lighting,
    this.face,
    this.pose,
  });
  final int tMs;
  final VisionMode mode;

  /// Mean luma of the frame, 0–1.
  final double lighting;
  final FaceObservation? face;
  final PoseObservation? pose;
}

enum VisionMode { off, face, pose }

/// Loudness summary of one 100 ms microphone window.
class AudioLevel {
  const AudioLevel(
      {required this.tMs, required this.rmsDb, required this.peakDb});
  final int tMs;
  final double rmsDb, peakDb;
}

/// A timestamped activity event recorded by an activity controller.
class ActivityEvent {
  const ActivityEvent(this.tMs, this.type, [this.data = const {}]);
  final int tMs;
  final String type;
  final Map<String, Object> data;

  T get<T>(String key) => data[key] as T;
}
