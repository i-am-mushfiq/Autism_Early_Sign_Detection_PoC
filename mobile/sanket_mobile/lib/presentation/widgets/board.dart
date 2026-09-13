import 'package:flutter/material.dart';

import '../theme.dart';

/// The child-facing play area shared by all activities.
class ActivityBoard extends StatelessWidget {
  const ActivityBoard({super.key, required this.child, this.colors, this.banner});
  final Widget child;
  final List<Color>? colors;

  /// Short caregiver-facing banner shown across the top (e.g. "Now call …").
  final Widget? banner;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: colors ?? const [Color(0xffa7e1fa), Color(0xffe5efab)],
            ),
          ),
          child: Stack(fit: StackFit.expand, children: [
            child,
            if (banner != null) Positioned(top: 12, left: 12, right: 12, child: Center(child: banner)),
          ]),
        ),
      );
}

class BoardBanner extends StatelessWidget {
  const BoardBanner({super.key, required this.text, this.icon, this.emphasis = false});
  final String text;
  final IconData? icon;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: emphasis ? SanketColors.primary : Colors.white.withOpacity(.92),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 8)],
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (icon != null) ...[
            Icon(icon, color: emphasis ? Colors.white : SanketColors.primary),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Text(text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: emphasis ? Colors.white : SanketColors.ink,
                    fontWeight: FontWeight.w800,
                    fontSize: emphasis ? 20 : 16)),
          ),
        ]),
      );
}

/// Mascot image from the green-bird emotion set.
class Mascot extends StatelessWidget {
  const Mascot(this.emotion, {super.key, this.height = 120, this.label});
  final String emotion;
  final double height;
  final String? label;

  @override
  Widget build(BuildContext context) =>
      Image.asset('assets/mascot/$emotion.png', height: height, semanticLabel: label, excludeFromSemantics: label == null);
}
