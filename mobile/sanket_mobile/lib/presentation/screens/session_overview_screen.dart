import 'package:flutter/material.dart';

import '../../core/activity_catalog.dart';
import '../../core/measurement.dart';
import '../../core/prototype_parameters.dart';
import '../../l10n/locale_scope.dart';
import '../theme.dart';

class SessionOverviewScreen extends StatelessWidget {
  const SessionOverviewScreen({super.key, required this.onContinue});
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final bn = s.isBangla;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            overline: bn ? 'সেশনের প্রস্তুতি' : 'Before you begin',
            title: bn ? 'আজকের সেশনে যা থাকবে' : 'What happens in a session',
            lead: bn
                ? 'শান্ত জায়গায় শিশুর সাথে থাকুন। প্রতিটি কার্যক্রমের আগে পূর্ণ নির্দেশনা দেখানো হবে।'
                : 'Stay with your child in a calm place. A complete guide appears before every activity.',
          ),
          InfoCard(
            color: SanketColors.mint,
            child: Row(
              children: [
                const Icon(Icons.schedule_rounded,
                    color: SanketColors.primary, size: 34),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bn ? 'প্রায় ৬–৮ মিনিট' : 'About 6–8 minutes',
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w900),
                      ),
                      Text(
                        bn
                            ? 'শিশুর বয়স অনুযায়ী ৫–৬টি কার্যক্রম'
                            : '5–6 activities based on the child’s age',
                        style: const TextStyle(color: SanketColors.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            bn ? 'কার্যক্রমগুলো' : 'Activities',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 10),
          for (final definition in activityCatalog)
            _ActivityCard(definition: definition),
          IconNote(
            icon: Icons.videocam_off_outlined,
            color: SanketColors.cream,
            text: bn
                ? 'কোনো ভিডিও বা অডিও সংরক্ষণ করা হয় না। অনুমতি দিলে শুধুমাত্র তৈরি হওয়া পর্যবেক্ষণ এই ফোনে রাখা হয়।'
                : 'No video or audio is stored. Only derived observations are kept on this phone when you allow it.',
          ),
          PrimaryButton(
            label: bn ? 'শিশুর তথ্য দিন' : 'Continue to child information',
            icon: Icons.arrow_forward_rounded,
            onPressed: onContinue,
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.definition});
  final ActivityDefinition definition;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final bn = s.isBangla;
    final data = _details(definition.id, bn);
    return InfoCard(
      margin: 10,
      padding: 14,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: SanketColors.mint,
              borderRadius: BorderRadius.circular(15),
            ),
            child: Icon(data.icon, color: SanketColors.primary),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.activityName(definition.id),
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.w900),
                      ),
                    ),
                    Text(data.duration,
                        style: const TextStyle(
                            color: SanketColors.muted,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(data.description,
                    style: const TextStyle(color: SanketColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final modality in definition.modalities.where(
                      (value) =>
                          value == Modality.camera ||
                          value == Modality.audio ||
                          value == Modality.touch,
                    ))
                      _Tag(label: _modality(modality, bn)),
                    if (definition.minAgeMonths > 0)
                      _Tag(
                          label: bn
                              ? '${P.switchMinAgeMonths}+ মাস'
                              : '${P.switchMinAgeMonths}+ months'),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _modality(Modality modality, bool bn) => switch (modality) {
      Modality.camera => bn ? 'ক্যামেরা' : 'Camera',
      Modality.audio => bn ? 'মাইক্রোফোন' : 'Microphone',
      Modality.touch => bn ? 'স্পর্শ' : 'Touch',
      _ => '',
    };

({IconData icon, String duration, String description}) _details(
        ActivityId id, bool bn) =>
    switch (id) {
      ActivityId.socialStory => (
          icon: Icons.menu_book_rounded,
          duration: bn ? '১ মিনিট' : '1 min',
          description: bn
              ? 'একটি ছোট গল্প দেখার সময় শিশুর মনোযোগ লক্ষ্য করা হয়।'
              : 'Observe attention while a short visual story plays.',
        ),
      ActivityId.nameResponse => (
          icon: Icons.record_voice_over_rounded,
          duration: bn ? '১ মিনিট' : '1 min',
          description: bn
              ? 'শান্তভাবে নাম ধরে ডাকলে শিশুর প্রতিক্রিয়া দেখা হয়।'
              : 'Observe the child’s response when you calmly call their name.',
        ),
      ActivityId.followMyLook => (
          icon: Icons.visibility_rounded,
          duration: bn ? '১ মিনিট' : '1 min',
          description: bn
              ? 'শিশু আপনার দৃষ্টির দিক অনুসরণ করে কি না দেখা হয়।'
              : 'See whether the child follows the direction of your gaze.',
        ),
      ActivityId.bubbleTrail => (
          icon: Icons.bubble_chart_rounded,
          duration: bn ? '৪০ সেকেন্ড' : '40 sec',
          description: bn
              ? 'বুদবুদ স্পর্শ করার ধরন ও আগ্রহ লক্ষ্য করা হয়।'
              : 'Observe touch patterns and engagement with moving bubbles.',
        ),
      ActivityId.copyMe => (
          icon: Icons.accessibility_new_rounded,
          duration: bn ? '১ মিনিট' : '1 min',
          description: bn
              ? 'সহজ নড়াচড়া অনুকরণ করার চেষ্টা দেখা হয়।'
              : 'Invite the child to copy a few simple movements.',
        ),
      ActivityId.switchIt => (
          icon: Icons.swap_horiz_rounded,
          duration: bn ? '১ মিনিট' : '1 min',
          description: bn
              ? 'নিয়ম বদলালে শিশু কীভাবে মানিয়ে নেয় তা দেখা হয়।'
              : 'Observe how the child adapts when a simple rule changes.',
        ),
    };

class _Tag extends StatelessWidget {
  const _Tag({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: SanketColors.pale,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
      );
}
