/// Explicit, reusable signal-quality assessment.
///
/// Each function turns derived samples into a [ModalityQuality] decision with
/// the measured value that justified it, so exclusions are always explainable.
library;

import 'measurement.dart';
import 'prototype_parameters.dart';
import 'samples.dart';


/// Frames inside [fromMs, toMs].
List<VisionFrame> framesBetween(List<VisionFrame> frames, int fromMs, int toMs) =>
    [for (final f in frames) if (f.tMs >= fromMs && f.tMs <= toMs) f];

List<AudioLevel> audioBetween(List<AudioLevel> levels, int fromMs, int toMs) =>
    [for (final a in levels) if (a.tMs >= fromMs && a.tMs <= toMs) a];

/// Why a single face frame cannot be used for head-orientation measurement,
/// or null when it can.
ReasonCode? faceFrameProblem(VisionFrame frame) {
  if (frame.lighting < P.minLighting) return ReasonCode.tooDark;
  if (frame.lighting > P.maxLighting) return ReasonCode.tooBright;
  final face = frame.face;
  if (face == null) return ReasonCode.faceNotVisible;
  if (face.widthFraction < P.minFaceWidthFraction) return ReasonCode.faceTooFar;
  if (face.widthFraction > P.maxFaceWidthFraction) return ReasonCode.faceTooClose;
  return null;
}

bool usableFaceFrame(VisionFrame frame) => faceFrameProblem(frame) == null;

/// Usable for coarse gaze: a usable face frame whose eyes are not closed.
bool usableGazeFrame(VisionFrame frame) =>
    usableFaceFrame(frame) && !frame.face!.eyesLikelyClosed;

double framesPerSecond(List<VisionFrame> frames, int durationMs) =>
    durationMs <= 0 ? 0 : frames.length * 1000 / durationMs;

ModalityQuality assessCamera(List<VisionFrame> frames, int durationMs,
    {required bool available}) {
  if (!available) {
    return const ModalityQuality(Modality.camera, QualityStatus.unavailable,
        reason: ReasonCode.cameraUnavailable);
  }
  final fps = framesPerSecond(frames, durationMs);
  return ModalityQuality(
      Modality.camera,
      fps >= P.minVisionFps ? QualityStatus.valid : QualityStatus.excluded,
      reason: fps >= P.minVisionFps ? null : ReasonCode.lowFrameRate,
      value: fps);
}

ModalityQuality assessLighting(List<VisionFrame> frames) {
  final m = median(frames.map((f) => f.lighting));
  if (m == null) {
    return const ModalityQuality(Modality.lighting, QualityStatus.unavailable,
        reason: ReasonCode.cameraUnavailable);
  }
  final reason = m < P.minLighting
      ? ReasonCode.tooDark
      : m > P.maxLighting
          ? ReasonCode.tooBright
          : null;
  return ModalityQuality(Modality.lighting,
      reason == null ? QualityStatus.valid : QualityStatus.excluded,
      reason: reason, value: m);
}

/// Face quality: share of frames with a usable face, plus the dominant problem.
ModalityQuality assessFace(List<VisionFrame> frames,
    {double minFraction = 0.5}) {
  if (frames.isEmpty) {
    return const ModalityQuality(Modality.face, QualityStatus.unavailable,
        reason: ReasonCode.cameraUnavailable);
  }
  final problems = <ReasonCode, int>{};
  var usable = 0;
  for (final f in frames) {
    final p = faceFrameProblem(f);
    if (p == null) {
      usable++;
    } else {
      problems[p] = (problems[p] ?? 0) + 1;
    }
  }
  final fraction = usable / frames.length;
  if (fraction >= minFraction) {
    return ModalityQuality(Modality.face, QualityStatus.valid, value: fraction);
  }
  final dominant = problems.entries.reduce((a, b) => a.value >= b.value ? a : b);
  return ModalityQuality(Modality.face, QualityStatus.excluded,
      reason: dominant.key, value: fraction);
}

/// Background noise from windows known not to contain the caregiver's call.
ModalityQuality assessAudioFloor(List<AudioLevel> quietWindows,
    {required bool available, bool permissionDenied = false}) {
  if (!available) {
    return ModalityQuality(Modality.audio, QualityStatus.unavailable,
        reason: permissionDenied
            ? ReasonCode.microphonePermissionDenied
            : ReasonCode.microphoneUnavailable);
  }
  final floor = median(quietWindows.map((a) => a.rmsDb));
  if (floor == null) {
    return const ModalityQuality(Modality.audio, QualityStatus.unavailable,
        reason: ReasonCode.microphoneUnavailable);
  }
  final ok = floor <= P.maxNoiseFloorDb;
  return ModalityQuality(
      Modality.audio, ok ? QualityStatus.valid : QualityStatus.excluded,
      reason: ok ? null : ReasonCode.tooNoisy, value: floor);
}

/// Detects the onset of a caregiver's call: the first run of
/// [P.callOnsetWindows] consecutive windows clearly above the noise floor.
///
/// Returns the onset time, or null. Shared by the live controller (to advance
/// the activity) and the analyzer (to recompute timing from stored samples).
int? detectCallOnset(List<AudioLevel> levels, double noiseFloorDb) {
  final threshold = (noiseFloorDb + P.callOnsetAboveFloorDb) > P.callOnsetMinDb
      ? noiseFloorDb + P.callOnsetAboveFloorDb
      : P.callOnsetMinDb;
  var run = 0;
  for (var i = 0; i < levels.length; i++) {
    if (levels[i].rmsDb >= threshold) {
      run++;
      if (run >= P.callOnsetWindows) return levels[i - run + 1].tMs;
    } else {
      run = 0;
    }
  }
  return null;
}
