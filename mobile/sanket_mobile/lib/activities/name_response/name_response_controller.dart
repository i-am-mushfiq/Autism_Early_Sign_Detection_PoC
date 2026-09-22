import 'package:flutter/services.dart';

import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/measurement.dart';
import '../../core/prototype_parameters.dart';
import '../../core/quality.dart';
import '../../core/samples.dart';
import '../../runtime/activity_controller.dart';
import 'name_response_analyzer.dart';

enum NamePhase { waitingAttention, prompting, responseWindow, between }

class NameResponseController extends ActivityController {
  NameResponseController(super.ctx);

  @override
  ActivityId get id => ActivityId.nameResponse;
  @override
  ActivityAnalyzer get analyzer => const NameResponseAnalyzer();
  @override
  bool get needsAudio => true;
  @override
  int get expectedDurationMs => P.nameTrials * 10000;

  NamePhase namePhase = NamePhase.waitingAttention;
  int attempt = 0;
  int validTrials = 0;

  /// True when call timing must come from the caregiver's tap (no usable mic).
  bool tapFallback = false;
  bool lastCallMissed = false;

  int _token = 0;
  int? _attentionSince;
  int? _lastFacingT;
  int _promptMs = 0;
  double? _floorDb;
  int _attentionTimeoutsInRow = 0;

  double get _centerYaw =>
      ctx.calibration.usable ? ctx.calibration.centerYaw! : 0;

  @override
  double get progress => phase == ActivityPhase.running
      ? (validTrials / P.nameTrials).clamp(0.0, 0.98)
      : super.progress;

  @override
  void onStart() {
    attempt = 0;
    validTrials = 0;
    _attentionTimeoutsInRow = 0;
    _beginTrial();
  }

  void _beginTrial() {
    attempt++;
    final token = ++_token;
    namePhase = NamePhase.waitingAttention;
    _attentionSince = null;
    _lastFacingT = null;
    record(NameResponseAnalyzer.trialStart, {'index': attempt});
    after(P.nameAttentionTimeoutMs, () {
      if (token != _token || namePhase != NamePhase.waitingAttention) return;
      record(NameResponseAnalyzer.attentionTimeout);
      _attentionTimeoutsInRow++;
      _endTrial();
    });
  }

  @override
  void onFrame(VisionFrame frame) {
    final f = frame;
    if (namePhase != NamePhase.waitingAttention) return;
    final facing = usableFaceFrame(f) &&
        (f.face!.yawDeg - _centerYaw).abs() <= P.nameFacingMaxYawDeg;
    if (!facing) {
      // A brief tracker miss (blink, momentary jitter) doesn't restart the
      // streak; only a longer gap means the child actually looked away.
      if (_attentionSince != null &&
          f.tMs - _lastFacingT! > P.nameAttentionGapToleranceMs) {
        _attentionSince = null;
      }
      return;
    }
    _attentionSince ??= f.tMs;
    _lastFacingT = f.tMs;
    if (f.tMs - _attentionSince! >= P.nameAttentionMs) _prompt();
  }

  void _prompt() {
    final token = _token;
    _attentionTimeoutsInRow = 0;
    final quiet = [
      for (final a in audio)
        if (now - a.tMs <= 1200) a
    ];
    _floorDb = quiet.length >= 5 ? median(quiet.map((a) => a.rmsDb)) : null;
    tapFallback = !ctx.sensors.availability.microphone ||
        _floorDb == null ||
        _floorDb! > P.maxNoiseFloorDb;
    namePhase = NamePhase.prompting;
    _promptMs = now;
    lastCallMissed = false;
    HapticFeedback.mediumImpact();
    after(P.nameCallTimeoutMs, () {
      if (token != _token || namePhase != NamePhase.prompting) return;
      record(NameResponseAnalyzer.callTimeout);
      lastCallMissed = true;
      _endTrial();
    });
    notify();
  }

  @override
  void onAudio(AudioLevel level) {
    if (namePhase != NamePhase.prompting || tapFallback || _floorDb == null)
      return;
    final since = [
      for (final a in audio)
        if (a.tMs >= _promptMs) a
    ];
    final onset = detectCallOnset(since, _floorDb!);
    if (onset != null) _called('audio', onset);
  }

  /// The caregiver's "I called" button (fallback when the mic can't time it).
  void caregiverCalled() {
    if (phase != ActivityPhase.running || namePhase != NamePhase.prompting)
      return;
    _called('caregiver', now);
  }

  void _called(String source, int atMs) {
    record(
        NameResponseAnalyzer.call,
        {
          'source': source,
          if (_floorDb != null) 'floorDb': _floorDb!,
        },
        atMs);
    namePhase = NamePhase.responseWindow;
    final token = _token;
    after(atMs + P.nameResponseWindowMs - now, () {
      if (token == _token) _endTrial();
    });
    notify();
  }

  void _endTrial() {
    record(NameResponseAnalyzer.trialEnd);
    _token++;
    namePhase = NamePhase.between;
    validTrials = analyzer.analyze(capture()).validTrials;
    final done = validTrials >= P.nameTrials ||
        attempt >= P.nameMaxAttempts ||
        _attentionTimeoutsInRow >= P.nameStopAfterAttentionTimeouts;
    after(done ? 700 : 1800, done ? () => finish() : _beginTrial);
    notify();
  }

  @override
  void onCancelled() {
    _token++;
    namePhase = NamePhase.waitingAttention;
  }
}
