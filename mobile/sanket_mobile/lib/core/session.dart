import 'activity_capture.dart';
import 'calibration.dart';
import 'interpretation.dart';
import 'measurement.dart';
import 'prototype_parameters.dart';

enum TrialPhase {
  instructions,
  ready,
  running,
  paused,
  completed,
  skipped,
  stopped
}

/// Legal phase transitions for one activity attempt.
class ActivityStateMachine {
  TrialPhase phase = TrialPhase.instructions;

  static const _permitted = {
    TrialPhase.instructions: [
      TrialPhase.ready,
      TrialPhase.skipped,
      TrialPhase.stopped
    ],
    TrialPhase.ready: [
      TrialPhase.running,
      TrialPhase.skipped,
      TrialPhase.stopped
    ],
    TrialPhase.running: [
      TrialPhase.paused,
      TrialPhase.completed,
      TrialPhase.stopped
    ],
    TrialPhase.paused: [
      TrialPhase.ready,
      TrialPhase.skipped,
      TrialPhase.stopped
    ],
    TrialPhase.completed: [TrialPhase.ready],
    TrialPhase.skipped: <TrialPhase>[],
    TrialPhase.stopped: <TrialPhase>[],
  };

  bool canTransition(TrialPhase next) => _permitted[phase]!.contains(next);

  bool transition(TrialPhase next) {
    if (!canTransition(next)) return false;
    phase = next;
    return true;
  }
}

enum PrimaryLanguage { bangla, english, both }

enum OtherLanguage { none, bangla, english, other }

enum ScreenFamiliarity { low, medium, high }

class ChildProfile {
  const ChildProfile({
    required this.nickname,
    required this.ageMonths,
    this.primaryLanguage = PrimaryLanguage.bangla,
    this.otherLanguage = OtherLanguage.english,
    this.hearingConcern = false,
    this.visionConcern = false,
    this.motorDifficulty = false,
    this.priorConcern = false,
    this.screenFamiliarity = ScreenFamiliarity.medium,
  });

  final String nickname;
  final int ageMonths;
  final PrimaryLanguage primaryLanguage;
  final OtherLanguage otherLanguage;
  final bool hearingConcern, visionConcern, motorDifficulty, priorConcern;
  final ScreenFamiliarity screenFamiliarity;

  bool get ageSupported =>
      ageMonths >= PrototypeParameters.minAgeMonths &&
      ageMonths <= PrototypeParameters.maxAgeMonths;

  ChildContext get context => ChildContext(
      ageMonths: ageMonths,
      hearingConcern: hearingConcern,
      visionConcern: visionConcern,
      motorDifficulty: motorDifficulty);

  Map<String, Object?> toJson() => {
        'nickname': nickname,
        'ageMonths': ageMonths,
        'primaryLanguage': primaryLanguage.name,
        'otherLanguage': otherLanguage.name,
        'hearingConcern': hearingConcern,
        'visionConcern': visionConcern,
        'motorDifficulty': motorDifficulty,
        'priorConcern': priorConcern,
        'screenFamiliarity': screenFamiliarity.name,
      };

  factory ChildProfile.fromJson(Map<String, dynamic> j) => ChildProfile(
        nickname: j['nickname'] as String,
        ageMonths: j['ageMonths'] as int,
        primaryLanguage:
            PrimaryLanguage.values.byName(j['primaryLanguage'] as String),
        otherLanguage:
            OtherLanguage.values.byName(j['otherLanguage'] as String),
        hearingConcern: j['hearingConcern'] as bool,
        visionConcern: j['visionConcern'] as bool,
        motorDifficulty: j['motorDifficulty'] as bool,
        priorConcern: j['priorConcern'] as bool? ?? false,
        screenFamiliarity:
            ScreenFamiliarity.values.byName(j['screenFamiliarity'] as String),
      );
}

/// Separate consent choices (spec §5 "Introduction and consent", §10).
class ConsentChoices {
  const ConsentChoices({
    this.processing = false,
    this.storeOnDevice = false,
    this.shareWithProfessional = false,
    this.research = false,
  });

  /// Required: process camera and microphone on this device during the session.
  final bool processing;

  /// Optional: keep derived observations on this device for history.
  final bool storeOnDevice;

  /// Optional: allow derived observations to be shared with a professional or
  /// programme later. This version never uploads; the choice is recorded.
  final bool shareWithProfessional;

  /// Optional, separate: de-identified research use. Recorded only.
  final bool research;

  bool get canStart => processing;

