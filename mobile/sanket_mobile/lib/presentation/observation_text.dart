import '../core/activity_catalog.dart';
import '../core/interpretation.dart';
import '../core/measurement.dart';
import '../core/session.dart';
import '../l10n/locale_scope.dart';
import '../l10n/strings.dart';

/// Plain-language descriptions of stored measurements. Used by the result
/// screen and the copyable summary so both always say the same thing.
class ObservationText {
  const ObservationText(this.s, this.name);
  final Strings s;
  final String name;

  String? summary(ActivityObservation o) {
    if (!o.valid) return null;
    int count(bool Function(TrialResult t) test) =>
        o.trials.where((t) => t.valid && test(t)).length;
    switch (o.activity) {
      case ActivityId.socialStory:
        final share = o.feature('social_share')?.value;
        return share == null
            ? null
            : s(T.sumStory, {'pct': (share * 100).round()});
      case ActivityId.nameResponse:
        final base = s(T.sumName, {
          'n': count((t) => t.measures['responded'] == true),
          'total': o.validTrials
        });
        final latency = o.feature('median_latency_ms');
        return latency == null
            ? base
            : '$base ${s(T.sumLatency, {'sec': s.seconds(latency.value)})}';
      case ActivityId.followMyLook:
        return s(T.sumLook, {
          'n': count((t) => t.measures['followed'] == true),
          'total': o.validTrials
        });
      case ActivityId.bubbleTrail:
        final base = s(T.sumBubble, {
          'n': (o.feature('bubbles_popped')?.value ?? 0).round(),
          'taps': (o.feature('touches')?.value ?? 0).round(),
        });
        final rt = o.feature('median_reaction_ms');
        return rt == null
            ? base
            : '$base ${s(T.sumLatency, {'sec': s.seconds(rt.value)})}';
      case ActivityId.copyMe:
        return s(T.sumCopy, {
          'n': count((t) => t.measures['matched'] == true),
          'total': o.validTrials
        });
      case ActivityId.switchIt:
        List<TrialResult> rule(String r) => [
              for (final t in o.trials)
                if (t.valid && t.measures['rule'] == r) t
            ];
        final pre = rule('bird'), post = rule('ball');
        return s(T.sumSwitch, {
          'a': pre.where((t) => t.measures['correct'] == true).length,
          'b': pre.length,
          'c': post.where((t) => t.measures['correct'] == true).length,
          'd': post.length,
        });
    }
  }

  String pattern(InterpretedPattern p, ActivityObservation o) {
    final n = o.validTrials;
    return switch (p.note) {
      PatternNote.storyNonSocialPreference => s(T.noteStory, {'name': name}),
      PatternNote.nameNoOrienting => s(T.noteName, {'n': n}),
      PatternNote.lookNoFollow => s(T.noteLook, {'name': name, 'n': n}),
      PatternNote.copyNoImitation => s(T.noteCopy, {'n': n}),
    };
  }

  String? inconclusiveDetail(SessionOutcome outcome) =>
      switch (outcome.inconclusiveReason) {
        InconclusiveReason.tooFewValidActivities =>
          s(T.inconclusiveTooFew, {'n': outcome.validActivities}),
        InconclusiveReason.tooFewEvidenceBackedActivities =>
          s(T.inconclusiveEvidence),
        null => null,
      };

  /// Text for the clipboard. Contains no raw data and states the boundary.
  String clipboard(SessionRecord r) {
    final outcome = r.outcome!;
    final lines = <String>[
      s(T.copyHeader),
      '${s.dateTime(r.startedAt)} · ${s(T.historyChild, {
            'name': name,
            'age': r.profile.ageMonths
          })}',
      '${s(T.resultOverline)}: ${s.stateTitle(outcome.state)}',
      s.stateBody(outcome.state, name),
      '',
    ];
    for (final o in r.observations) {
      final detail =
          summary(o) ?? (o.reason == null ? '' : s.reason(o.reason!, name));
      lines.add(
          '• ${s.activityName(o.activity)} — ${s.activityStatus(o.status)}${detail.isEmpty ? '' : ': $detail'}');
    }
    lines
      ..add('')
      ..add('${s(T.resultNextStep)}: ${s.nextStep(outcome.state, name)}')
      ..add(s(T.resultBoundary))
      ..add(s(T.copyNotDiagnosis));
    return lines.join('\n');
  }
}
