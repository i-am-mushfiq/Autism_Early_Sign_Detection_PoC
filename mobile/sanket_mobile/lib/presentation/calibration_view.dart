import 'package:flutter/material.dart';

import '../core/calibration.dart';
import '../l10n/locale_scope.dart';
import '../l10n/strings.dart';
import '../runtime/calibration_controller.dart';
import 'theme.dart';
import 'widgets/board.dart';

/// Child-facing calibration board: the star moves through the four targets.
class CalibrationBoard extends StatelessWidget {
  const CalibrationBoard({super.key, required this.controller, this.preview});
  final CalibrationController controller;
  final Widget? preview;

  static Alignment alignmentOf(CalibrationTarget t) => switch (t) {
        CalibrationTarget.center => Alignment.center,
        CalibrationTarget.left => const Alignment(-0.86, 0.1),
        CalibrationTarget.right => const Alignment(0.86, 0.1),
        CalibrationTarget.upper => const Alignment(0, -0.8),
      };

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final c = controller;
        switch (c.phase) {
          case CalibrationPhase.intro:
          case CalibrationPhase.waitingForFace:
            return ActivityBoard(
              colors: const [Color(0xfff0f7f1), Color(0xffdff1e6)],
              child: Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  if (preview != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: ConstrainedBox(
                          constraints: const BoxConstraints(
                              maxHeight: 180, maxWidth: 320),
                          child: preview),
                    ),
                  const SizedBox(height: 12),
                  const _PulsingStar(),
                ]),
              ),
            );
          case CalibrationPhase.running:
            return ActivityBoard(
              colors: const [Color(0xff16324a), Color(0xff1f4d5c)],
              banner: BoardBanner(text: s(T.calRunning)),
              child: AnimatedAlign(
                alignment: alignmentOf(c.target ?? CalibrationTarget.center),
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInOut,
                child: const _PulsingStar(),
              ),
            );
          case CalibrationPhase.done:
            final ok = c.result.usable;
            return ActivityBoard(
              colors: const [Color(0xfff0f7f1), Color(0xffdff1e6)],
              child: Center(
                  child: Mascot(ok ? 'excited' : 'curious', height: 170)),
            );
        }
      },
    );
  }
}

class _PulsingStar extends StatefulWidget {
  const _PulsingStar();
  @override
  State<_PulsingStar> createState() => _PulsingStarState();
}

class _PulsingStarState extends State<_PulsingStar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 700))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
        scale: Tween(begin: .85, end: 1.1).animate(_c),
        child: const Text('⭐', style: TextStyle(fontSize: 84)),
      );
}

/// Caregiver panel content for calibration, minus the pinned action button.
class CalibrationBody extends StatelessWidget {
  const CalibrationBody(
      {super.key,
      required this.controller,
      required this.name,
      required this.onShowGuide});
  final CalibrationController controller;
  final String name;
  final VoidCallback onShowGuide;

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
              Text(s(T.calTitle),
                  style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w900,
                      color: SanketColors.ink)),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: onShowGuide,
                  icon: const Icon(Icons.help_outline),
                  label: Text(s(T.stageGuide)),
                ),
              ),
              const SizedBox(height: 10),
              if (c.phase != CalibrationPhase.done) ...[
                Text(s(T.calParent, {'name': name}),
                    style: const TextStyle(
                        fontSize: 15, color: Color(0xff415b56))),
                const SizedBox(height: 8),
                Text(s(T.calWhy),
                    style: const TextStyle(
                        fontSize: 13, color: SanketColors.muted)),
                const SizedBox(height: 8),
                IconNote(
                    icon: Icons.open_with,
                    iconColor: SanketColors.warn,
                    color: SanketColors.warnSoft,
                    text: s(T.calFramingHint, {'name': name})),
              ],
              if (c.phase == CalibrationPhase.waitingForFace) ...[
                const SizedBox(height: 14),
                Text(s(T.calWaitingFace, {'name': name}),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                    value: c.recentFaceFraction(), minHeight: 6),
              ],
              if (c.phase == CalibrationPhase.running) ...[
                const SizedBox(height: 14),
                LinearProgressIndicator(
                    value: c.stageIndex / CalibrationController.sequence.length,
                    minHeight: 6),
              ],
              if (c.phase == CalibrationPhase.done)
                InfoCard(
                  margin: 4,
                  color: c.result.usable
                      ? SanketColors.mint
                      : SanketColors.warnSoft,
                  child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                            c.result.usable
                                ? Icons.check_circle
                                : Icons.info_outline,
                            color: c.result.usable
                                ? SanketColors.leaf
                                : SanketColors.warn),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    s(c.result.usable
                                        ? T.calUsable
                                        : T.calUnusable),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800)),
                                const SizedBox(height: 4),
                                Text(c.result.usable
                                    ? s(T.calUsableBody)
                                    : '${s.reason(c.result.reason!, name)} ${s(T.calUnusableBody, {
                                            'name': name
                                          })}'),
                              ]),
                        ),
                      ]),
                ),
            ]);
      },
    );
  }
}

/// Pinned action buttons for calibration, kept out of the scrollable body so
/// they stay visible without scrolling.
class CalibrationActions extends StatelessWidget {
  const CalibrationActions(
      {super.key, required this.controller, required this.onContinue});
  final CalibrationController controller;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final c = controller;
        return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (c.phase == CalibrationPhase.intro)
                PrimaryButton(
                    label: s(T.calStart),
                    icon: Icons.play_arrow_rounded,
                    onPressed: c.start),
              if (c.phase == CalibrationPhase.done) ...[
                if (!c.result.usable && c.canRetry)
                  PrimaryButton(
                      label: s(T.tryAgain),
                      icon: Icons.refresh,
                      onPressed: c.start),
                PrimaryButton(
                    label: c.result.usable
                        ? s(T.continueLabel)
                        : s(T.calContinueWithout),
                    pale: !c.result.usable && c.canRetry,
                    onPressed: onContinue),
              ],
            ]);
      },
    );
  }
}
