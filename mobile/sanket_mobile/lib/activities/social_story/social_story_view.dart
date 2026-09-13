import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/calibration.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../presentation/theme.dart';
import '../../presentation/widgets/board.dart';
import '../../presentation/widgets/frame_ticker.dart';
import '../../presentation/widgets/guide_figure.dart';
import 'social_story_controller.dart';

class SocialStoryBoard extends StatelessWidget {
  const SocialStoryBoard({super.key, required this.controller});
  final SocialStoryController controller;

  static const _lines = [T.storyLine1, T.storyLine2, T.storyLine3, T.storyLine4];

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return FrameTicker(
      nowMs: () => controller.now,
      builder: (context, now) {
        final c = controller;
        final running = c.segment >= 0 && !c.inGap;
        final phase = (now % 2000) / 2000;
        final socialLeft = c.segment < 0 || c.socialSide == GazeRegion.left;
        final social = Column(mainAxisSize: MainAxisSize.min, children: [
          _SpeechBubble(text: s(_lines[c.line])),
          const SizedBox(height: 6),
          Flexible(
            child: FittedBox(
              child: GuideFigure(
                  talking: running, arms: c.line.isOdd ? ArmPose.wave : ArmPose.rest, phase: phase, size: 150),
            ),
          ),
        ]);
        final toy = Center(child: _Pinwheel(angle: now / 1000 * math.pi * .9, size: 150));
        return ActivityBoard(
          colors: const [Color(0xffbfe8f7), Color(0xfff1f3c2)],
          child: AnimatedOpacity(
            opacity: running ? 1 : 0.15,
            duration: const Duration(milliseconds: 400),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 18, 12, 12),
              child: Row(children: [
                Expanded(child: Center(child: socialLeft ? social : toy)),
                const SizedBox(width: 40),
                Expanded(child: Center(child: socialLeft ? toy : social)),
              ]),
            ),
          ),
        );
      },
    );
  }
}

class SocialStoryPanel extends StatelessWidget {
  const SocialStoryPanel({super.key, required this.controller, required this.name});
  final SocialStoryController controller;
  final String name;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: controller,
        builder: (context, _) => controller.lookingAway
            ? IconNote(
                icon: Icons.visibility_off_outlined,
                iconColor: SanketColors.warn,
                color: SanketColors.warnSoft,
                text: context.s(T.storyLookAway, {'name': name}))
            : const SizedBox.shrink(),
      );
}

class _SpeechBubble extends StatelessWidget {
  const _SpeechBubble({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w800, color: SanketColors.ink, fontSize: 15)),
      );
}

/// Non-social stimulus: a slowly turning pinwheel.
class _Pinwheel extends StatelessWidget {
  const _Pinwheel({required this.angle, required this.size});
  final double angle, size;
  @override
  Widget build(BuildContext context) =>
      SizedBox(width: size, height: size, child: CustomPaint(painter: _PinwheelPainter(angle)));
}

class _PinwheelPainter extends CustomPainter {
  _PinwheelPainter(this.angle);
  final double angle;
  static const colors = [Color(0xfff4a5c6), Color(0xff79c7f2), Color(0xffa4d657), Color(0xfff5c745)];

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    for (var i = 0; i < 4; i++) {
      canvas.save();
      canvas.rotate(i * math.pi / 2);
      final path = Path()
        ..moveTo(0, 0)
        ..lineTo(r * .95, -r * .1)
        ..quadraticBezierTo(r * .9, -r * .75, 0, -r * .95)
        ..close();
      canvas.drawPath(path, Paint()..color = colors[i]);
      canvas.restore();
    }
    canvas.restore();
    canvas.drawCircle(c, r * .12, Paint()..color = Colors.white);
    canvas.drawRect(Rect.fromLTWH(c.dx - 3, c.dy + r * .1, 6, r * .9), Paint()..color = const Color(0xff9a7b5b));
  }

  @override
  bool shouldRepaint(_PinwheelPainter old) => old.angle != angle;
}
