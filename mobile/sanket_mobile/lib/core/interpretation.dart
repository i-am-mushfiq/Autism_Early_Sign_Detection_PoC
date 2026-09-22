/// Deterministic, traceable next-step interpretation.
///
/// Spec §5/§10: four next-step states — no strong follow-up signal observed,
/// monitor, discuss with a professional, inconclusive. Spec §8: too little
/// valid data → inconclusive. Spec §17: never a diagnosis or probability.
///
/// Prototype rules ([PrototypeParameters.rulesVersion]):
///  1. Only activities with status `valid` count. If fewer than
///     [P.minValidActivities] are valid, or fewer than
///     [P.minValidEvidenceBackedActivities] evidence-backed ones → Inconclusive.
///  2. Patterns (see [PatternNote]) come only from valid activities.
///  3. A pattern is not interpreted when a reported baseline concern could
///     explain it (spec §5 baseline context): hearing → Name Response;
///     vision → Social Story and Follow My Look; motor → Copy Me.
///  4. Evidence-backed activities' patterns can escalate; emerging ones can
///     raise the state to Monitor at most; promising / supportive-only
///     activities are descriptive (spec §7 evidence column).
///  5. "Several observations" (≥ 2 escalating patterns) → Discuss with a
///     professional; "one or more observations" → Monitor; none → No strong
///     follow-up signal observed.
library;

import 'activity_catalog.dart';
import 'measurement.dart';
import 'prototype_parameters.dart';

enum ObservationState {
  noStrongSignal,
  monitor,
  discussProfessional,
  inconclusive
}

enum ContextFactor { hearingConcern, visionConcern, motorDifficulty }

enum InconclusiveReason {
  tooFewValidActivities,
  tooFewEvidenceBackedActivities
}

class ChildContext {
  const ChildContext({
    required this.ageMonths,
    this.hearingConcern = false,
    this.visionConcern = false,
    this.motorDifficulty = false,
  });
  final int ageMonths;
  final bool hearingConcern, visionConcern, motorDifficulty;
}

class InterpretedPattern {
  const InterpretedPattern(this.activity, this.note, {this.suppressedBy});
  final ActivityId activity;
  final PatternNote note;
  final ContextFactor? suppressedBy;

  Map<String, Object?> toJson() => {
        'activity': activity.name,
        'note': note.name,
        'suppressedBy': suppressedBy?.name,
      };
  factory InterpretedPattern.fromJson(Map<String, dynamic> j) =>
      InterpretedPattern(ActivityId.values.byName(j['activity'] as String),
          PatternNote.values.byName(j['note'] as String),
          suppressedBy: j['suppressedBy'] == null
              ? null
              : ContextFactor.values.byName(j['suppressedBy'] as String));
}

class SessionOutcome {
  const SessionOutcome({
    required this.state,
    required this.validActivities,
    required this.validEvidenceBacked,
    required this.patterns,
    this.inconclusiveReason,
    this.rulesVersion = PrototypeParameters.rulesVersion,
  });

  final ObservationState state;
  final int validActivities, validEvidenceBacked;

  /// All patterns from valid activities, including suppressed ones.
  final List<InterpretedPattern> patterns;
  final InconclusiveReason? inconclusiveReason;
  final String rulesVersion;

  Iterable<InterpretedPattern> get counted =>
      patterns.where((p) => p.suppressedBy == null);

  Map<String, Object?> toJson() => {
        'state': state.name,
        'validActivities': validActivities,
        'validEvidenceBacked': validEvidenceBacked,
        'patterns': patterns.map((p) => p.toJson()).toList(),
        'inconclusiveReason': inconclusiveReason?.name,
        'rulesVersion': rulesVersion,
      };

  factory SessionOutcome.fromJson(Map<String, dynamic> j) => SessionOutcome(
        state: ObservationState.values.byName(j['state'] as String),
        validActivities: j['validActivities'] as int,
        validEvidenceBacked: j['validEvidenceBacked'] as int,
        patterns: [
          for (final p in j['patterns'] as List)
            InterpretedPattern.fromJson(Map<String, dynamic>.from(p as Map))
        ],
        inconclusiveReason: j['inconclusiveReason'] == null
            ? null
            : InconclusiveReason.values
                .byName(j['inconclusiveReason'] as String),
        rulesVersion: j['rulesVersion'] as String,
      );
}

class SessionInterpreter {
  const SessionInterpreter();

  SessionOutcome interpret(
      List<ActivityObservation> observations, ChildContext context) {
    final valid = observations.where((o) => o.valid).toList();
    final evidenceValid = valid
        .where(
            (o) => o.activity.definition.role == InterpretationRole.escalating)
        .length;

    final patterns = [
      for (final o in valid)
        for (final n in o.notes)
          InterpretedPattern(o.activity, n,
              suppressedBy: _suppression(o.activity, context))
    ];

    InconclusiveReason? inconclusive;
    if (valid.length < P.minValidActivities) {
      inconclusive = InconclusiveReason.tooFewValidActivities;
    } else if (evidenceValid < P.minValidEvidenceBackedActivities) {
      inconclusive = InconclusiveReason.tooFewEvidenceBackedActivities;
    }
    if (inconclusive != null) {
      return SessionOutcome(
          state: ObservationState.inconclusive,
          validActivities: valid.length,
          validEvidenceBacked: evidenceValid,
          patterns: patterns,
          inconclusiveReason: inconclusive);
    }

    final counted = patterns.where((p) => p.suppressedBy == null);
    final escalating = counted
        .where(
            (p) => p.activity.definition.role == InterpretationRole.escalating)
        .length;
    final monitorOnly = counted
        .where(
            (p) => p.activity.definition.role == InterpretationRole.monitorOnly)
        .length;

    final state = escalating >= 2
        ? ObservationState.discussProfessional
        : escalating == 1 || monitorOnly >= 1
            ? ObservationState.monitor
            : ObservationState.noStrongSignal;
    return SessionOutcome(
        state: state,
        validActivities: valid.length,
        validEvidenceBacked: evidenceValid,
        patterns: patterns);
  }

  ContextFactor? _suppression(ActivityId activity, ChildContext c) =>
      switch (activity) {
        ActivityId.nameResponse when c.hearingConcern =>
          ContextFactor.hearingConcern,
        ActivityId.socialStory ||
        ActivityId.followMyLook when c.visionConcern =>
          ContextFactor.visionConcern,
        ActivityId.copyMe when c.motorDifficulty =>
          ContextFactor.motorDifficulty,
        _ => null,
      };
}
