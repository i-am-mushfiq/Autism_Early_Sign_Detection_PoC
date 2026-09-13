import 'package:flutter/material.dart';

import '../../core/activity_catalog.dart';
import '../../core/measurement.dart';
import '../../core/session.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../runtime/session_controller.dart';
import '../theme.dart';

/// Offered activities in a record (excludes age-gated ones).
int offeredActivities(SessionRecord r) =>
    r.observations.where((o) => o.status != ActivityStatus.notOffered).length;

int measuredActivities(SessionRecord r) => r.observations.where((o) => o.valid).length;

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key, required this.session, required this.onNewSession, required this.onOpen});
  final SessionController session;
  final VoidCallback onNewSession;
  final ValueChanged<SessionRecord> onOpen;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final records = session.history.where((r) => r.finished && r.outcome != null).toList();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(overline: s(T.historyOverline), title: s(T.historyTitle), lead: s(T.historyLead)),
        InfoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(s(T.historyTrendTitle), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 12),
            if (records.length < 2)
              Row(children: [
                const Icon(Icons.insights_outlined, color: SanketColors.faint),
                const SizedBox(width: 10),
                Expanded(child: Text(s(T.historyTrendEmpty), style: const TextStyle(color: SanketColors.muted))),
              ])
            else ...[
              _TrendChart(records: records.take(8).toList().reversed.toList()),
              const SizedBox(height: 8),
              Text(s(T.historyTrendCaption), style: const TextStyle(fontSize: 12, color: SanketColors.muted)),
            ],
          ]),
        ),
        if (records.isEmpty)
          IconNote(icon: Icons.inbox_outlined, iconColor: SanketColors.faint, text: s(T.historyEmpty))
        else
          for (final r in records)
            InfoCard(
              margin: 10,
              padding: 0,
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                onTap: () => onOpen(r),
                title: Text(s.stateTitle(r.outcome!.state), style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const SizedBox(height: 2),
                  Text('${s.dateTime(r.startedAt)} · ${s.sessionStatus(r.status)}'),
                  Text(s(T.historyChild, {'name': r.profile.nickname, 'age': r.profile.ageMonths})),
                  Text(s(T.historyMeasured, {'n': measuredActivities(r), 'total': offeredActivities(r)}),
                      style: const TextStyle(color: SanketColors.muted)),
                ]),
                trailing: const Icon(Icons.chevron_right),
              ),
            ),
        IconNote(icon: Icons.shield_outlined, color: SanketColors.cream, text: s(T.historyPrivacy)),
        PrimaryButton(label: s(T.historyNewSession), onPressed: onNewSession),
        if (records.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: SanketColors.warn, minimumSize: const Size(48, 48)),
                onPressed: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text(s(T.historyDeleteTitle)),
                      content: Text(s(T.historyDeleteBody)),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s(T.cancel))),
                        FilledButton(
                            style: FilledButton.styleFrom(backgroundColor: SanketColors.warn),
                            onPressed: () => Navigator.pop(context, true),
                            child: Text(s(T.historyDelete))),
                      ],
                    ),
                  );
                  if (ok == true) await session.deleteAllHistory();
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(s(T.historyDeleteAll)),
              ),
            ),
          ),
      ]),
    );
  }
}

/// Bars of measured activities per real saved session (oldest → newest).
class _TrendChart extends StatelessWidget {
  const _TrendChart({required this.records});
  final List<SessionRecord> records;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final maxTotal = activityCatalog.length;
    return SizedBox(
      height: 150,
      child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
        for (final r in records)
          Expanded(
            child: Semantics(
              label: s(T.historyMeasured, {'n': measuredActivities(r), 'total': offeredActivities(r)}),
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5),
                child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                  Text(s.number(measuredActivities(r)), style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  Container(
                    height: 8 + 100 * measuredActivities(r) / maxTotal,
                    decoration: BoxDecoration(
                        color: const Color(0xff43a96c), borderRadius: BorderRadius.circular(8)),
                  ),
                  const SizedBox(height: 6),
                  Text('${s.number(r.startedAt.toLocal().day)}/${s.number(r.startedAt.toLocal().month)}',
                      style: const TextStyle(fontSize: 11)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}
