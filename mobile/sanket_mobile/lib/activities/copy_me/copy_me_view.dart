import 'package:flutter/material.dart';

import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../presentation/theme.dart';
import '../../presentation/widgets/board.dart';
import '../../presentation/widgets/frame_ticker.dart';
import '../../presentation/widgets/guide_figure.dart';
import 'copy_me_controller.dart';
import 'pose_actions.dart';

T copyActionLabel(CopyAction a) => switch (a) {
      CopyAction.handsUp => T.copyHandsUp,
      CopyAction.clap => T.copyClap,
      CopyAction.touchHead => T.copyTouchHead,
    };

ArmPose _arms(CopyAction a) => switch (a) {
      CopyAction.handsUp => ArmPose.up,
      CopyAction.clap => ArmPose.clap,
      CopyAction.touchHead => ArmPose.head,
    };

class CopyMeBoard extends StatelessWidget {
  const CopyMeBoard({super.key, required this.controller});
  final CopyMeController controller;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return FrameTicker(
      nowMs: () => controller.now,
      builder: (context, now) {
        final c = controller;
        final phase = (now % 1600) / 1600;
        Widget content;
        BoardBanner? banner;
        switch (c.copyPhase) {
          case CopyPhase.framing:
          case CopyPhase.between:
            content = Center(
                child: FittedBox(child: GuideFigure(size: 160, phase: phase)));
          case CopyPhase.demo:
            banner = BoardBanner(text: s(T.copyWatch));
            content = Center(
                child: FittedBox(
                    child: GuideFigure(
                        size: 170,
                        arms: _arms(c.action),
                        phase: phase,
                        talking: true)));
          case CopyPhase.window:
            banner = BoardBanner(
                text: '${s(T.copyYourTurn)} ${s(copyActionLabel(c.action))}',
                emphasis: true);
            content = Center(
                child: Opacity(
                    opacity: .55,
                    child: FittedBox(
                        child: GuideFigure(
                            size: 150, arms: _arms(c.action), phase: phase))));
          case CopyPhase.feedback:
            content = Center(
                child: Column(mainAxisSize: MainAxisSize.min, children: [
              const Mascot('excited', height: 150),
              const SizedBox(height: 8),
              StatusPill(text: s(T.reward)),
            ]));
        }
        return ActivityBoard(
            colors: const [Color(0xffffe3c7), Color(0xfffdf6d8)],
            banner: banner,
            child: content);
      },
    );
  }
}

class CopyMePanel extends StatelessWidget {
  const CopyMePanel(
      {super.key, required this.controller, required this.name, this.preview});
  final CopyMeController controller;
  final String name;
  final Widget? preview;

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
                  text: s(T.stageTryOf, {'n': c.trial.clamp(1, 3), 'total': 3}),
                  background: SanketColors.pale),
              if (preview != null) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Stack(children: [
                    ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 110),
                        child: Center(child: preview)),
                    Positioned(
                      left: 6,
                      top: 6,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                            color: Colors.black54, shape: BoxShape.circle),
                        child: Icon(
                            c.framed ? Icons.check_circle : Icons.crop_free,
                            size: 20,
                            color: c.framed
                                ? const Color(0xff7ff1b1)
                                : Colors.white),
                      ),
                    ),
                  ]),
                ),
              ],
              if (c.copyPhase == CopyPhase.framing && !c.framed)
                IconNote(
                    icon: Icons.open_with,
                    iconColor: SanketColors.warn,
                    color: SanketColors.warnSoft,
                    text: s(T.copyFraming, {'name': name})),
              if (c.seen != null)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(children: [
                    const Icon(Icons.visibility,
                        color: SanketColors.leaf, size: 18),
                    const SizedBox(width: 6),
                    Text(s(T.copySeen),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
            ]);
      },
    );
  }
}
