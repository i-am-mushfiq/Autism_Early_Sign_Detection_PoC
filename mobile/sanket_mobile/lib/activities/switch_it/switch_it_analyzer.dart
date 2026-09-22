import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/measurement.dart';
import '../../core/prototype_parameters.dart';

enum SwitchRule { bird, ball }

/// Switch It — attention shifting (spec §7, 24–36 months, "supportive only").
///
/// The child taps the bird for five trials, then the rule changes to the ball.
/// Item sides are shuffled each trial so the rule is about the object, not the
/// position. Measured from touch: switch cost, perseveration (tapping the old
/// target after the switch), omissions and reaction-time variability.
class SwitchItAnalyzer implements ActivityAnalyzer {
  const SwitchItAnalyzer();

  static const trialStart = 'trial_start'; // {index, rule, targetSide}
  static const response = 'response'; // {index, chosen, rtMs}
  static const omission = 'omission'; // {index}
  static const ruleSwitch = 'rule_switch';
  static const stoppedForOmissions = 'stopped_omissions';

  @override
  ActivityObservation analyze(ActivityCapture c) {
    final trials = <TrialResult>[];
    for (final g in c.trials(trialStart)) {
      final index = g.first.get<int>('index');
      final rule = g.first.get<String>('rule');
      final r = firstOf(g, response);
      if (r == null) {
        trials.add(TrialResult(index, TrialStatus.invalid,
            reason: firstOf(g, omission) != null
                ? ReasonCode.noResponses
                : (c.endedBy ?? ReasonCode.stoppedEarly),
            measures: {'rule': rule}));
        continue;
      }
      trials.add(TrialResult(index, TrialStatus.valid, measures: {
        'rule': rule,
        'chosen': r.get<String>('chosen'),
        'correct': r.get<String>('chosen') == rule,
        'rtMs': r.get<int>('rtMs'),
      }));
    }

    List<TrialResult> responses(SwitchRule rule) => [
          for (final t in trials)
            if (t.valid && t.measures['rule'] == rule.name) t
        ];
    final pre = responses(SwitchRule.bird);
    final post = responses(SwitchRule.ball);
    final allResponses = [...pre, ...post];
    double? accuracy(List<TrialResult> ts) => ts.isEmpty
        ? null
        : ts.where((t) => t.measures['correct'] == true).length / ts.length;
    List<int> correctRts(List<TrialResult> ts) => [
          for (final t in ts)
            if (t.measures['correct'] == true) t.measures['rtMs'] as int
        ];

    final perseverative =
        post.where((t) => t.measures['chosen'] == SwitchRule.bird.name).length;
    final preRt = correctRts(pre), postRt = correctRts(post);
    final allRt = [for (final t in allResponses) t.measures['rtMs'] as int];
    final rtMean = mean(allRt), rtSd = standardDeviation(allRt);
    final omissions =
        trials.where((t) => t.reason == ReasonCode.noResponses).length;

    final enough = pre.length >= P.switchMinResponsesPerRule &&
        post.length >= P.switchMinResponsesPerRule;
    final rel = enough ? Reliability.adequate : Reliability.limited;
    final features = <Feature>[
      Feature('responses', allResponses.length.toDouble(), Modality.touch,
          unit: 'count'),
      Feature('omissions', omissions.toDouble(), Modality.touch, unit: 'count'),
      if (accuracy(pre) != null)
        Feature('accuracy_before_switch', accuracy(pre)!, Modality.touch,
            unit: 'ratio', reliability: rel),
      if (accuracy(post) != null)
        Feature('accuracy_after_switch', accuracy(post)!, Modality.touch,
            unit: 'ratio', reliability: rel),
      if (post.isNotEmpty)
        Feature('perseverative_taps', perseverative.toDouble(), Modality.touch,
            unit: 'count', reliability: rel),
      if (preRt.length >= 2 && postRt.length >= 2)
        Feature(
            'switch_cost_ms', median(postRt)! - median(preRt)!, Modality.touch,
            unit: 'ms', reliability: Reliability.limited),
      if (rtMean != null && rtSd != null && allRt.length >= 3 && rtMean > 0)
        Feature('reaction_time_cv', rtSd / rtMean, Modality.touch,
            unit: 'ratio', reliability: rel),
    ];
    final touch = ModalityQuality(
        Modality.touch,
        allResponses.isEmpty
            ? QualityStatus.excluded
            : enough
                ? QualityStatus.valid
                : QualityStatus.limited,
        reason: allResponses.isEmpty
            ? ReasonCode.noTouches
            : enough
                ? null
                : ReasonCode.tooFewResponses,
        value: allResponses.length.toDouble());

    final status = allResponses.isEmpty
        ? ActivityStatus.nonParticipation
        : enough
            ? ActivityStatus.valid
            : ActivityStatus.insufficient;
    return ActivityObservation(
      activity: ActivityId.switchIt,
      status: status,
      reason: switch (status) {
        ActivityStatus.nonParticipation => ReasonCode.noParticipation,
        ActivityStatus.insufficient => c.endedBy ?? ReasonCode.tooFewResponses,
        _ => null,
      },
      quality: [touch],
      features: features,
      trials: trials,
      attempt: c.attempt,
      durationMs: c.durationMs,
    );
  }
}