  ConsentChoices copyWith(
          {bool? processing,
          bool? storeOnDevice,
          bool? shareWithProfessional,
          bool? research}) =>
      ConsentChoices(
        processing: processing ?? this.processing,
        storeOnDevice: storeOnDevice ?? this.storeOnDevice,
        shareWithProfessional:
            shareWithProfessional ?? this.shareWithProfessional,
        research: research ?? this.research,
      );

  Map<String, Object?> toJson() => {
        'processing': processing,
        'storeOnDevice': storeOnDevice,
        'shareWithProfessional': shareWithProfessional,
        'research': research,
        // Raw media retention is not offered by this version (spec §10 default).
        'rawMediaRetention': false,
      };

  factory ConsentChoices.fromJson(Map<String, dynamic> j) => ConsentChoices(
        processing: j['processing'] as bool,
        storeOnDevice: j['storeOnDevice'] as bool,
        shareWithProfessional: j['shareWithProfessional'] as bool? ?? false,
        research: j['research'] as bool? ?? false,
      );
}

enum SessionStatus {
  /// Activities are running. A record left in this state was interrupted.
  inProgress,
  completed,

  /// The caregiver ended the session before all activities.
  stoppedEarly,

  /// The app closed during the session; recovered on next launch.
  interrupted,

  /// The enforced maximum duration was reached.
  timeLimit,
}

class SessionRecord {
  SessionRecord({
    required this.id,
    required this.startedAt,
    required this.profile,
    required this.consents,
    required this.sensors,
    required this.appLanguage,
    this.status = SessionStatus.inProgress,
    this.endedAt,
    this.calibration = CalibrationResult.notRun,
    List<ActivityObservation>? observations,
    this.outcome,
  }) : observations = observations ?? [];

  final String id;
  final DateTime startedAt;
  final ChildProfile profile;
  final ConsentChoices consents;
  final SensorAvailability sensors;
  final String appLanguage;
  SessionStatus status;
  DateTime? endedAt;
  CalibrationResult calibration;
  final List<ActivityObservation> observations;
  SessionOutcome? outcome;

  bool get finished => status != SessionStatus.inProgress;

  /// Replaces an earlier attempt of the same activity (retry), keeping order.
  void putObservation(ActivityObservation o) {
    final i = observations.indexWhere((e) => e.activity == o.activity);
    if (i >= 0) {
      observations[i] = o;
    } else {
      observations.add(o);
    }
  }

  /// Reproducible: the outcome is a pure function of stored observations,
  /// the stored profile and the rules.
  SessionOutcome computeOutcome() =>
      const SessionInterpreter().interpret(observations, profile.context);

  void finish(SessionStatus finalStatus, DateTime at) {
    if (finished) return;
    status = finalStatus;
    endedAt = at;
    outcome = computeOutcome();
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'startedAt': startedAt.toIso8601String(),
        'endedAt': endedAt?.toIso8601String(),
        'status': status.name,
        'profile': profile.toJson(),
        'consents': consents.toJson(),
        'sensors': {
          'camera': sensors.camera,
          'microphone': sensors.microphone,
          'cameraDenied': sensors.cameraDenied,
          'microphoneDenied': sensors.microphoneDenied,
        },
        'appLanguage': appLanguage,
        'calibration': calibration.toJson(),
        'observations': observations.map((o) => o.toJson()).toList(),
        'outcome': outcome?.toJson(),
      };

  factory SessionRecord.fromJson(Map<String, dynamic> j) {
    final s = Map<String, dynamic>.from(j['sensors'] as Map);
    return SessionRecord(
      id: j['id'] as String,
      startedAt: DateTime.parse(j['startedAt'] as String),
      endedAt:
          j['endedAt'] == null ? null : DateTime.parse(j['endedAt'] as String),
      status: SessionStatus.values.byName(j['status'] as String),
      profile:
          ChildProfile.fromJson(Map<String, dynamic>.from(j['profile'] as Map)),
      consents: ConsentChoices.fromJson(
          Map<String, dynamic>.from(j['consents'] as Map)),
      sensors: SensorAvailability(
          camera: s['camera'] as bool,
          microphone: s['microphone'] as bool,
          cameraDenied: s['cameraDenied'] as bool? ?? false,
          microphoneDenied: s['microphoneDenied'] as bool? ?? false),
      appLanguage: j['appLanguage'] as String,
      calibration: CalibrationResult.fromJson(
          Map<String, dynamic>.from(j['calibration'] as Map)),
      observations: [
        for (final o in j['observations'] as List)
          ActivityObservation.fromJson(Map<String, dynamic>.from(o as Map))
      ],
      outcome: j['outcome'] == null
          ? null
          : SessionOutcome.fromJson(
              Map<String, dynamic>.from(j['outcome'] as Map)),
    );
  }
}
