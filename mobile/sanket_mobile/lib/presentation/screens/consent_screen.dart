import 'package:flutter/material.dart';

import '../../core/session.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../runtime/session_controller.dart';
import '../theme.dart';

class ConsentScreen extends StatelessWidget {
  const ConsentScreen({super.key, required this.session, required this.onAgree});
  final SessionController session;
  final VoidCallback onAgree;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final c = session.consents;
    void set(ConsentChoices next) => session.setConsents(next);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(overline: s(T.consentOverline), title: s(T.consentTitle)),
        InfoCard(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _Can(icon: Icons.check_circle_outline, color: SanketColors.leaf, label: s(T.canLabel), text: s(T.consentCan)),
            const Divider(height: 24),
            _Can(icon: Icons.block, color: SanketColors.warn, label: s(T.cannotLabel), text: s(T.consentCannot)),
          ]),
        ),
        const SizedBox(height: 22),
        Text(s(T.consentChoose), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        _ConsentTile(
          required: true,
          value: c.processing,
          title: s(T.consentProcessingTitle),
          body: s(T.consentProcessingBody),
          onChanged: (v) => set(c.copyWith(processing: v)),
        ),
        _ConsentTile(
          value: c.storeOnDevice,
          title: s(T.consentStoreTitle),
          body: s(T.consentStoreBody),
          onChanged: (v) => set(c.copyWith(storeOnDevice: v)),
        ),
        _ConsentTile(
          value: c.shareWithProfessional,
          title: s(T.consentShareTitle),
          body: s(T.consentShareBody),
          onChanged: (v) => set(c.copyWith(shareWithProfessional: v)),
        ),
        _ConsentTile(
          value: c.research,
          title: s(T.consentResearchTitle),
          body: s(T.consentResearchBody),
          onChanged: (v) => set(c.copyWith(research: v)),
        ),
        IconNote(icon: Icons.privacy_tip_outlined, color: SanketColors.cream, text: s(T.consentNever)),
        if (!c.canStart)
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(s(T.consentNeedProcessing), style: const TextStyle(color: SanketColors.warn, fontWeight: FontWeight.w600)),
          ),
        PrimaryButton(label: s(T.consentAgree), onPressed: c.canStart ? onAgree : null),
      ]),
    );
  }
}

class _Can extends StatelessWidget {
  const _Can({required this.icon, required this.color, required this.label, required this.text});
  final IconData icon;
  final Color color;
  final String label, text;
  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(text),
          ]),
        ),
      ]);
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile(
      {required this.value, required this.title, required this.body, required this.onChanged, this.required = false});
  final bool value, required;
  final String title, body;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return InfoCard(
      margin: 12,
      padding: 4,
      color: value ? SanketColors.mint : Colors.white,
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
        title: Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text((required ? s(T.consentRequired) : s(T.consentOptional)).toUpperCase(),
                style: TextStyle(
                    fontSize: 11,
                    letterSpacing: 1,
                    fontWeight: FontWeight.w800,
                    color: required ? SanketColors.warn : SanketColors.primary)),
            const SizedBox(height: 2),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ]),
        ),
        subtitle: Text(body, style: const TextStyle(color: SanketColors.muted)),
      ),
    );
  }
}
