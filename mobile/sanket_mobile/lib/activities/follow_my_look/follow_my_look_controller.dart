import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/calibration.dart';
import '../../core/prototype_parameters.dart';
import '../../core/samples.dart';
import '../../runtime/activity_controller.dart';
import 'follow_my_look_analyzer.dart';

enum LookPhase { waitingCenter, looking, reward, between }

class FollowMyLookController extends ActivityController {
  FollowMyLookController(super.ctx);

  @override
  ActivityId get id => ActivityId.followMyLook;
  @override
  ActivityAnalyzer get analyzer => const FollowMyLookAnalyzer();
  @override
  int get expectedDurationMs =>
      P.lookTrials * (P.lookPreCueMs + P.lookWindowMs + P.lookRewardMs + 900);

  late final CoarseGazeClassifier? _classifier =
      ctx.calibration.usable ? CoarseGazeClassifier(ctx.calibration) : null;
  bool get gazeAvailable => _classifier != null;

  LookPhase lookPhase = LookPhase.waitingCenter;
  int trial = 0;

  /// Where the guide is looking (drives the animation).
  GazeRegion guideLook = GazeRegion.center;
  GazeRegion? target;
  GazeRegion? tapped;
  late List<GazeRegion> _sides;
  int _token = 0;
  int _centerRun = 0;
  int _waitStart = 0;

  @override
  double get progress => phase == ActivityPhase.running
      ? ((trial - 1).clamp(0, P.lookTrials) / P.lookTrials)
      : super.progress;

  @override
  void onStart() {
    _sides = [
      GazeRegion.left,
      GazeRegion.right,
      GazeRegion.left,
      GazeRegion.right
    ]..shuffle(ctx.random);
    trial = 0;
    _beginTrial();
  }

  void _beginTrial() {
    trial++;
    final token = ++_token;
    target = _sides[trial - 1];
    tapped = null;
    guideLook = GazeRegion.center;
    lookPhase = LookPhase.waitingCenter;
    _centerRun = 0;
    _waitStart = now;
    record(FollowMyLookAnalyzer.trialStart,
        {'index': trial, 'side': target!.name});
    if (!gazeAvailable) {
      // Without calibrated gaze, the guide still looks after a fixed pause so
      // tap responses can be recorded (reported with limited reliability).
      after(P.lookPreCueMs, () {
        if (token == _token) _cue();
      });
    }
    after(P.lookCenterTimeoutMs, () {
      if (token != _token || lookPhase != LookPhase.waitingCenter) return;
      record(FollowMyLookAnalyzer.centerTimeout);
      _endTrial();
    });
  }

  @override
  void onFrame(VisionFrame frame) {
    final f = frame;
    if (lookPhase != LookPhase.waitingCenter || _classifier == null) return;
    _centerRun =
        _classifier.classify(f) == GazeRegion.center ? _centerRun + 1 : 0;
    // The guide first looks at the child for a moment before turning.
    if (_centerRun >= 2 && now - _waitStart >= 600) _cue();
  }

  void _cue() {
    if (lookPhase != LookPhase.waitingCenter) return;
    final token = _token;
    record(FollowMyLookAnalyzer.cue, {'side': target!.name});
    lookPhase = LookPhase.looking;
    guideLook = target!;
    after(P.lookWindowMs, () {
      if (token != _token) return;
      lookPhase = LookPhase.reward;
      after(P.lookRewardMs, () {
        if (token == _token) _endTrial();
      });
    });
    notify();
  }

  /// The child tapped one of the two toys.
  void tapToy(GazeRegion side) {
    if (phase != ActivityPhase.running ||
        lookPhase != LookPhase.looking ||
        tapped != null) return;
    tapped = side;
    record(FollowMyLookAnalyzer.tap, {'side': side.name});
    notify();
  }

  void _endTrial() {
    record(FollowMyLookAnalyzer.trialEnd);
    _token++;
    lookPhase = LookPhase.between;
    guideLook = GazeRegion.center;
    if (trial >= P.lookTrials) {
      after(500, () => finish());
    } else {
      after(900, _beginTrial);
    }
    notify();
  }

  @override
  void onCancelled() => _token++;
}
