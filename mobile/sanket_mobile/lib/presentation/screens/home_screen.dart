import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../l10n/locale_scope.dart';
import '../../runtime/session_controller.dart';
import '../theme.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({
    super.key,
    required this.session,
    required this.onStart,
    required this.onStartTour,
    required this.onOpenLatest,
  });

  final SessionController session;
  final VoidCallback onStart;
  final VoidCallback onStartTour;
  final ValueChanged<SessionRecord> onOpenLatest;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final bn = s.isBangla;
    final completed = session.history
        .where((record) => record.status == SessionStatus.completed)
        .toList();
    final transient = session.record?.finished == true ? session.record : null;
    final latest = transient ?? (completed.isEmpty ? null : completed.first);
    final name = session.profile?.nickname.trim();
    final measured =
        latest?.observations.where((item) => item.valid).length ?? 0;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 132),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null || name.isEmpty
                ? (bn ? 'স্বাগতম' : 'Welcome')
                : (bn ? '$name-এর জন্য প্রস্তুত?' : 'Ready for $name?'),
            style: const TextStyle(
              fontSize: 30,
              height: 1.15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bn
                ? 'শান্ত সময় বেছে নিন এবং শিশুর সাথে থাকুন।'
                : 'Choose a calm moment and stay with your child throughout.',
            style: const TextStyle(
              color: SanketColors.muted,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 22),
          _SessionCard(onStart: onStart),
          const SizedBox(height: 12),
          _TourCard(onStartTour: onStartTour),
          const SizedBox(height: 30),
          Text(
            bn ? 'আপনার পর্যবেক্ষণ' : 'Your observations',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (latest == null)
            _EmptyAnalytics(onStart: onStart)
          else ...[
            Row(
              children: [
                Expanded(
                  child: _MetricCard(
                    icon: Icons.task_alt_rounded,
                    value: s.number(completed.length),
                    label: bn ? 'সম্পন্ন সেশন' : 'Completed sessions',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _MetricCard(
                    icon: Icons.visibility_outlined,
                    value: s.number(measured),
                    label: bn ? 'সর্বশেষ পরিমাপ' : 'Latest measured',
                  ),
                ),
              ],
            ),
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => onOpenLatest(latest),
              child: InfoCard(
                color: SanketColors.mint,
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.insights_rounded,
                          color: SanketColors.primary),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            bn ? 'সর্বশেষ সারাংশ' : 'Latest summary',
                            style: const TextStyle(
                              color: SanketColors.muted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            latest.outcome == null
                                ? s.sessionStatus(latest.status)
                                : s.stateTitle(latest.outcome!.state),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            s.dateTime(latest.startedAt),
                            style: const TextStyle(color: SanketColors.muted),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ],
          IconNote(
            icon: Icons.health_and_safety_outlined,
            color: SanketColors.cream,
            text: bn
                ? 'সংকেত বিকাশের কিছু লক্ষণ পর্যবেক্ষণ করে—এটি কোনো রোগ নির্ণয় নয়।'
                : 'Sanket observes selected developmental signals. It does not provide a diagnosis.',
          ),
        ],
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  const _SessionCard({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final bn = context.s.isBangla;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [SanketColors.primaryDeep, SanketColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: const [
          BoxShadow(
              color: Color(0x30238A6B), blurRadius: 22, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: .14),
              borderRadius: BorderRadius.circular(30),
            ),
            child: Text(
              bn
                  ? '৬–৮ মিনিট • ৫–৬টি কার্যক্রম'
                  : '6–8 minutes • 5–6 activities',
              style: const TextStyle(
                  color: Colors.white, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            bn ? 'একটি নির্দেশিত সেশন নিন' : 'Take a guided session',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 27,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            bn
                ? 'সহজ খেলার মাধ্যমে নির্বাচিত বিকাশগত আচরণ পর্যবেক্ষণ করুন।'
                : 'Observe selected developmental behaviours through simple play.',
            style: const TextStyle(
                color: Color(0xffd9f3e9), fontSize: 15, height: 1.45),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: SanketColors.primaryDeep,
              ),
              onPressed: onStart,
              icon: const Icon(Icons.arrow_forward_rounded),
              label: Text(bn ? 'সেশন সম্পর্কে জানুন' : 'View session details'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Entry point for a judge-facing walkthrough: the exact same screens, run
/// on a simulated child so no real camera/microphone or child is needed.
class _TourCard extends StatelessWidget {
  const _TourCard({required this.onStartTour});
  final VoidCallback onStartTour;

  @override
  Widget build(BuildContext context) {
    final bn = context.s.isBangla;
    return InkWell(
      borderRadius: BorderRadius.circular(20),
      onTap: onStartTour,
      child: InfoCard(
        margin: 0,
        color: SanketColors.cream,
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: SanketColors.primary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bn ? 'পূর্ণ ডেমো ট্যুর' : 'Full demo tour',
                    style:
                        const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    bn
                        ? 'একটি সিমুলেটেড শিশু দিয়ে পুরো অ্যাপ দেখুন — সত্যিকারের ক্যামেরা লাগবে না।'
                        : 'Walk the whole app with a simulated child — no real camera needed.',
                    style: const TextStyle(color: SanketColors.muted),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard(
      {required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value, label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: SanketColors.border),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: SanketColors.primary),
            const SizedBox(height: 12),
            Text(value,
                style:
                    const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
            Text(label,
                style:
                    const TextStyle(color: SanketColors.muted, height: 1.25)),
          ],
        ),
      );
}

class _EmptyAnalytics extends StatelessWidget {
  const _EmptyAnalytics({required this.onStart});
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final bn = context.s.isBangla;
    return InfoCard(
      margin: 0,
      child: Column(
        children: [
          const Icon(Icons.auto_graph_rounded,
              size: 48, color: SanketColors.primary),
          const SizedBox(height: 12),
          Text(
            bn
                ? 'প্রথম সেশনের পর এখানে সারাংশ দেখা যাবে'
                : 'Your summaries will appear here after the first session',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onStart,
            child:
                Text(bn ? 'প্রথম সেশন শুরু করুন' : 'Start your first session'),
          ),
        ],
      ),
    );
  }
}
