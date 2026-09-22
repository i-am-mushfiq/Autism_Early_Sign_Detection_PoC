import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/app_preferences.dart';
import 'core/session.dart';
import 'core/session_repository.dart';
import 'l10n/locale_scope.dart';
import 'l10n/strings.dart';
import 'presentation/app_shell.dart';
import 'presentation/screens/consent_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/result_screen.dart';
import 'presentation/screens/session_overview_screen.dart';
import 'presentation/screens/setup_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/session_stage.dart';
import 'presentation/theme.dart';
import 'presentation/widgets/sanket_logo.dart';
import 'runtime/session_controller.dart';
import 'sensors/device_sensor_hub.dart';
import 'tour/tour_scope.dart';
import 'tour/tour_sensor_hub.dart';
import 'tour/tour_permission_gateway.dart';
import 'presentation/screens/history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final store = SharedPreferencesStore();
  runApp(
    SanketApp(
      session: SessionController(
        repository: SessionRepository(store),
        sensorFactory: DeviceSensorHub.new,
        permissions: DevicePermissionGateway(),
      ),
      preferences: AppPreferences(store),
    ),
  );
}

class SharedPreferencesStore implements KeyValueStore {
  @override
  Future<String?> read(String key) async =>
      (await SharedPreferences.getInstance()).getString(key);

  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);

  @override
  Future<void> remove(String key) async =>
      (await SharedPreferences.getInstance()).remove(key);
}

enum FlowStep {
  splash,
  onboarding,
  shell,
  overview,
  profile,
  consent,
  setup,
  session,
  result,
  pastResult,
  tourHistory,
}

class SanketApp extends StatefulWidget {
  const SanketApp({super.key, required this.session, this.preferences});

  final SessionController session;
  final AppPreferences? preferences;

  @override
  State<SanketApp> createState() => _SanketAppState();
}

class _SanketAppState extends State<SanketApp> {
  SessionController get session => widget.session;
  late final AppPreferences preferences = widget.preferences ??
      AppPreferences(MemoryStore(), defaultOnboardingCompleted: true);

  SessionController? _tourSession;
  bool isTour = false;
  SessionController get activeSession => isTour ? _tourSession! : session;

