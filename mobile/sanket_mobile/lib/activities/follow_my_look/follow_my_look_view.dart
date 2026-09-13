import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/calibration.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../presentation/theme.dart';
import '../../presentation/widgets/board.dart';
import '../../presentation/widgets/frame_ticker.dart';
import '../../presentation/widgets/guide_figure.dart';
import 'follow_my_look_controller.dart';

class FollowMyLookBoard extends StatelessWidget {
  const FollowMyLookBoard({super.key, required this.controller});
  final FollowMyLookController controller;

  @override
  Widget build(BuildContext context) {
    return FrameTicker(
      nowMs: () => controller.now,
      builder: (context, now) {
        final c = controller;
        final look = switch (c.guideLook) {
          GazeRegion.left => -1.0,
          GazeRegion.right => 1.0,
          _ => 0.0,
        };
        final reward = c.lookPhase == LookPhase.reward;
        Widget toy(GazeRegion side) {
          final isTarget = c.target == side;
          final jiggle = reward && isTarget ? math.sin(now / 70) * .12 : 0.0;
          final tapped = c.tapped == side;
          return Semantics(
            button: true,
            label: context.s(side == GazeRegion.left ? T.lookToyCar : T.lookToyBunny),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => c.tapToy(side),
              child: Transform.rotate(
                angle: jiggle,
                child: AnimatedScale(
                  scale: tapped ? 1.12 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    width: 132,
                    height: 132,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(.85),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 4),
                    ),
                    child: Icon(side == GazeRegion.left ? Icons.directions_car_filled_rounded : Icons.cruelty_free,
                        size: 78, color: side == GazeRegion.left ? const Color(0xffe3534b) : const Color(0xff8a6bd1)),
                  ),
                ),
              ),
            ),
          );
        }

        return ActivityBoard(
          colors: const [Color(0xffc9ecd8), Color(0xfff6efc7)],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              toy(GazeRegion.left),
              Expanded(
                child: Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: look),
                    duration: const Duration(milliseconds: 650),
                    curve: Curves.easeInOut,
                    builder: (context, value, _) => FittedBox(child: GuideFigure(look: value, size: 170)),
                  ),
                ),
              ),
              toy(GazeRegion.right),
            ]),
          ),
        );
      },
    );
  }
}

class FollowMyLookPanel extends StatelessWidget {
  const FollowMyLookPanel({super.key, required this.controller, required this.name});
  final FollowMyLookController controller;
  final String name;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final c = controller;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          StatusPill(text: s(T.stageTryOf, {'n': c.trial.clamp(1, 4), 'total': 4}), background: SanketColors.pale),
          if (c.lookPhase == LookPhase.waitingCenter && c.gazeAvailable) ...[
            const SizedBox(height: 10),
            Text(s(T.lookWaitCenter, {'name': name}), style: const TextStyle(color: SanketColors.muted)),
          ],
          if (!c.gazeAvailable)
            IconNote(
                icon: Icons.info_outline,
                iconColor: SanketColors.warn,
                color: SanketColors.warnSoft,
                text: s(T.lookGazeUnavailable, {'name': name})),
        ]);
      },
    );
  }
}
