/// Non-clinical measurement model for Sanket.
///
/// Pipeline: capture (derived samples + activity events) → quality check →
/// feature extraction → interpretation. Every stage produces data that can be
/// stored and re-interpreted deterministically.
library;

import 'activity_catalog.dart';

enum Modality { camera, lighting, face, gaze, audio, touch, pose }

enum QualityStatus { valid, limited, excluded, unavailable }

/// Why a modality, trial or activity was not (fully) usable. Stored by name.
enum ReasonCode {
  cameraUnavailable,
  cameraPermissionDenied,
  lowFrameRate,
  tooDark,
  tooBright,
  faceNotVisible,
  faceTooFar,
  faceTooClose,
  eyesNotVisible,
  gazeNotCalibrated,
  gazeCalibrationUnusable,
  calibrationTooFewSamples,
  calibrationTargetsNotSeparable,
  calibrationUnstable,
  microphoneUnavailable,
  microphonePermissionDenied,
  tooNoisy,
  callNotDetected,
  callTimedByCaregiver,
  notAttendingBeforePrompt,
  alreadyLookingAtTarget,
  faceLostWithoutTurn,
  bodyNotVisible,
  tooFewTouches,
  noTouches,
  palmContact,
  tooFewResponses,
  noResponses,
  tooFewValidTrials,
  pausedByCaregiver,
  skippedByCaregiver,
  stoppedEarly,
  notOfferedForAge,
  sessionTimeLimit,
  noParticipation,
}

class ModalityQuality {
  const ModalityQuality(this.modality, this.status, {this.reason, this.value});
  final Modality modality;
  final QualityStatus status;
  final ReasonCode? reason;

  /// The measured quantity behind the decision (e.g. median lighting).
  final double? value;
  bool get usable =>
      status == QualityStatus.valid || status == QualityStatus.limited;

  Map<String, Object?> toJson() => {
        'modality': modality.name,
        'status': status.name,
        'reason': reason?.name,
        'value': value,
      };
  factory ModalityQuality.fromJson(Map<String, dynamic> j) => ModalityQuality(
      Modality.values.byName(j['modality'] as String),
      QualityStatus.values.byName(j['status'] as String),
      reason: j['reason'] == null
          ? null
          : ReasonCode.values.byName(j['reason'] as String),
      value: (j['value'] as num?)?.toDouble());
}

enum Reliability { adequate, limited }

/// A measured quantity extracted from real interaction samples.
class Feature {
  const Feature(this.name, this.value, this.modality,
      {this.unit = '', this.reliability = Reliability.adequate});
  final String name;
  final double value;
  final Modality modality;
  final String unit;
  final Reliability reliability;

  Map<String, Object?> toJson() => {
        'name': name,
        'value': value,
        'modality': modality.name,
        'unit': unit,
        'reliability': reliability.name,
      };
  factory Feature.fromJson(Map<String, dynamic> j) => Feature(
      j['name'] as String,
      (j['value'] as num).toDouble(),
      Modality.values.byName(j['modality'] as String),
      unit: j['unit'] as String? ?? '',
      reliability: Reliability.values.byName(j['reliability'] as String));
}

enum TrialStatus { valid, invalid }

class TrialResult {
  const TrialResult(this.index, this.status,
      {this.reason, this.measures = const {}});
  final int index;
  final TrialStatus status;
  final ReasonCode? reason;

  /// Per-trial measured values (latency, detected action, …). JSON primitives.
  final Map<String, Object?> measures;
  bool get valid => status == TrialStatus.valid;

  Map<String, Object?> toJson() => {
        'index': index,
        'status': status.name,
        'reason': reason?.name,
        'measures': measures,
      };
  factory TrialResult.fromJson(Map<String, dynamic> j) => TrialResult(
      j['index'] as int, TrialStatus.values.byName(j['status'] as String),
      reason: j['reason'] == null
          ? null
          : ReasonCode.values.byName(j['reason'] as String),
      measures: Map<String, Object?>.from(j['measures'] as Map? ?? {}));
}

enum ActivityStatus {
  /// Enough reliable measurement for the activity's construct.
  valid,

  /// The child took part but too little reliable measurement remained.
  insufficient,

  /// No participation detected. Never interpreted as a behaviour.
  nonParticipation,