  FlowStep step = FlowStep.splash;
  SessionRecord? pastRecord;
  int shellIndex = 0;

  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
    _initialize();
  }

  Future<void> _initialize() async {
    final preferenceFuture = preferences.load();
    await session.init();
    final data = await preferenceFuture;
    session.setLanguage(data.language);
    if (data.profile != null) session.setProfile(data.profile!);
    if (!mounted) return;
    setState(() {
      step = data.onboardingCompleted ? FlowStep.shell : FlowStep.onboarding;
    });
  }

  @override
  void dispose() {
    _tourSession?.removeListener(_changed);
    _tourSession?.dispose();
    session.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Future<void> _setLanguage(AppLanguage language) async {
    session.setLanguage(language);
    await preferences.saveLanguage(language);
  }

  Future<void> _saveProfile(ChildProfile profile) async {
    session.setProfile(profile);
    await preferences.saveProfile(profile);
  }

  Future<void> _finishOnboarding() async {
    await preferences.completeOnboarding();
    // A brand-new user lands straight in the guided demo tour instead of an
    // empty shell, so the first thing they see is the whole app working.
    await _startTourFlow();
  }

  void _startSessionFlow() {
    if (session.record?.finished == true) session.resetForNewSession();
    go(FlowStep.overview);
  }

  /// Opens the isolated, tap-driven walkthrough.
  Future<void> _startTourFlow() async {
    if (isTour) return;
    _tourSession?.removeListener(_changed);
    _tourSession?.dispose();
    final demo = SessionController(
      repository: SessionRepository(MemoryStore()),
      sensorFactory: () => TourSensorHub(scripted: true),
      permissions: TourPermissionGateway(),
      allowAutomaticActivityFinish: false,
    );
    _tourSession = demo;
    await demo.init();
    demo.setLanguage(session.language);
    demo.setProfile(const ChildProfile(nickname: 'Adiba', ageMonths: 30));
    demo.setConsents(
        const ConsentChoices(processing: true, storeOnDevice: true));
    demo.addListener(_changed);
    isTour = true;
    await go(FlowStep.overview);
  }

  Future<void> go(FlowStep next) async {
    final landscape = next == FlowStep.session;
    await Future.wait([
      SystemChrome.setPreferredOrientations(
        landscape
            ? const [
                DeviceOrientation.landscapeLeft,
                DeviceOrientation.landscapeRight,
              ]
            : const [DeviceOrientation.portraitUp],
      ),
      SystemChrome.setEnabledSystemUIMode(
        landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge,
      ),
    ]);
    if (next == FlowStep.session && step == FlowStep.setup) {
      await activeSession.sensors.refreshAfterOrientationChange();
    }
    if ((step == FlowStep.session || step == FlowStep.setup) &&
        next != FlowStep.session) {
      await activeSession.releaseSensors();
    }
    if (next == FlowStep.shell && isTour) {
      final demo = _tourSession!;
      demo.removeListener(_changed);
      if (demo.record != null) await demo.finalize(SessionStatus.stoppedEarly);
      isTour = false;
      demo.dispose();
      _tourSession = null;
    }
    if (mounted) setState(() => step = next);
  }

  FlowStep? get _backTarget => switch (step) {
        FlowStep.overview => FlowStep.shell,
        FlowStep.profile => FlowStep.overview,
        FlowStep.consent => FlowStep.profile,
        FlowStep.setup => FlowStep.consent,
        FlowStep.tourHistory => FlowStep.shell,
        FlowStep.pastResult => FlowStep.shell,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final strings = Strings(session.language);
    return LocaleScope(
      strings: strings,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: strings(T.appName),
        theme: sanketTheme(session.language),
        home: TourScope(
          enabled: isTour,
          target: switch (step) {
            FlowStep.overview => strings.isBangla
                ? 'শিশুর তথ্য দিন'
                : 'Continue to child information',
            FlowStep.profile => strings(T.continueLabel),
            FlowStep.consent => strings(T.consentAgree),
            FlowStep.setup => strings(T.setupBegin),
            FlowStep.result => strings(T.resultHistory),
            FlowStep.tourHistory => strings(T.historyNewSession),
            _ => null,
          },
          child: Builder(
            builder: (context) {
              if (step == FlowStep.splash) return const SplashScreen();
              if (step == FlowStep.onboarding) {
                return OnboardingScreen(
                  onDone: _finishOnboarding,
                  onLanguageChanged: _setLanguage,
                );
              }

              if (step == FlowStep.shell) {
                return AppShell(
                  session: session,
                  index: shellIndex,
                  onIndexChanged: (value) => setState(() => shellIndex = value),
                  onStart: _startSessionFlow,
                  onStartTour: _startTourFlow,
                  onOpenRecord: (record) {
                    pastRecord = record;
                    go(FlowStep.pastResult);
                  },
                  onSaveProfile: _saveProfile,
                  onLanguageChanged: _setLanguage,
                  onReplayOnboarding: () => go(FlowStep.onboarding),
                );
              }
              if (step == FlowStep.session) {
                return SessionStage(
                  session: activeSession,
                  isTour: isTour,
                  onExitTour: () => go(FlowStep.shell),
                  onFinished: () => go(FlowStep.result),
                );
              }
              final back = _backTarget;
              return PopScope(
                canPop: false,
                onPopInvoked: (didPop) {
                  if (!didPop && back != null) go(back);
                },
                child: Scaffold(
                  appBar: AppBar(
                    backgroundColor: SanketColors.ground,
                    scrolledUnderElevation: 0,
                    leading: back == null
                        ? null
                        : IconButton(
                            tooltip: strings(T.back),
                            onPressed: () => go(back),
                            icon: const Icon(Icons.arrow_back_ios_new_rounded),
                          ),
                    automaticallyImplyLeading: false,
                    title: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SanketLogo(size: 31),
                        SizedBox(width: 8),
                        Text('Sanket',
                            style: TextStyle(fontWeight: FontWeight.w900)),
                      ],
                    ),
                  ),
                  body: SafeArea(
                    child: isTour
                        ? Column(children: [
                            Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(children: [
                                  Expanded(
                                      child: Text(strings(T.tourActualPrivacy),
                                          style:
                                              const TextStyle(fontSize: 12))),
                                  TextButton(
                                      key: const ValueKey('tour-exit'),
                                      onPressed: () => go(FlowStep.shell),
                                      child: Text(strings(T.tourExit))),
                                ])),
                            Expanded(child: _flowScreen()),
                          ])
                        : _flowScreen(),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _flowScreen() => switch (step) {
        FlowStep.overview => SessionOverviewScreen(
            onContinue: () => go(FlowStep.profile),
          ),
        FlowStep.profile => ProfileScreen(
            session: activeSession,
            onSaved: isTour
                ? (profile) async {
                    activeSession.setProfile(profile);
                  }
                : _saveProfile,
            onContinue: () => go(FlowStep.consent),
          ),
        FlowStep.consent => ConsentScreen(
            session: activeSession,
            onAgree: () => go(FlowStep.setup),
          ),
        FlowStep.setup => SetupScreen(
            session: activeSession,
            isTour: isTour,
            onBegin: () {
              activeSession.beginSession();
              go(FlowStep.session);
            },
          ),
        FlowStep.result => ResultScreen(
            record: activeSession.record!,
            saving: activeSession.saving,
            saved: activeSession.saved,
            onHistory: () {
              if (isTour) {
                go(FlowStep.tourHistory);
              } else {
                shellIndex = 1;
                go(FlowStep.shell);
              }
            },
            onHome: () {
              shellIndex = 0;
              go(FlowStep.shell);
            },
          ),
        FlowStep.pastResult => ResultScreen(
            record: pastRecord!,
            saving: false,
            saved: true,
            onHistory: () {
              if (isTour) {
                go(FlowStep.tourHistory);
              } else {
                shellIndex = 1;
                go(FlowStep.shell);
              }
            },
            onHome: () {
              shellIndex = 0;
              go(FlowStep.shell);
            },
          ),
        FlowStep.splash ||
        FlowStep.onboarding ||
        FlowStep.shell ||
        FlowStep.session =>
          const SizedBox.shrink(),
        FlowStep.tourHistory => HistoryScreen(
            session: activeSession,
            onNewSession: () => go(FlowStep.shell),
            onOpen: (record) {
              pastRecord = record;
              go(FlowStep.pastResult);
            },
          ),
      };
}
