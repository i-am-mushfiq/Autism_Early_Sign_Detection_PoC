import 'package:flutter/widgets.dart';

import '../core/activity_catalog.dart';
import '../core/interpretation.dart';
import '../core/measurement.dart';
import '../core/session.dart';
import 'strings.dart';

enum AppLanguage { en, bn }

/// Resolves [T] keys for one language, fills `{placeholders}` and formats
/// numbers with the language's digits.
class Strings {
  const Strings(this.language);
  final AppLanguage language;

  static final _placeholder = RegExp(r'\{(\w+)\}');
  static const _bnDigits = ['০', '১', '২', '৩', '৪', '৫', '৬', '৭', '৮', '৯'];

  bool get isBangla => language == AppLanguage.bn;

  String raw(T key) => isBangla ? key.bn : key.en;

  /// `{guide}` is always available; other placeholders come from [args].
  /// Numeric arguments are rendered with localized digits.
  String call(T key, [Map<String, Object?> args = const {}]) {
    return raw(key).replaceAllMapped(_placeholder, (m) {
      final name = m.group(1)!;
      if (name == 'guide') return raw(T.guideName);
      final value = args[name];
      if (value == null) return m.group(0)!;
      return value is num ? number(value) : value.toString();
    });
  }

  String number(num value, {int decimals = 0}) =>
      digits(value is int ? value.toString() : value.toStringAsFixed(decimals));

  /// Replaces ASCII digits with the language's digits.
  String digits(String text) {
    if (!isBangla) return text;
    return text.split('').map((c) {
      final d = int.tryParse(c);
      return d == null ? c : _bnDigits[d];
    }).join();
  }

  String dateTime(DateTime d) {
    final l = d.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return digits('${l.year}-${two(l.month)}-${two(l.day)} ${two(l.hour)}:${two(l.minute)}');
  }

  String seconds(num ms) => number(ms / 1000, decimals: 1);

  static Set<String> placeholdersOf(String text) =>
      {for (final m in _placeholder.allMatches(text)) m.group(1)!};

  // ── Domain vocabulary ────────────────────────────────────────────────
  String activityName(ActivityId id) => call(switch (id) {
        ActivityId.socialStory => T.storyName,
        ActivityId.nameResponse => T.nameName,
        ActivityId.followMyLook => T.lookName,
        ActivityId.bubbleTrail => T.bubbleName,
        ActivityId.copyMe => T.copyName,
        ActivityId.switchIt => T.switchName,
      });

  String construct(ActivityId id) => call(switch (id) {
        ActivityId.socialStory => T.storyConstruct,
        ActivityId.nameResponse => T.nameConstruct,
        ActivityId.followMyLook => T.lookConstruct,
        ActivityId.bubbleTrail => T.bubbleConstruct,
        ActivityId.copyMe => T.copyConstruct,
        ActivityId.switchIt => T.switchConstruct,
      });

  String parentInstruction(ActivityId id, String name) => call(
      switch (id) {
        ActivityId.socialStory => T.storyParent,
        ActivityId.nameResponse => T.nameParent,
        ActivityId.followMyLook => T.lookParent,
        ActivityId.bubbleTrail => T.bubbleParent,
        ActivityId.copyMe => T.copyParent,
        ActivityId.switchIt => T.switchParent,
      },
      {'name': name});

  String activityStatus(ActivityStatus s) => call(switch (s) {
        ActivityStatus.valid => T.aValid,
        ActivityStatus.insufficient => T.aInsufficient,
        ActivityStatus.nonParticipation => T.aNonParticipation,
        ActivityStatus.skipped => T.aSkipped,
        ActivityStatus.notOffered => T.aNotOffered,
      });

  String sessionStatus(SessionStatus s) => call(switch (s) {
        SessionStatus.completed => T.sessionCompleted,
        SessionStatus.stoppedEarly => T.sessionStopped,
        SessionStatus.interrupted => T.sessionInterrupted,
        SessionStatus.timeLimit => T.sessionTimeLimit,
        SessionStatus.inProgress => T.sessionInProgress,
      });

  String stateTitle(ObservationState s) => call(switch (s) {
        ObservationState.noStrongSignal => T.stateNoStrongTitle,
        ObservationState.monitor => T.stateMonitorTitle,
        ObservationState.discussProfessional => T.stateDiscussTitle,
        ObservationState.inconclusive => T.stateInconclusiveTitle,
      });

