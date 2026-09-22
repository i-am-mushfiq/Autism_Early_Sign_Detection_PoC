import 'package:flutter/material.dart';

import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../runtime/session_controller.dart';
import '../theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen(
      {super.key,
      required this.session,
      required this.onStart,
      required this.onHistory});
  final SessionController session;
  final VoidCallback onStart, onHistory;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(children: [
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => session
                .setLanguage(s.isBangla ? AppLanguage.en : AppLanguage.bn),
            icon: const Icon(Icons.translate),
            label: Text(s(T.switchLanguage),
                style:
                    const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ),
        ),
        const Icon(Icons.spa_outlined, size: 52, color: SanketColors.leaf),
        Semantics(
          header: true,
          child: Text(s(T.appName),
              style: const TextStyle(
                  fontSize: 50,
                  height: 1.1,
                  color: SanketColors.primaryDeep,
                  fontWeight: FontWeight.w900)),
        ),
        const SizedBox(height: 14),
        Text(s(T.tagline),
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 24, fontWeight: FontWeight.w800, height: 1.35)),
        const SizedBox(height: 6),
        Image.asset('assets/sanket_companion.png',
            height: 190, semanticLabel: s(T.welcomeCompanionLabel)),
        Text(s(T.welcomeLead),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, height: 1.55)),
        const SizedBox(height: 8),
        Text(s(T.welcomeDuration),
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: SanketColors.muted, fontWeight: FontWeight.w600)),
        PrimaryButton(
            label: s(T.welcomeStart),
            icon: Icons.arrow_forward_rounded,
            onPressed: onStart),
        PrimaryButton(
            label: s(T.welcomeHistory), pale: true, onPressed: onHistory),
        IconNote(
            icon: Icons.shield_outlined,
            color: SanketColors.cream,
            text: s(T.welcomePrivacy)),
      ]),
    );
  }
}
