/// Coarse gaze calibration based on head orientation.
///
/// Spec §8: a brief non-social calibration checks whether this child + device +
/// camera position + lighting can produce useful *coarse* gaze information at
/// large regions of interest. Sanket's prototype uses head yaw from on-device
/// face tracking (no iris tracking), which suits toddlers who orient with the
/// head, and only distinguishes left / centre / right of the screen.
///
/// Calibration is usable only when real samples at each target exist, the
/// left and right targets produce clearly separable head orientations, and
/// within-target variation is small. Otherwise gaze is excluded.
library;

import 'measurement.dart';
import 'prototype_parameters.dart';
import 'quality.dart';
import 'samples.dart';


enum CalibrationTarget { center, left, right, upper }

enum GazeRegion { left, center, right, uncertain }

/// When each target was shown during calibration.
class CalibrationStage {
  const CalibrationStage(this.target, this.startMs, this.endMs);
  final CalibrationTarget target;
  final int startMs, endMs;
}

class CalibrationResult {
  const CalibrationResult({
    required this.usable,
    this.reason,
    this.centerYaw,
    this.leftYaw,
    this.rightYaw,
    this.noiseDeg,
    this.samples = const {},
    this.verticalSeparationDeg,
  });

  final bool usable;
  final ReasonCode? reason;
  final double? centerYaw, leftYaw, rightYaw, noiseDeg;
  final Map<CalibrationTarget, int> samples;
  final double? verticalSeparationDeg;

  double? get separationDeg => leftYaw == null || rightYaw == null
      ? null
      : (leftYaw! - rightYaw!).abs();

  static const notRun = CalibrationResult(
      usable: false, reason: ReasonCode.gazeNotCalibrated);

  Map<String, Object?> toJson() => {
        'usable': usable,
        'reason': reason?.name,
        'centerYaw': centerYaw,
        'leftYaw': leftYaw,
        'rightYaw': rightYaw,
        'noiseDeg': noiseDeg,
        'samples': {for (final e in samples.entries) e.key.name: e.value},
        'verticalSeparationDeg': verticalSeparationDeg,
      };

  factory CalibrationResult.fromJson(Map<String, dynamic> j) =>
      CalibrationResult(
        usable: j['usable'] as bool,
        reason: j['reason'] == null
            ? null
            : ReasonCode.values.byName(j['reason'] as String),
        centerYaw: (j['centerYaw'] as num?)?.toDouble(),
        leftYaw: (j['leftYaw'] as num?)?.toDouble(),
        rightYaw: (j['rightYaw'] as num?)?.toDouble(),
        noiseDeg: (j['noiseDeg'] as num?)?.toDouble(),
        samples: {
          for (final e in (j['samples'] as Map? ?? {}).entries)
            CalibrationTarget.values.byName(e.key as String): e.value as int
        },
        verticalSeparationDeg: (j['verticalSeparationDeg'] as num?)?.toDouble(),
      );

  ModalityQuality get quality => usable
      ? ModalityQuality(Modality.gaze, QualityStatus.valid, value: separationDeg)
      : ModalityQuality(Modality.gaze, QualityStatus.excluded,
          reason: reason ?? ReasonCode.gazeCalibrationUnusable,
          value: separationDeg);
}

class GazeCalibrator {
  const GazeCalibrator();

  CalibrationResult evaluate(
      List<VisionFrame> frames, List<CalibrationStage> stages) {
    final yawByTarget = <CalibrationTarget, List<double>>{};
    final pitchByTarget = <CalibrationTarget, List<double>>{};
    var dark = 0, total = 0;
    for (final stage in stages) {
      final window =
          framesBetween(frames, stage.startMs + P.calibrationSettleMs, stage.endMs);
      total += window.length;
      for (final f in window) {
        if (f.lighting < P.minLighting) dark++;
        if (!usableGazeFrame(f)) continue;
        yawByTarget.putIfAbsent(stage.target, () => []).add(f.face!.yawDeg);
        pitchByTarget.putIfAbsent(stage.target, () => []).add(f.face!.pitchDeg);
      }
    }
    final counts = {
      for (final t in CalibrationTarget.values) t: yawByTarget[t]?.length ?? 0
    };
    final required = [
      CalibrationTarget.center,
      CalibrationTarget.left,
      CalibrationTarget.right
    ];
    if (required.any((t) => counts[t]! < P.minSamplesPerCalibrationTarget)) {
      final reason = total > 0 && dark > total / 2
          ? ReasonCode.tooDark
          : total == 0
              ? ReasonCode.cameraUnavailable
              : ReasonCode.calibrationTooFewSamples;
      return CalibrationResult(usable: false, reason: reason, samples: counts);
    }

    final c = median(yawByTarget[CalibrationTarget.center]!)!;
    final l = median(yawByTarget[CalibrationTarget.left]!)!;
    final r = median(yawByTarget[CalibrationTarget.right]!)!;
    final sds = [
      for (final t in required) standardDeviation(yawByTarget[t]!) ?? 0
    ];
    final noise = mean(sds)!;
    final separation = (l - r).abs();
    double? vertical;
    final up = pitchByTarget[CalibrationTarget.upper];
    if (up != null && up.length >= P.minSamplesPerCalibrationTarget) {
      vertical = (median(up)! - median(pitchByTarget[CalibrationTarget.center]!)!).abs();
    }

    ReasonCode? reason;
    if (noise > P.maxCalibrationNoiseDeg) {
      reason = ReasonCode.calibrationUnstable;
    } else if (separation < P.minLeftRightSeparationDeg ||
        separation < noise * P.separationToNoiseRatio ||
        // The centre must lie between left and right.
        !((c - l) * (c - r) < 0)) {
      reason = ReasonCode.calibrationTargetsNotSeparable;
    }
    return CalibrationResult(
      usable: reason == null,
      reason: reason,
      centerYaw: c,
      leftYaw: l,
      rightYaw: r,
      noiseDeg: noise,
      samples: counts,
      verticalSeparationDeg: vertical,
    );
  }
}

/// Maps a head yaw to a coarse screen region using a usable calibration.
/// Yaw values that are not clearly closer to one calibrated region are
/// [GazeRegion.uncertain] rather than forced into a region.
class CoarseGazeClassifier {
  CoarseGazeClassifier(this.calibration)
      : assert(calibration.usable, 'calibration must be usable');
  final CalibrationResult calibration;

  GazeRegion classify(VisionFrame frame) {
    if (!usableGazeFrame(frame)) return GazeRegion.uncertain;
    final yaw = frame.face!.yawDeg;
    final d = <GazeRegion, double>{
      GazeRegion.left: (yaw - calibration.leftYaw!).abs(),
      GazeRegion.center: (yaw - calibration.centerYaw!).abs(),
      GazeRegion.right: (yaw - calibration.rightYaw!).abs(),
    };
    final sorted = d.entries.toList()..sort((a, b) => a.value.compareTo(b.value));
    final margin = (calibration.noiseDeg ?? 0) * 0.5;
    if (sorted[1].value - sorted[0].value < margin) return GazeRegion.uncertain;
    return sorted[0].key;
  }
}
