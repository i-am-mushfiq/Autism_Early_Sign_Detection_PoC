import 'dart:convert';

import '../l10n/locale_scope.dart';
import 'session.dart';
import 'session_repository.dart';

class AppPreferenceData {
  const AppPreferenceData({
    required this.onboardingCompleted,
    required this.language,
    this.profile,
  });

  final bool onboardingCompleted;
  final AppLanguage language;
  final ChildProfile? profile;
}

/// Small, independent store for caregiver preferences. Session records remain
/// immutable snapshots in [SessionRepository].
class AppPreferences {
  AppPreferences(this.store, {this.defaultOnboardingCompleted = false});

  final KeyValueStore store;
  final bool defaultOnboardingCompleted;

  static const _onboardingKey = 'sanket_onboarding_completed_v1';
  static const _languageKey = 'sanket_language_v1';
  static const _profileKey = 'sanket_profile_v1';

  Future<AppPreferenceData> load() async {
    final values = await Future.wait([
      store.read(_onboardingKey),
      store.read(_languageKey),
      store.read(_profileKey),
    ]);
    ChildProfile? profile;
    try {
      final raw = values[2];
      if (raw != null) {
        profile = ChildProfile.fromJson(
          Map<String, dynamic>.from(jsonDecode(raw) as Map),
        );
      }
    } catch (_) {
      profile = null;
    }
    return AppPreferenceData(
      onboardingCompleted:
          values[0] == null ? defaultOnboardingCompleted : values[0] == 'true',
      language: AppLanguage.values
              .where((value) => value.name == values[1])
              .firstOrNull ??
          AppLanguage.en,
      profile: profile,
    );
  }

  Future<void> completeOnboarding() => store.write(_onboardingKey, 'true');

  Future<void> saveLanguage(AppLanguage language) =>
      store.write(_languageKey, language.name);

  Future<void> saveProfile(ChildProfile profile) =>
      store.write(_profileKey, jsonEncode(profile.toJson()));
}
