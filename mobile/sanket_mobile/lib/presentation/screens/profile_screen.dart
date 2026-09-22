import 'package:flutter/material.dart';

import '../../core/prototype_parameters.dart';
import '../../core/session.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../runtime/session_controller.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({
    super.key,
    required this.session,
    required this.onContinue,
    this.standalone = false,
    this.onSaved,
    this.onLanguageChanged,
    this.onReplayOnboarding,
  });
  final SessionController session;
  final VoidCallback onContinue;
  final bool standalone;
  final Future<void> Function(ChildProfile profile)? onSaved;
  final ValueChanged<AppLanguage>? onLanguageChanged;
  final VoidCallback? onReplayOnboarding;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name =
      TextEditingController(text: widget.session.profile?.nickname ?? '');
  late final _age = TextEditingController(
      text: widget.session.profile?.ageMonths.toString() ?? '');
  late ChildProfile _p =
      widget.session.profile ?? const ChildProfile(nickname: '', ageMonths: 0);

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    super.dispose();
  }

  int? get _ageValue => int.tryParse(_age.text.trim());

  void _update(ChildProfile Function(ChildProfile p) change) =>
      setState(() => _p = change(_p));

  ChildProfile _with({
    PrimaryLanguage? primary,
    OtherLanguage? other,
    bool? hearing,
    bool? vision,
    bool? motor,
    bool? prior,
    ScreenFamiliarity? screen,
  }) =>
      ChildProfile(
        nickname: _name.text.trim(),
        ageMonths: _ageValue ?? 0,
        primaryLanguage: primary ?? _p.primaryLanguage,
        otherLanguage: other ?? _p.otherLanguage,
        hearingConcern: hearing ?? _p.hearingConcern,
        visionConcern: vision ?? _p.visionConcern,
        motorDifficulty: motor ?? _p.motorDifficulty,
        priorConcern: prior ?? _p.priorConcern,
        screenFamiliarity: screen ?? _p.screenFamiliarity,
      );

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final yesNo = {false: s(T.no), true: s(T.yes)};
    final age = _ageValue;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(24, 24, 24, widget.standalone ? 132 : 24),
      child: Form(
        key: _form,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SectionHeader(
              overline: s(T.profileOverline),
              title: s(T.profileTitle),
              lead: s(T.profileLead)),
          const SizedBox(height: 20),
          TextFormField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
                labelText: s(T.profileName), helperText: s(T.profileNameHelp)),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? s(T.profileNameMissing) : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _age,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: s(T.profileAge)),
            onChanged: (_) => setState(() {}),
            validator: (v) {
              final a = int.tryParse((v ?? '').trim());
              return a == null || a < P.minAgeMonths || a > P.maxAgeMonths
                  ? s(T.profileAgeInvalid)
                  : null;
            },
          ),
          if (age != null &&
              age >= P.minAgeMonths &&
              age < P.switchMinAgeMonths)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(s(T.profileUnder24Note),
                  style: const TextStyle(color: SanketColors.muted)),
            ),
          ChoiceQuestion<PrimaryLanguage>(
            label: s(T.profilePrimaryLanguage),
            value: _p.primaryLanguage,
            options: {
              PrimaryLanguage.bangla: s(T.langBangla),
              PrimaryLanguage.english: s(T.langEnglish),
              PrimaryLanguage.both: s(T.langBoth),
            },
            onChanged: (v) => _update((_) => _with(primary: v)),
          ),
          ChoiceQuestion<OtherLanguage>(
            label: s(T.profileOtherLanguage),
            value: _p.otherLanguage,
            options: {
              OtherLanguage.none: s(T.langNone),
              OtherLanguage.bangla: s(T.langBangla),
              OtherLanguage.english: s(T.langEnglish),
              OtherLanguage.other: s(T.langOther),
            },
            onChanged: (v) => _update((_) => _with(other: v)),
          ),
          ChoiceQuestion<bool>(
              label: s(T.profileHearing),
              value: _p.hearingConcern,
              options: yesNo,
              onChanged: (v) => _update((_) => _with(hearing: v))),
          ChoiceQuestion<bool>(
              label: s(T.profileVision),
              value: _p.visionConcern,
              options: yesNo,
              onChanged: (v) => _update((_) => _with(vision: v))),
          ChoiceQuestion<bool>(
              label: s(T.profileMotor),
              value: _p.motorDifficulty,
              options: yesNo,
              onChanged: (v) => _update((_) => _with(motor: v))),
          ChoiceQuestion<bool>(
              label: s(T.profilePriorConcern),
              value: _p.priorConcern,
              options: yesNo,
              onChanged: (v) => _update((_) => _with(prior: v))),
          ChoiceQuestion<ScreenFamiliarity>(
            label: s(T.profileScreen),
            value: _p.screenFamiliarity,
            options: {
              ScreenFamiliarity.low: s(T.screenLow),
              ScreenFamiliarity.medium: s(T.screenMedium),
              ScreenFamiliarity.high: s(T.screenHigh),
            },
            onChanged: (v) => _update((_) => _with(screen: v)),
          ),
          IconNote(
              icon: Icons.spa_outlined,
              color: SanketColors.mint,
              text: s(T.profileContextNote)),
          PrimaryButton(
            label: widget.standalone
                ? (s.isBangla ? 'প্রোফাইল সংরক্ষণ করুন' : 'Save profile')
                : s(T.continueLabel),
            onPressed: () async {
              if (!(_form.currentState?.validate() ?? false)) return;
              final profile = _with();
              widget.session.setProfile(profile);
              await widget.onSaved?.call(profile);
              if (!context.mounted) return;
              if (widget.standalone) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text(s.isBangla
                          ? 'প্রোফাইল সংরক্ষিত হয়েছে'
                          : 'Profile saved')),
                );
              }
              widget.onContinue();
            },
          ),
          if (widget.standalone) ...[
            const SizedBox(height: 28),
            Text(
              s.isBangla ? 'অ্যাপ সেটিংস' : 'App settings',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
            ),
            InfoCard(
              margin: 12,
              padding: 4,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.translate,
                        color: SanketColors.primary),
                    title: Text(s.isBangla ? 'অ্যাপের ভাষা' : 'App language'),
                    subtitle: Text(s.isBangla ? 'বাংলা' : 'English'),
                    trailing: TextButton(
                      onPressed: () => widget.onLanguageChanged?.call(
                        s.isBangla ? AppLanguage.en : AppLanguage.bn,
                      ),
                      child: Text(s.isBangla ? 'English' : 'বাংলা'),
                    ),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.slideshow_rounded,
                        color: SanketColors.primary),
                    title: Text(s.isBangla
                        ? 'পরিচিতি আবার দেখুন'
                        : 'View introduction again'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: widget.onReplayOnboarding,
                  ),
                ],
              ),
            ),
          ],
        ]),
      ),
    );
  }
}
