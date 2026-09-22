import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/activity_catalog.dart';
import '../../core/interpretation.dart';
import '../../core/measurement.dart';
import '../../core/session.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../observation_text.dart';
import '../theme.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.record,
    required this.saving,
    required this.saved,
    required this.onHistory,
    required this.onHome,
  });
  final SessionRecord record;
  final bool saving, saved;
  final VoidCallback onHistory, onHome;

  static IconData stateIcon(ObservationState s) => switch (s) {
        ObservationState.noStrongSignal => Icons.check_circle_outline,
        ObservationState.monitor => Icons.visibility_outlined,
        ObservationState.discussProfessional => Icons.forum_outlined,
        ObservationState.inconclusive => Icons.help_outline,
      };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final name = record.profile.nickname;
    final outcome = record.outcome!;
    final text = ObservationText(s, name);
    final byActivity = {for (final o in record.observations) o.activity: o};

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(
            overline: s(T.resultOverline), title: s.stateTitle(outcome.state)),
        InfoCard(
          color: outcome.state == ObservationState.inconclusive
              ? const Color(0xfff0f0ec)
              : SanketColors.mint,
          child: Column(children: [
            Icon(stateIcon(outcome.state),
                size: 46, color: SanketColors.primary),
            const SizedBox(height: 10),
            Text(s.stateBody(outcome.state, name),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16, height: 1.5)),
            if (text.inconclusiveDetail(outcome) != null) ...[
              const SizedBox(height: 8),
              Text(text.inconclusiveDetail(outcome)!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SanketColors.muted)),
            ],
          ]),
        ),
        const SizedBox(height: 22),
        Text(s(T.resultWhatObserved),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        for (final def in activityCatalog)
          if (byActivity[def.id] != null)
            _ActivityRow(
                observation: byActivity[def.id]!, outcome: outcome, text: text),
        const SizedBox(height: 22),
        Text(s(T.resultNextStep),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        IconNote(
            icon: Icons.near_me_outlined,
            color: SanketColors.cream,
            text: s.nextStep(outcome.state, name)),
        Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Text(s(T.resultBoundary),
              style: const TextStyle(fontSize: 13, color: SanketColors.faint)),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Row(children: [
            Icon(
                saved
                    ? Icons.phone_android
                    : saving
                        ? Icons.sync
                        : Icons.cloud_off_outlined,
                size: 18,
                color: SanketColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                  s(saved
                      ? T.resultSaved
                      : saving
                          ? T.resultSaving
                          : T.resultNotSaved),
                  style: const TextStyle(color: SanketColors.muted)),
            ),
          ]),
        ),
        PrimaryButton(
          label: s(T.resultCopy),
          icon: Icons.copy_rounded,
          pale: true,
          onPressed: () async {
            await Clipboard.setData(
                ClipboardData(text: text.clipboard(record)));
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(s(T.resultCopied))));
            }
          },
        ),
        if (record.consents.storeOnDevice)
          PrimaryButton(
              label: s(T.resultHistory), pale: true, onPressed: onHistory),
        PrimaryButton(label: s(T.resultHome), onPressed: onHome),
      ]),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(
      {required this.observation, required this.outcome, required this.text});
  final ActivityObservation observation;
  final SessionOutcome outcome;
  final ObservationText text;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final o = observation;
    final patterns = outcome.patterns.where((p) => p.activity == o.activity);
    final summary = text.summary(o);
    final (icon, color) = switch (o.status) {
      ActivityStatus.valid => (Icons.check_circle, SanketColors.leaf),
      ActivityStatus.notOffered => (
          Icons.remove_circle_outline,
          SanketColors.faint
        ),
      ActivityStatus.skipped => (Icons.skip_next_rounded, SanketColors.faint),
      _ => (Icons.help_outline, SanketColors.warn),
    };
    return InfoCard(
      margin: 10,
      padding: 14,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s.activityName(o.activity),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            Text(s.activityStatus(o.status),
                style: TextStyle(color: color, fontWeight: FontWeight.w600)),
            if (summary != null)
              Padding(
                  padding: const EdgeInsets.only(top: 4), child: Text(summary)),
            if (!o.valid &&
                o.reason != null &&
                o.status != ActivityStatus.notOffered &&
                o.status != ActivityStatus.nonParticipation)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(s.reason(o.reason!, text.name),
                      style: const TextStyle(color: SanketColors.muted))),
            if (o.status == ActivityStatus.notOffered)
              Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(s.reason(ReasonCode.notOfferedForAge, text.name),
                      style: const TextStyle(color: SanketColors.muted))),
            for (final p in patterns) ...[
              const SizedBox(height: 6),
              Text(text.pattern(p, o),
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (p.suppressedBy != null)
                Text(
                    s(T.resultPatternSuppressed,
                        {'factor': s.factor(p.suppressedBy!)}),
                    style: const TextStyle(color: SanketColors.muted)),
            ],
            if (o.valid &&
                o.activity.definition.role == InterpretationRole.descriptive)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(s(T.resultDescriptiveOnly),
                    style: const TextStyle(
                        fontSize: 12, color: SanketColors.faint)),
              ),
          ]),
        ),
      ]),
    );
  }
}
