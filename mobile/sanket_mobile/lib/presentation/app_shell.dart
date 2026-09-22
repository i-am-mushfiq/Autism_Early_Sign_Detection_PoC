import 'dart:ui';

import 'package:flutter/material.dart';

import '../core/session.dart';
import '../l10n/locale_scope.dart';
import '../runtime/session_controller.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/profile_screen.dart';
import 'theme.dart';
import 'widgets/sanket_logo.dart';

class AppShell extends StatelessWidget {
  const AppShell({
    super.key,
    required this.session,
    required this.index,
    required this.onIndexChanged,
    required this.onStart,
    required this.onStartTour,
    required this.onOpenRecord,
    required this.onSaveProfile,
    required this.onLanguageChanged,
    required this.onReplayOnboarding,
  });

  final SessionController session;
  final int index;
  final ValueChanged<int> onIndexChanged;
  final VoidCallback onStart;
  final VoidCallback onStartTour;
  final ValueChanged<SessionRecord> onOpenRecord;
  final Future<void> Function(ChildProfile) onSaveProfile;
  final ValueChanged<AppLanguage> onLanguageChanged;
  final VoidCallback onReplayOnboarding;

  @override
  Widget build(BuildContext context) {
    final bn = context.s.isBangla;
    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          SafeArea(
            bottom: false,
            child: Container(
              width: double.infinity,
              color: SanketColors.mint,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
              child: Row(
                children: [
                  const SanketLogo(size: 42),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Sanket',
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: SanketColors.primaryDeep,
                        fontSize: 25,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => onLanguageChanged(
                      bn ? AppLanguage.en : AppLanguage.bn,
                    ),
                    icon: const Icon(Icons.translate_rounded),
                    label: Text(bn ? 'English' : 'বাংলা'),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: IndexedStack(
                index: index,
                children: [
                  HomeScreen(
                    session: session,
                    onStart: onStart,
                    onStartTour: onStartTour,
                    onOpenLatest: onOpenRecord,
                  ),
                  HistoryScreen(
                    session: session,
                    onNewSession: onStart,
                    onOpen: onOpenRecord,
                  ),
                  ProfileScreen(
                    session: session,
                    standalone: true,
                    onContinue: () {},
                    onSaved: onSaveProfile,
                    onLanguageChanged: onLanguageChanged,
                    onReplayOnboarding: onReplayOnboarding,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
          child: SafeArea(
            minimum: const EdgeInsets.fromLTRB(18, 0, 18, 14),
            child: Material(
              elevation: 14,
              shadowColor: Colors.black.withValues(alpha: .22),
              color: SanketColors.pale.withValues(alpha: .78),
              borderRadius: BorderRadius.circular(25),
              clipBehavior: Clip.antiAlias,
              child: NavigationBar(
                height: 72,
                backgroundColor: Colors.transparent,
                indicatorColor: Colors.white,
                selectedIndex: index,
                onDestinationSelected: onIndexChanged,
                destinations: [
                  NavigationDestination(
                    icon: const Icon(Icons.home_outlined),
                    selectedIcon: const Icon(Icons.home_rounded),
                    label: bn ? 'হোম' : 'Home',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.history_rounded),
                    selectedIcon:
                        const Icon(Icons.history_toggle_off_rounded),
                    label: bn ? 'ইতিহাস' : 'History',
                  ),
                  NavigationDestination(
                    icon: const Icon(Icons.person_outline_rounded),
                    selectedIcon: const Icon(Icons.person_rounded),
                    label: bn ? 'প্রোফাইল' : 'Profile',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
