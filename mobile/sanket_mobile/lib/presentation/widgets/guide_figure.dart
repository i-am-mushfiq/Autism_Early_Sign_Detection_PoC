import 'dart:math' as math;

import 'package:flutter/material.dart';

enum ArmPose { rest, wave, up, clap, head }

/// "Mitu", Sanket's human guide, drawn so her gaze direction, speech and
/// movements are explicit, controllable stimuli (spec §7: social story,
/// follow-my-look actor, copy-me demonstrations).
class GuideFigure extends StatelessWidget {
  const GuideFigure({
    super.key,
    this.look = 0,
    this.talking = false,
    this.arms = ArmPose.rest,
    this.phase = 0,
    this.size = 180,
  });

  /// −1 = looking fully to the screen's left, 0 = at the child, 1 = right.
  final double look;
  final bool talking;
  final ArmPose arms;

  /// 0–1 animation phase for waving / clapping / talking.
  final double phase;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size * 1.25,
        child: CustomPaint(painter: _GuidePainter(look, talking, arms, phase)),
      );
}

class _GuidePainter extends CustomPainter {
  _GuidePainter(this.look, this.talking, this.arms, this.phase);
  final double look;
  final bool talking;
  final ArmPose arms;
  final double phase;

  static const skin = Color(0xffc98b5e);
  static const skinShade = Color(0xffb27549);
  static const hair = Color(0xff2b1d16);
  static const kameez = Color(0xff2fa37f);
  static const orna = Color(0xfff2b64c);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final headC = Offset(w * .5 + look * w * .09, h * .30 + look.abs() * h * .01);
    final headR = w * .2;
    final shoulderY = h * .56;
    final lShoulder = Offset(w * .3, shoulderY);
    final rShoulder = Offset(w * .7, shoulderY);

    // Body.
    final body = Path()
      ..moveTo(w * .28, shoulderY)
      ..quadraticBezierTo(w * .5, shoulderY - h * .05, w * .72, shoulderY)
      ..lineTo(w * .8, h * .98)
      ..lineTo(w * .2, h * .98)
      ..close();
    canvas.drawPath(body, Paint()..color = kameez);
    canvas.drawPath(
        Path()
          ..moveTo(w * .3, shoulderY + h * .02)
          ..quadraticBezierTo(w * .5, h * .74, w * .7, shoulderY + h * .02),
        Paint()
          ..color = orna
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * .05
          ..strokeCap = StrokeCap.round);

    // Arms.
    final armPaint = Paint()
      ..color = skin
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * .075
      ..strokeCap = StrokeCap.round;
    final wave = math.sin(phase * math.pi * 2);
    Offset lHand, rHand;
    switch (arms) {
      case ArmPose.rest:
        lHand = Offset(w * .22, h * .88);
        rHand = Offset(w * .78, h * .88);
      case ArmPose.wave:
        lHand = Offset(w * .22, h * .88);
        rHand = Offset(w * .9 + wave * w * .05, h * .28);
      case ArmPose.up:
        lHand = Offset(w * .14, h * .06);
        rHand = Offset(w * .86, h * .06);
      case ArmPose.clap:
        final open = (math.sin(phase * math.pi * 4) + 1) / 2;
        lHand = Offset(w * (.46 - open * .16), h * .7);
        rHand = Offset(w * (.54 + open * .16), h * .7);
      case ArmPose.head:
        lHand = Offset(headC.dx - headR * .7, headC.dy - headR * 1.05);
        rHand = Offset(headC.dx + headR * .7, headC.dy - headR * 1.05);
    }
    for (final (s, hand) in [(lShoulder, lHand), (rShoulder, rHand)]) {
      final elbow = Offset((s.dx + hand.dx) / 2 + (hand.dx < w / 2 ? -w * .04 : w * .04),
          (s.dy + hand.dy) / 2 + h * .02);
      canvas.drawPath(
          Path()
            ..moveTo(s.dx, s.dy)
            ..quadraticBezierTo(elbow.dx, elbow.dy, hand.dx, hand.dy),
          armPaint);
      canvas.drawCircle(hand, w * .05, Paint()..color = skin);
    }