  String stateBody(ObservationState s, String name) => call(
      switch (s) {
        ObservationState.noStrongSignal => T.stateNoStrongBody,
        ObservationState.monitor => T.stateMonitorBody,
        ObservationState.discussProfessional => T.stateDiscussBody,
        ObservationState.inconclusive => T.stateInconclusiveBody,
      },
      {'name': name});

  String nextStep(ObservationState s, String name) => call(
      switch (s) {
        ObservationState.noStrongSignal => T.nextNoStrong,
        ObservationState.monitor => T.nextMonitor,
        ObservationState.discussProfessional => T.nextDiscuss,
        ObservationState.inconclusive => T.nextInconclusive,
      },
      {'name': name});

  String factor(ContextFactor f) => call(switch (f) {
        ContextFactor.hearingConcern => T.factorHearing,
        ContextFactor.visionConcern => T.factorVision,
        ContextFactor.motorDifficulty => T.factorMotor,
      });

  String reason(ReasonCode r, String name) => call(reasonKey(r), {'name': name});

  static T reasonKey(ReasonCode r) => switch (r) {
        ReasonCode.cameraUnavailable => T.rCameraUnavailable,
        ReasonCode.cameraPermissionDenied => T.rCameraPermissionDenied,
        ReasonCode.lowFrameRate => T.rLowFrameRate,
        ReasonCode.tooDark => T.rTooDark,
        ReasonCode.tooBright => T.rTooBright,
        ReasonCode.faceNotVisible => T.rFaceNotVisible,
        ReasonCode.faceTooFar => T.rFaceTooFar,
        ReasonCode.faceTooClose => T.rFaceTooClose,
        ReasonCode.eyesNotVisible => T.rEyesNotVisible,
        ReasonCode.gazeNotCalibrated => T.rGazeNotCalibrated,
        ReasonCode.gazeCalibrationUnusable => T.rGazeCalibrationUnusable,
        ReasonCode.calibrationTooFewSamples => T.rCalibrationTooFewSamples,
        ReasonCode.calibrationTargetsNotSeparable => T.rCalibrationTargetsNotSeparable,
        ReasonCode.calibrationUnstable => T.rCalibrationUnstable,
        ReasonCode.microphoneUnavailable => T.rMicrophoneUnavailable,
        ReasonCode.microphonePermissionDenied => T.rMicrophonePermissionDenied,
        ReasonCode.tooNoisy => T.rTooNoisy,
        ReasonCode.callNotDetected => T.rCallNotDetected,
        ReasonCode.callTimedByCaregiver => T.rCallTimedByCaregiver,
        ReasonCode.notAttendingBeforePrompt => T.rNotAttendingBeforePrompt,
        ReasonCode.alreadyLookingAtTarget => T.rAlreadyLookingAtTarget,
        ReasonCode.faceLostWithoutTurn => T.rFaceLostWithoutTurn,
        ReasonCode.bodyNotVisible => T.rBodyNotVisible,
        ReasonCode.tooFewTouches => T.rTooFewTouches,
        ReasonCode.noTouches => T.rNoTouches,
        ReasonCode.palmContact => T.rPalmContact,
        ReasonCode.tooFewResponses => T.rTooFewResponses,
        ReasonCode.noResponses => T.rNoResponses,
        ReasonCode.tooFewValidTrials => T.rTooFewValidTrials,
        ReasonCode.pausedByCaregiver => T.rPausedByCaregiver,
        ReasonCode.skippedByCaregiver => T.rSkippedByCaregiver,
        ReasonCode.stoppedEarly => T.rStoppedEarly,
        ReasonCode.notOfferedForAge => T.rNotOfferedForAge,
        ReasonCode.sessionTimeLimit => T.rSessionTimeLimit,
        ReasonCode.noParticipation => T.rNoParticipation,
      };
}

class LocaleScope extends InheritedWidget {
  const LocaleScope({super.key, required this.strings, required super.child});
  final Strings strings;

  static Strings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LocaleScope>()?.strings ??
      const Strings(AppLanguage.en);

  @override
  bool updateShouldNotify(LocaleScope oldWidget) => oldWidget.strings.language != strings.language;
}

extension LocalizedContext on BuildContext {
  Strings get s => LocaleScope.of(this);
}
