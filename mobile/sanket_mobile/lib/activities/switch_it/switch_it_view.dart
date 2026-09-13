import 'package:flutter/material.dart';

import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../presentation/widgets/board.dart';
import 'switch_it_analyzer.dart';
import 'switch_it_controller.dart';

class SwitchItBoard extends StatelessWidget {
  const SwitchItBoard({super.key, required this.controller});
  final SwitchItController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final c = controller;
        final ballRule = c.displayedRule == SwitchRule.ball;
        final colors = ballRule
            ? const [Color(0xffffd7c2), Color(0xfffff1d6)]
            : const [Color(0xffc8f0d8), Color(0xffe9f7cf)];
        if (c.switchPhase == SwitchPhase.switching) {
          return ActivityBoard(
            colors: colors,
            banner: BoardBanner(text: s(T.switchNow), emphasis: true),
            child: const Center(child: _Item(item: SwitchRule.ball, size: 170)),
          );
        }
        final prompt = s(c.rule == SwitchRule.bird ? T.switchTapBird : T.switchTapBall);
        Widget card(SwitchRule item) => Expanded(
              child: Semantics(
                button: true,
                label: s(item == SwitchRule.bird ? T.switchTapBird : T.switchTapBall),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => c.tap(item),
                  child: Center(
                    child: AnimatedScale(
                      scale: c.chosen == item ? 1.15 : (c.chosen != null ? .9 : 1),
                      duration: const Duration(milliseconds: 180),
                      child: _Item(item: item, size: 150),
                    ),
                  ),
                ),
              ),
            );
        final left = c.birdOnLeft ? SwitchRule.bird : SwitchRule.ball;
        final right = c.birdOnLeft ? SwitchRule.ball : SwitchRule.bird;
        return ActivityBoard(
          colors: colors,
          banner: BoardBanner(text: prompt, emphasis: true),
          child: Padding(
            padding: const EdgeInsets.only(top: 56),
            child: Row(children: [card(left), card(right)]),
          ),
        );
      },
    );
  }
}

class _Item extends StatelessWidget {
  const _Item({required this.item, required this.size});
  final SwitchRule item;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        padding: EdgeInsets.all(size * .1),
        decoration: const BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: Color(0x22000000), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: item == SwitchRule.bird
            ? const FittedBox(child: Mascot('happy', height: 200))
            : CustomPaint(painter: _BallPainter()),
      );
}

class _BallPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.drawCircle(c, r, Paint()..color = const Color(0xffef5a4f));
    final band = Paint()
      ..color = const Color(0xfff7c948)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * .28;
    canvas.drawArc(Rect.fromCircle(center: c, radius: r * .62), -.6, 2.4, false, band);
    canvas.drawCircle(c.translate(-r * .35, -r * .4), r * .16, Paint()..color = Colors.white.withOpacity(.7));
  }

  @override
  bool shouldRepaint(_BallPainter oldDelegate) => false;
}
