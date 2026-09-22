import 'package:flutter/material.dart';

import '../theme.dart';

/// The Sanket leaf mark, drawn in code so it stays crisp at every size.
class SanketLogo extends StatelessWidget {
  const SanketLogo({super.key, this.size = 64, this.showWordmark = false});

  final double size;
  final bool showWordmark;

  @override
  Widget build(BuildContext context) {
    final mark = Semantics(
      label: 'Sanket',
      image: true,
      child: CustomPaint(size: Size.square(size), painter: _LogoPainter()),
    );
    if (!showWordmark) return mark;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        SizedBox(height: size * .12),
        Text(
          'Sanket',
          style: TextStyle(
            color: SanketColors.primaryDeep,
            fontSize: size * .6,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = SanketColors.leaf
      ..style = PaintingStyle.fill;
    final stroke = Paint()
      ..color = SanketColors.primaryDeep
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * .075;

    Path leaf(double cx, double cy, double rotation) {
      final path = Path()
        ..moveTo(0, -size.height * .3)
        ..cubicTo(
          size.width * .24,
          -size.height * .18,
          size.width * .24,
          size.height * .12,
          0,
          size.height * .3,
        )
        ..cubicTo(
          -size.width * .24,
          size.height * .12,
          -size.width * .24,
          -size.height * .18,
          0,
          -size.height * .3,
        )
        ..close();
      final matrix = Matrix4.identity()
        ..translateByDouble(cx, cy, 0, 1)
        ..rotateZ(rotation);
      return path.transform(matrix.storage);
    }

    canvas.drawPath(leaf(size.width * .5, size.height * .31, 0), paint);
    canvas.drawPath(
      leaf(size.width * .35, size.height * .58, -.78),
      paint,
    );
    canvas.drawPath(
      leaf(size.width * .65, size.height * .58, .78),
      paint,
    );
    final stem = Path()
      ..moveTo(size.width * .5, size.height * .38)
      ..lineTo(size.width * .5, size.height * .82)
      ..moveTo(size.width * .5, size.height * .66)
      ..lineTo(size.width * .3, size.height * .48)
      ..moveTo(size.width * .5, size.height * .66)
      ..lineTo(size.width * .7, size.height * .48);
    canvas.drawPath(stem, stroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
