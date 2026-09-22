import 'package:flutter/material.dart';

import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../presentation/theme.dart';
import '../../presentation/widgets/board.dart';
import '../../presentation/widgets/frame_ticker.dart';
import 'bubble_trail_controller.dart';

class BubbleTrailBoard extends StatefulWidget {
  const BubbleTrailBoard(
      {super.key, required this.controller, required this.name});
  final BubbleTrailController controller;
  final String name;

  @override
  State<BubbleTrailBoard> createState() => _BubbleTrailBoardState();
}

class _BubbleTrailBoardState extends State<BubbleTrailBoard> {
  final _pointers = <int>{};

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = widget.controller;
    return LayoutBuilder(builder: (context, constraints) {
      c.board = constraints.biggest;
      return Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          _pointers.add(e.pointer);
          c.touch(e.localPosition, _pointers.length);
        },
        onPointerUp: (e) => _pointers.remove(e.pointer),
        onPointerCancel: (e) => _pointers.remove(e.pointer),
        child: FrameTicker(
          nowMs: () => c.now,
          builder: (context, now) => ActivityBoard(
            colors: const [Color(0xffa7e1fa), Color(0xffe5efab)],
            banner: c.showHint
                ? BoardBanner(
                    text: s(T.bubbleInactive, {'name': widget.name}),
                    icon: Icons.touch_app)
                : null,
            child: Stack(children: [
              Positioned.fill(
                  child: CustomPaint(painter: _BubblePainter(c, now))),
              Positioned(
                right: 14,
                bottom: 14,
                child:
                    StatusPill(text: s(T.bubblePopped, {'n': c.poppedCount})),
              ),
            ]),
          ),
        ),
      );
    });
  }
}

class _BubblePainter extends CustomPainter {
  _BubblePainter(this.c, this.now);
  final BubbleTrailController c;
  final int now;

  @override
  void paint(Canvas canvas, Size size) {
    for (final b in c.alive) {
      final center = b.centerAt(now, size);
      final r = b.radius(size);
      canvas.drawCircle(
          center, r, Paint()..color = Color(b.color).withOpacity(.82));
      canvas.drawCircle(
          center,
          r,
          Paint()
            ..color = Colors.white
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3);
      canvas.drawCircle(center.translate(-r * .35, -r * .35), r * .18,
          Paint()..color = Colors.white.withOpacity(.8));
    }
    for (final p in c.popped) {
      final t = ((now - p.atMs) / 450).clamp(0.0, 1.0);
      final paint = Paint()
        ..color = Color(p.color).withOpacity(1 - t)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      canvas.drawCircle(p.center, p.radius * (1 + t * .8), paint);
    }
  }

  @override
  bool shouldRepaint(_BubblePainter old) => true;
}
