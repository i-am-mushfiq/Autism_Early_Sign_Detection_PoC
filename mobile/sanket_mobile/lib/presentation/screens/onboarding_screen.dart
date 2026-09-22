import 'package:flutter/material.dart';

import '../../l10n/locale_scope.dart';
import '../theme.dart';
import '../widgets/sanket_logo.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.onDone,
    required this.onLanguageChanged,
  });

  final VoidCallback onDone;
  final ValueChanged<AppLanguage> onLanguageChanged;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bn = context.s.isBangla;
    final pages = [
      _OnboardingData(
        Icons.insights_rounded,
        bn
            ? 'ছোট ছোট পরিবর্তন লক্ষ্য করুন'
            : 'Notice small developmental changes',
        bn
            ? 'নিয়মিত, একইভাবে পর্যবেক্ষণ করলে শিশুর আচরণের পরিবর্তন বুঝতে সুবিধা হয়।'
            : 'Short, consistent observations can make changes in your child’s behaviour easier to understand.',
      ),
      _OnboardingData(
        Icons.child_care_rounded,
        bn ? 'খেলার মতো সহজ কার্যক্রম' : 'Simple, play-based activities',
        bn
            ? 'আপনি শিশুকে সাহায্য করবেন। সংকেত ক্যামেরা, মাইক্রোফোন ও স্পর্শ থেকে শুধুমাত্র প্রয়োজনীয় সংকেত পর্যবেক্ষণ করবে।'
            : 'You guide your child while Sanket observes selected signals from the camera, microphone, and touch.',
      ),
      _OnboardingData(
        Icons.shield_outlined,
        bn ? 'ব্যক্তিগত এবং সহায়ক' : 'Private and supportive',
        bn
            ? 'সব প্রক্রিয়াকরণ এই ফোনে হয়। সংকেত কোনো রোগ নির্ণয় করে না—এটি পরবর্তী পদক্ষেপ বুঝতে সাহায্য করে।'
            : 'Processing happens on this phone. Sanket does not diagnose—it helps you understand possible next steps.',
      ),
    ];
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 12, 0),
              child: Row(
                children: [
                  const SanketLogo(size: 40),
                  const Spacer(),
                  TextButton.icon(
                    onPressed: () => widget.onLanguageChanged(
                      bn ? AppLanguage.en : AppLanguage.bn,
                    ),
                    icon: const Icon(Icons.translate),
                    label: Text(bn ? 'English' : 'বাংলা'),
                  ),
                  TextButton(
                    onPressed: widget.onDone,
                    child: Text(bn ? 'এড়িয়ে যান' : 'Skip'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _controller,
                itemCount: pages.length,
                onPageChanged: (value) => setState(() => _page = value),
                itemBuilder: (context, index) => _OnboardingPage(
                  data: pages[index],
                  page: index,
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < pages.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: i == _page ? 26 : 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: i == _page
                          ? SanketColors.primary
                          : SanketColors.border,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 24),
              child: Row(
                children: [
                  if (_page > 0)
                    IconButton.filledTonal(
                      tooltip: bn ? 'পেছনে' : 'Back',
                      onPressed: () => _controller.previousPage(
                        duration: const Duration(milliseconds: 260),
                        curve: Curves.easeOut,
                      ),
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  if (_page > 0) const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _page == pages.length - 1
                          ? widget.onDone
                          : () => _controller.nextPage(
                                duration: const Duration(milliseconds: 260),
                                curve: Curves.easeOut,
                              ),
                      icon: Icon(_page == pages.length - 1
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded),
                      label: Text(_page == pages.length - 1
                          ? (bn ? 'শুরু করুন' : 'Get started')
                          : (bn ? 'পরবর্তী' : 'Next')),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingData {
  const _OnboardingData(this.icon, this.title, this.body);
  final IconData icon;
  final String title, body;
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data, required this.page});
  final _OnboardingData data;
  final int page;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 22),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 190,
              height: 190,
              decoration: BoxDecoration(
                color: [
                  SanketColors.mint,
                  SanketColors.cream,
                  SanketColors.pale,
                ][page],
                shape: BoxShape.circle,
              ),
              child: Icon(data.icon, size: 92, color: SanketColors.primary),
            ),
            const SizedBox(height: 44),
            Text(
              data.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              data.body,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: SanketColors.muted,
                height: 1.55,
              ),
            ),
          ],
        ),
      );
}
