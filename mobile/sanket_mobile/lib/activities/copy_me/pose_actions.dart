import 'dart:math' as math;

import '../../core/prototype_parameters.dart';
import '../../core/samples.dart';

enum CopyAction { handsUp, clap, touchHead }

class DetectedAction {
  const DetectedAction(this.action, this.tMs);
  final CopyAction action;
  final int tMs;
}

/// Rough, rule-based action recognition from on-device pose landmarks.
///
/// Spec §7 lists Copy Me signals as "pose sequence, action onset, latency,
/// rough fidelity" with *emerging* evidence; these geometric rules are a
/// bounded prototype of that, not a validated imitation measure.
class PoseActionDetector {
  const PoseActionDetector();

  static const _min = P.minPoseLikelihood;

  /// Enough of the upper body is visible to recognise the actions.
  static bool framingOk(PoseObservation? pose) {
    if (pose == null) return false;
    return pose.reliable(PosePoint.nose, _min) != null &&
        pose.reliable(PosePoint.leftShoulder, _min) != null &&
        pose.reliable(PosePoint.rightShoulder, _min) != null &&
        (pose.reliable(PosePoint.leftWrist, _min) != null ||
            pose.reliable(PosePoint.rightWrist, _min) != null);
  }

  /// Static postures (hands up, hand on head) for a single frame.
  CopyAction? posture(PoseObservation pose) {
    final nose = pose.reliable(PosePoint.nose, _min);
    final ls = pose.reliable(PosePoint.leftShoulder, _min);
    final rs = pose.reliable(PosePoint.rightShoulder, _min);
    if (nose == null || ls == null || rs == null) return null;
    final unit = _dist(ls, rs);
    if (unit < 0.02) return null;
    final lw = pose.reliable(PosePoint.leftWrist, _min);
    final rw = pose.reliable(PosePoint.rightWrist, _min);

    bool above(PoseLandmark w, double ratio) => nose.y - w.y >= ratio * unit;
    if (lw != null &&
        rw != null &&
        above(lw, P.handsUpAboveNoseRatio) &&
        above(rw, P.handsUpAboveNoseRatio) &&
        _dist(lw, rw) > P.clapOpenRatio * unit) {
      return CopyAction.handsUp;
    }
    for (final w in [lw, rw]) {
      if (w == null) continue;
      if (_dist(w, nose) <= P.touchHeadDistanceRatio * unit &&
          w.y <= nose.y + P.touchHeadBelowNoseTolerance * unit) {
        return CopyAction.touchHead;
      }
    }
    return null;
  }

  /// First action in [frames]: a posture held for [P.copyActionFrames]
  /// consecutive pose frames, or a clap (wrists apart, then together in front
  /// of the body within [P.clapWindowMs]).
  DetectedAction? detect(List<VisionFrame> frames) {
    CopyAction? run;
    var runLength = 0;
    int? runStart;
    int? lastOpenMs;
    for (final f in frames) {
      final pose = f.pose;
      if (pose == null) {
        run = null;
        runLength = 0;
        continue;
      }
      final p = posture(pose);
      if (p != null && p == run) {
        runLength++;
      } else {
        run = p;
        runLength = p == null ? 0 : 1;
        runStart = f.tMs;
      }
      if (run != null && runLength >= P.copyActionFrames) {
        return DetectedAction(run, runStart!);
      }

      final ratio = _wristRatio(pose);
      final nose = pose.reliable(PosePoint.nose, _min);
      if (ratio != null && nose != null) {
        if (ratio >= P.clapOpenRatio) lastOpenMs = f.tMs;
        final lw = pose.reliable(PosePoint.leftWrist, _min)!;
        final rw = pose.reliable(PosePoint.rightWrist, _min)!;
        final inFront = lw.y > nose.y && rw.y > nose.y;
        if (ratio <= P.clapClosedRatio &&
            inFront &&
            lastOpenMs != null &&
            f.tMs - lastOpenMs <= P.clapWindowMs) {
          return DetectedAction(CopyAction.clap, f.tMs);
        }
      }
    }
    return null;
  }

  double? _wristRatio(PoseObservation pose) {
    final ls = pose.reliable(PosePoint.leftShoulder, _min);
    final rs = pose.reliable(PosePoint.rightShoulder, _min);
    final lw = pose.reliable(PosePoint.leftWrist, _min);
    final rw = pose.reliable(PosePoint.rightWrist, _min);
    if (ls == null || rs == null || lw == null || rw == null) return null;
    final unit = _dist(ls, rs);
    return unit < 0.02 ? null : _dist(lw, rw) / unit;
  }

  static double _dist(PoseLandmark a, PoseLandmark b) =>
      math.sqrt((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y));
}
