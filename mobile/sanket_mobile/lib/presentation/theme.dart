import 'package:flutter/material.dart';

import '../l10n/locale_scope.dart';
import '../tour/tour_scope.dart';

class SanketColors {
  static const primary = Color(0xff176b57);
  static const primaryDeep = Color(0xff075449);
  static const ink = Color(0xff083e36);
  static const leaf = Color(0xff238651);
  static const muted = Color(0xff64736e);
  static const faint = Color(0xff788680);
  static const ground = Color(0xfff6f7f3);
  static const border = Color(0xffdce4df);
  static const mint = Color(0xffedf8f3);
  static const pale = Color(0xffe6f0ea);
  static const cream = Color(0xfffffbf2);
  static const warn = Color(0xffb55b19);
  static const warnSoft = Color(0xfffff3e6);
  static const board = Color(0xffedf8f5);
}

ThemeData sanketTheme(AppLanguage language) {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(seedColor: SanketColors.primary),
    scaffoldBackgroundColor: SanketColors.ground,
  );
  // Bangla script needs more line height to stay readable.
  final height = language == AppLanguage.bn ? 1.5 : 1.35;
  return base.copyWith(
    textTheme: base.textTheme
        .apply(bodyColor: SanketColors.ink, displayColor: SanketColors.ink)
        .copyWith(
          bodyMedium:
              base.textTheme.bodyMedium?.copyWith(height: height, fontSize: 15),
          bodyLarge:
              base.textTheme.bodyLarge?.copyWith(height: height, fontSize: 16),
        ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(64, 56),
        backgroundColor: SanketColors.primary,
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(64, 52),
        foregroundColor: SanketColors.primary,
        side: const BorderSide(color: SanketColors.border, width: 1.5),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: SanketColors.border)),
    ),
  );
}

/// Overline + title + optional lead, as used across Sanket's screens.
class SectionHeader extends StatelessWidget {
  const SectionHeader(
      {super.key, required this.overline, required this.title, this.lead});
  final String overline, title;
  final String? lead;

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(overline.toUpperCase(),
            style: const TextStyle(
                color: SanketColors.primary,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                letterSpacing: 1.2)),
        const SizedBox(height: 10),
        Semantics(
          header: true,
          child: Text(title,
              style: TextStyle(
                  fontSize: context.s.isBangla ? 27 : 30,
                  fontWeight: FontWeight.w800,
                  height: context.s.isBangla ? 1.3 : 1.1)),
        ),
        if (lead != null)
          Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(lead!,
                  style: const TextStyle(
                      fontSize: 16, color: SanketColors.muted, height: 1.5))),
      ]);
}

class InfoCard extends StatelessWidget {
  const InfoCard(
      {super.key,
      required this.child,
      this.color,
      this.padding = 18,
      this.margin = 16});
  final Widget child;
  final Color? color;
  final double padding, margin;

  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      margin: EdgeInsets.only(top: margin),
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
          color: color ?? Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: SanketColors.border)),
      child: child);
}

class IconNote extends StatelessWidget {
  const IconNote(
      {super.key,
      required this.icon,
      required this.text,
      this.color,
      this.iconColor});
  final IconData icon;
  final String text;
  final Color? color, iconColor;

  @override
  Widget build(BuildContext context) => InfoCard(
      color: color,
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: iconColor ?? SanketColors.leaf),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
      ]));
}

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.pale = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool pale;

  @override
  Widget build(BuildContext context) {
    final style = pale
        ? FilledButton.styleFrom(
            backgroundColor: SanketColors.pale,
            foregroundColor: SanketColors.primary)
        : null;
    return TourTarget(
        label: label,
        child: Padding(
          padding: const EdgeInsets.only(top: 14),
          child: SizedBox(
            width: double.infinity,
            child: icon == null
                ? FilledButton(
                    onPressed: onPressed,
                    style: style,
                    child: Text(label, textAlign: TextAlign.center))
                : FilledButton.icon(
                    onPressed: onPressed,
                    style: style,
                    icon: Icon(icon),
                    label: Text(label)),
          ),
        ));
  }
}

/// Large two-option selector used for yes/no profile questions.
class ChoiceQuestion<V> extends StatelessWidget {
  const ChoiceQuestion(
      {super.key,
      required this.label,
      required this.value,
      required this.options,
      required this.onChanged});
  final String label;
  final V value;
  final Map<V, String> options;
  final ValueChanged<V> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 18),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style:
                  const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          if (options.length <= 3)
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<V>(
                showSelectedIcon: false,
                style:
                    SegmentedButton.styleFrom(minimumSize: const Size(48, 48)),
                segments: [
                  for (final e in options.entries)
                    ButtonSegment(value: e.key, label: Text(e.value)),
                ],
                selected: {value},
                onSelectionChanged: (v) => onChanged(v.first),
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in options.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: e.key == value,
                    onSelected: (_) => onChanged(e.key),
                  ),
              ],
            ),
        ]),
      );
}

class StatusPill extends StatelessWidget {
  const StatusPill(
      {super.key,
      required this.text,
      this.color = SanketColors.primary,
      this.background});
  final String text;
  final Color color;
  final Color? background;

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
          color: background ?? Colors.white.withOpacity(.9),
          borderRadius: BorderRadius.circular(20)),
      child: Text(text,
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 13)));
}
