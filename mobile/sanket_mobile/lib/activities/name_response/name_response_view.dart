import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/prototype_parameters.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../presentation/theme.dart';
import '../../presentation/widgets/board.dart';
import '../../presentation/widgets/frame_ticker.dart';
import 'name_response_controller.dart';

class NameResponseBoard extends StatelessWidget {
  const NameResponseBoard(
      {super.key, required this.controller, required this.name});
  final NameResponseController controller;
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return FrameTicker(
      nowMs: () => controller.now,
      builder: (context, now) {
        final c = controller;
        final bob = math.sin(now / 900) * 8;
        final banner = switch (c.namePhase) {
          NamePhase.prompting => BoardBanner(
              text: s(T.nameCallNow, {'name': name}),
              icon: Icons.record_voice_over,
              emphasis: true),
          NamePhase.responseWindow => c.tapFallback
              ? null
              : BoardBanner(text: s(T.nameHeard), icon: Icons.hearing),
          NamePhase.waitingAttention =>
            BoardBanner(text: s(T.nameWaitAttention, {'name': name})),
          NamePhase.between =>
            c.lastCallMissed ? BoardBanner(text: s(T.nameNotHeard)) : null,
        };
        return ActivityBoard(
          colors: const [Color(0xff1f3b5a), Color(0xff2e5d6b)],
          banner: banner,
          child: Stack(children: [
            for (var i = 0; i < 14; i++) _Twinkle(index: i, now: now),
            Center(
                child: Transform.translate(
                    offset: Offset(0, bob + 20),
                    child: const Mascot('happy', height: 150))),
          ]),
        );
      },
    );
  }
}

class _Twinkle extends StatelessWidget {
  const _Twinkle({required this.index, required this.now});
  final int index, now;
  @override
  Widget build(BuildContext context) {
    final r = math.Random(index * 7919);
    final x = r.nextDouble() * 2 - 1, y = r.nextDouble() * 2 - 1;
    final o = (math.sin(now / (600 + index * 90) + index) + 1) / 2;
    return Align(
      alignment: Alignment(x, y),
      child: Opacity(
          opacity: .25 + o * .75,
          child: Text('✦',
              style: TextStyle(
                  fontSize: 14 + r.nextDouble() * 18,
                  color: const Color(0xfffff3b0)))),
    );
  }
}

class NameResponsePanel extends StatelessWidget {
  const NameResponsePanel(
      {super.key, required this.controller, required this.name});
  final NameResponseController controller;
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final c = controller;
        return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              StatusPill(
                  text: s(T.stageTryOf, {
                    'n': c.attempt.clamp(1, P.nameMaxAttempts),
                    'total': P.nameTrials
                  }),
                  background: SanketColors.pale),
              const SizedBox(height: 10),
              if (c.namePhase == NamePhase.prompting && c.tapFallback) ...[
                Text(s(T.nameTapFallback),
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SizedBox(
                  height: 64,
                  child: FilledButton.icon(
                    onPressed: c.caregiverCalled,
                    icon: const Icon(Icons.record_voice_over),
                    label: Text(s(T.nameICalled, {'name': name})),
                  ),
                ),
              ],
            ]);
      },
    );
  }
}
