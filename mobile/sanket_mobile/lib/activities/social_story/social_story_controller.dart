import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/calibration.dart';
import '../../core/prototype_parameters.dart';
import '../../core/quality.dart';
import '../../core/samples.dart';
import '../../runtime/activity_controller.dart';
import 'social_story_analyzer.dart';

class SocialStoryController extends ActivityController {
  SocialStoryController(super.ctx);

  static const _gapMs = 1200;
  static const _lineEveryMs = 5000;

  @override
  ActivityId get id => ActivityId.socialStory;
  @override
  ActivityAnalyzer get analyzer => const SocialStoryAnalyzer();
  @override
  int get expectedDurationMs => 2 * P.socialStorySegmentMs + _gapMs;

  late GazeRegion _firstSocialSide;
  int segment = -1;
  bool inGap = false;
  bool lookingAway = false;
  int _segmentStart = 0;

  /// Side of the talking guide in the current segment.
  GazeRegion get socialSide => segment <= 0
      ? _firstSocialSide
      : (_firstSocialSide == GazeRegion.left ? GazeRegion.right : GazeRegion.left);

  /// Which story line is showing (cycles every few seconds).
  int get line => segment < 0 ? 0 : ((now - _segmentStart) ~/ _lineEveryMs) % 4;

  @override
  void onStart() {
    _firstSocialSide = ctx.random.nextBool() ? GazeRegion.left : GazeRegion.right;
    _startSegment(0);
  }

  void _startSegment(int index) {
    segment = index;
    inGap = false;
    _segmentStart = now;
    record(SocialStoryAnalyzer.segmentStart, {'index': index, 'socialSide': socialSide.name});
    after(P.socialStorySegmentMs, () {
      record(SocialStoryAnalyzer.segmentEnd, {'index': index});
      if (index == 0) {
        inGap = true;
        after(_gapMs, () => _startSegment(1));
      } else {
        finish();
      }
    });
  }

  @override
  void onTick() {
    final recent = frames.where((f) => now - f.tMs <= 4000).toList();
    lookingAway = elapsedMs > 4000 && (recent.isEmpty || !recent.any(usableFaceFrame));
  }

  @override
  void onFrame(VisionFrame frame) {}
}