  /// The caregiver skipped the activity or the session ended first.
  skipped,

  /// Age-gated by the specification (Switch It before 24 months).
  notOffered,
}

/// A behavioural pattern detected by a prototype rule inside one activity.
/// Describes what was observed; it is not a clinical finding.
enum PatternNote {
  storyNonSocialPreference,
  nameNoOrienting,
  lookNoFollow,
  copyNoImitation,
}

class ActivityObservation {
  const ActivityObservation({
    required this.activity,
    required this.status,
    this.features = const [],
    this.quality = const [],
    this.trials = const [],
    this.notes = const [],
    this.reason,
    this.attempt = 1,
    this.durationMs = 0,
  });

  final ActivityId activity;
  final ActivityStatus status;
  final List<Feature> features;
  final List<ModalityQuality> quality;
  final List<TrialResult> trials;
  final List<PatternNote> notes;
  final ReasonCode? reason;
  final int attempt;
  final int durationMs;

  bool get valid => status == ActivityStatus.valid;
  int get validTrials => trials.where((t) => t.valid).length;
  Feature? feature(String name) {
    for (final f in features) {
      if (f.name == name) return f;
    }
    return null;
  }

  ModalityQuality? qualityOf(Modality m) {
    for (final q in quality) {
      if (q.modality == m) return q;
    }
    return null;
  }

  ActivityObservation copyWith({int? attempt, int? durationMs}) =>
      ActivityObservation(
          activity: activity,
          status: status,
          features: features,
          quality: quality,
          trials: trials,
          notes: notes,
          reason: reason,
          attempt: attempt ?? this.attempt,
          durationMs: durationMs ?? this.durationMs);

  factory ActivityObservation.skipped(ActivityId id, ReasonCode reason) =>
      ActivityObservation(
          activity: id,
          status: reason == ReasonCode.notOfferedForAge
              ? ActivityStatus.notOffered
              : ActivityStatus.skipped,
          reason: reason);

  Map<String, Object?> toJson() => {
        'activity': activity.name,
        'status': status.name,
        'features': features.map((f) => f.toJson()).toList(),
        'quality': quality.map((q) => q.toJson()).toList(),
        'trials': trials.map((t) => t.toJson()).toList(),
        'notes': notes.map((n) => n.name).toList(),
        'reason': reason?.name,
        'attempt': attempt,
        'durationMs': durationMs,
      };

  factory ActivityObservation.fromJson(Map<String, dynamic> j) =>
      ActivityObservation(
        activity: ActivityId.values.byName(j['activity'] as String),
        status: ActivityStatus.values.byName(j['status'] as String),
        features: [
          for (final f in j['features'] as List)
            Feature.fromJson(Map<String, dynamic>.from(f as Map))
        ],
        quality: [
          for (final q in j['quality'] as List)
            ModalityQuality.fromJson(Map<String, dynamic>.from(q as Map))
        ],
        trials: [
          for (final t in j['trials'] as List)
            TrialResult.fromJson(Map<String, dynamic>.from(t as Map))
        ],
        notes: [
          for (final n in j['notes'] as List)
            PatternNote.values.byName(n as String)
        ],
        reason: j['reason'] == null
            ? null
            : ReasonCode.values.byName(j['reason'] as String),
        attempt: j['attempt'] as int? ?? 1,
        durationMs: j['durationMs'] as int? ?? 0,
      );
}

// ── Small statistics helpers shared by analyzers ─────────────────────────

double? median(Iterable<num> values) {
  final v = values.map((e) => e.toDouble()).toList()..sort();
  if (v.isEmpty) return null;
  final m = v.length ~/ 2;
  return v.length.isOdd ? v[m] : (v[m - 1] + v[m]) / 2;
}

double? mean(Iterable<num> values) {
  if (values.isEmpty) return null;
  return values.fold<double>(0, (a, b) => a + b) / values.length;
}

double? standardDeviation(Iterable<num> values) {
  if (values.length < 2) return null;
  final m = mean(values)!;
  final sq = values.fold<double>(0, (a, b) => a + (b - m) * (b - m));
  return _sqrt(sq / (values.length - 1));
}

double _sqrt(double x) {
  if (x <= 0) return 0;
  var r = x;
  for (var i = 0; i < 30; i++) {
    r = 0.5 * (r + x / r);
  }
  return r;
}
