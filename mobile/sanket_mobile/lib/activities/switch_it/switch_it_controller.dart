import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/prototype_parameters.dart';
import '../../core/samples.dart';
import '../../runtime/activity_controller.dart';
import 'switch_it_analyzer.dart';

enum SwitchPhase { showing, feedback, switching }

class SwitchItController extends ActivityController {
  SwitchItController(super.ctx);

  static const _feedbackMs = 700;
  static const _switchScreenMs = 2600;

  @override
  ActivityId get id => ActivityId.switchIt;
  @override
  ActivityAnalyzer get analyzer => const SwitchItAnalyzer();
  @override
  VisionMode get visionMode => VisionMode.off;
  @override
  bool get requiresCamera => false;
  @override
  int get expectedDurationMs =>
      P.switchTrialsPerRule * 2 * 2600 + _switchScreenMs;

  int get totalTrials => P.switchTrialsPerRule * 2;

  SwitchPhase switchPhase = SwitchPhase.showing;
  int trial = 0;
  SwitchRule get rule =>
      trial <= P.switchTrialsPerRule ? SwitchRule.bird : SwitchRule.ball;

  /// Whether the bird is on the left in the current trial (ball opposite).
  bool birdOnLeft = true;
  SwitchRule? chosen;

  int _token = 0;
  int _shownAt = 0;
  int _omissionsInRow = 0;

  @override
  double get progress => phase == ActivityPhase.running
      ? ((trial - 1).clamp(0, totalTrials) / totalTrials)
      : super.progress;

  @override
  void onStart() {
    trial = 0;
    _omissionsInRow = 0;
    _nextTrial();
  }

  void _nextTrial() {
    if (trial >= totalTrials) {
      finish();
      return;
    }
    if (trial == P.switchTrialsPerRule &&
        switchPhase != SwitchPhase.switching) {
      // Announce the new rule before the first ball trial.
      switchPhase = SwitchPhase.switching;
      record(SwitchItAnalyzer.ruleSwitch);
      final token = ++_token;
      after(_switchScreenMs, () {
        if (token == _token) _showTrial();
      });
      notify();
      return;
    }
    _showTrial();
  }

  void _showTrial() {
    trial++;
    final token = ++_token;
    chosen = null;
    birdOnLeft = ctx.random.nextBool();
    switchPhase = SwitchPhase.showing;
    _shownAt = now;
    record(SwitchItAnalyzer.trialStart, {
      'index': trial,
      'rule': rule.name,
      'targetSide': (rule == SwitchRule.bird) == birdOnLeft ? 'left' : 'right',
    });
    after(P.switchTrialTimeoutMs, () {
      if (token != _token || switchPhase != SwitchPhase.showing) return;
      record(SwitchItAnalyzer.omission, {'index': trial});
      _omissionsInRow++;
      if (_omissionsInRow >= P.switchStopAfterOmissions) {
        record(SwitchItAnalyzer.stoppedForOmissions);
        finish();
        return;
      }
      _token++;
      _nextTrial();
    });
    notify();
  }

  /// The child tapped the bird or the ball.
  void tap(SwitchRule item) {
    if (phase != ActivityPhase.running || switchPhase != SwitchPhase.showing)
      return;
    chosen = item;
    _omissionsInRow = 0;
    record(SwitchItAnalyzer.response,
        {'index': trial, 'chosen': item.name, 'rtMs': now - _shownAt});
    switchPhase = SwitchPhase.feedback;
    final token = ++_token;
    after(_feedbackMs, () {
      if (token == _token) _nextTrial();
    });
    notify();
  }

  /// Rule the child should follow on screen right now (the switch screen
  /// already announces the new rule).
  SwitchRule get displayedRule =>
      switchPhase == SwitchPhase.switching ? SwitchRule.ball : rule;

  @override
  void onCancelled() => _token++;
}