    // Neck, hair back, head.
    canvas.drawRect(Rect.fromCenter(center: Offset(headC.dx, headC.dy + headR), width: w * .1, height: headR),
        Paint()..color = skinShade);
    canvas.drawCircle(Offset(headC.dx, headC.dy - headR * .05), headR * 1.08, Paint()..color = hair);
    canvas.drawCircle(Offset(headC.dx + look * headR * .2, headC.dy - headR * 1.05), headR * .38,
        Paint()..color = hair);
    canvas.drawOval(
        Rect.fromCenter(center: headC, width: headR * 1.9 * (1 - look.abs() * .08), height: headR * 2.05),
        Paint()..color = skin);
    // Fringe.
    canvas.drawArc(Rect.fromCenter(center: Offset(headC.dx, headC.dy - headR * .15), width: headR * 2, height: headR * 1.9),
        math.pi * 1.05, math.pi * .9, false,
        Paint()
          ..color = hair
          ..style = PaintingStyle.stroke
          ..strokeWidth = headR * .35);

    // Eyes: shift with the look direction so the cue is unambiguous.
    final eyeY = headC.dy + headR * .05;
    final eyeDx = headR * .42;
    final pupilShift = look * headR * .26;
    for (final side in [-1.0, 1.0]) {
      final c = Offset(headC.dx + side * eyeDx + look * headR * .12, eyeY);
      canvas.drawOval(Rect.fromCenter(center: c, width: headR * .42, height: headR * .34), Paint()..color = Colors.white);
      canvas.drawCircle(Offset(c.dx + pupilShift, c.dy), headR * .12, Paint()..color = const Color(0xff1d1410));
      canvas.drawCircle(Offset(c.dx + pupilShift - headR * .04, c.dy - headR * .04), headR * .035,
          Paint()..color = Colors.white);
    }
    // Brows.
    final brow = Paint()
      ..color = hair
      ..strokeWidth = headR * .07
      ..strokeCap = StrokeCap.round;
    for (final side in [-1.0, 1.0]) {
      final x = headC.dx + side * eyeDx + look * headR * .12;
      canvas.drawLine(Offset(x - headR * .16, eyeY - headR * .3), Offset(x + headR * .16, eyeY - headR * .33), brow);
    }
    // Cheeks & mouth.
    for (final side in [-1.0, 1.0]) {
      canvas.drawCircle(Offset(headC.dx + side * headR * .62 + look * headR * .1, headC.dy + headR * .42), headR * .14,
          Paint()..color = const Color(0x55f07a7a));
    }
    final mouthC = Offset(headC.dx + look * headR * .15, headC.dy + headR * .55);
    final open = talking ? (math.sin(phase * math.pi * 6).abs() * .13 + .05) : .04;
    canvas.drawOval(Rect.fromCenter(center: mouthC, width: headR * .4, height: headR * open * 1.5),
        Paint()..color = const Color(0xffb04a44));
    if (!talking) {
      canvas.drawArc(Rect.fromCenter(center: mouthC.translate(0, -headR * .05), width: headR * .6, height: headR * .35),
          .2, math.pi - .4, false,
          Paint()
            ..color = const Color(0xff8c2f2f)
            ..style = PaintingStyle.stroke
            ..strokeWidth = headR * .07
            ..strokeCap = StrokeCap.round);
    }
    // Hair clip.
    canvas.drawCircle(Offset(headC.dx + headR * .75, headC.dy - headR * .7), headR * .12, Paint()..color = orna);
  }

  @override
  bool shouldRepaint(_GuidePainter old) =>
      old.look != look || old.talking != talking || old.arms != arms || old.phase != phase;
}
