import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/prototype_parameters.dart';
import '../../core/samples.dart';
import '../../runtime/activity_controller.dart';
import 'copy_me_analyzer.dart';
import 'pose_actions.dart';

enum CopyPhase { framing, demo, window, feedback, between }

class CopyMeController extends ActivityController {
  CopyMeController(super.ctx, {this.detector = const PoseActionDetector()});
  final PoseActionDetector detector;

  static const actions = [
    CopyAction.handsUp,
    CopyAction.clap,
    CopyAction.touchHead
  ];

  @override
  ActivityId get id => ActivityId.copyMe;
  @override
  ActivityAnalyzer get analyzer => const CopyMeAnalyzer();
  @override
  VisionMode get visionMode => VisionMode.pose;
  @override
  int get expectedDurationMs =>
      actions.length * (P.copyDemoMs + P.copyWindowMs + 2500);

  CopyPhase copyPhase = CopyPhase.framing;
  int trial = 0;
  CopyAction get action => actions[(trial - 1).clamp(0, actions.length - 1)];
  bool framed = false;
  DetectedAction? seen;

  int _token = 0;
  int _framedRun = 0;
  int _windowStart = 0;

  @override
  double get progress => phase == ActivityPhase.running
      ? ((trial - 1).clamp(0, actions.length) / actions.length)
      : super.progress;

  @override
  void onStart() {
    trial = 0;
    _beginTrial();
  }

  void _beginTrial() {
    trial++;
    final token = ++_token;
    seen = null;
    _framedRun = 0;
    copyPhase = CopyPhase.framing;
    record(CopyMeAnalyzer.trialStart, {'index': trial, 'action': action.name});
    after(P.copyFramingTimeoutMs, () {
      if (token != _token || copyPhase != CopyPhase.framing) return;
      record(CopyMeAnalyzer.framingTimeout);
      _endTrial();
    });
  }

  @override
  void onFrame(VisionFrame frame) {
    final f = frame;
    framed = PoseActionDetector.framingOk(f.pose);
    switch (copyPhase) {
      case CopyPhase.framing:
        _framedRun = framed ? _framedRun + 1 : 0;
        if (_framedRun >= 3) _demo();
      case CopyPhase.window:
        if (seen != null) return;
        final window = [
          for (final x in frames)
            if (x.tMs >= _windowStart) x
        ];
        final detected = detector.detect(window);
        if (detected != null) {
          seen = detected;
          final token = _token;
          // End the window shortly after a movement so the pace stays brisk.
          after(900, () {
            if (token == _token && copyPhase == CopyPhase.window)
              _closeWindow();
          });
          notify();
        }
      default:
        break;
    }
  }

  void _demo() {
    final token = _token;
    copyPhase = CopyPhase.demo;
    after(P.copyDemoMs, () {
      if (token != _token) return;
      _windowStart = now;
      record(CopyMeAnalyzer.windowStart);
      copyPhase = CopyPhase.window;
      after(P.copyWindowMs, () {
        if (token == _token && copyPhase == CopyPhase.window) _closeWindow();
      });
    });
    notify();
  }

  void _closeWindow() {
    final token = _token;
    record(CopyMeAnalyzer.windowEnd);
    copyPhase = CopyPhase.feedback;
    after(1100, () {
      if (token == _token) _endTrial();
    });
    notify();
  }

  void _endTrial() {
    _token++;
    copyPhase = CopyPhase.between;
    if (trial >= actions.length) {
      after(400, () => finish());
    } else {
      after(900, _beginTrial);
    }
    notify();
  }

  @override
  void onCancelled() => _token++;
}
