import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/session.dart';
import 'core/session_repository.dart';
import 'l10n/locale_scope.dart';
import 'l10n/strings.dart';
import 'presentation/screens/consent_screen.dart';
import 'presentation/screens/history_screen.dart';
import 'presentation/screens/profile_screen.dart';
import 'presentation/screens/result_screen.dart';
import 'presentation/screens/setup_screen.dart';
import 'presentation/screens/welcome_screen.dart';
import 'presentation/session_stage.dart';
import 'presentation/theme.dart';
import 'runtime/session_controller.dart';
import 'sensors/device_sensor_hub.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(SanketApp(
    session: SessionController(
      repository: SessionRepository(SharedPreferencesStore()),
      sensorFactory: DeviceSensorHub.new,
      permissions: DevicePermissionGateway(),
    ),
  ));
}

class SharedPreferencesStore implements KeyValueStore {
  @override
  Future<String?> read(String key) async => (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> write(String key, String value) async =>
      (await SharedPreferences.getInstance()).setString(key, value);
  @override
  Future<void> remove(String key) async => (await SharedPreferences.getInstance()).remove(key);
}

enum FlowStep { welcome, consent, profile, setup, session, result, history, pastResult }

class SanketApp extends StatefulWidget {
  const SanketApp({super.key, required this.session});
  final SessionController session;

  @override
  State<SanketApp> createState() => _SanketAppState();
}

class _SanketAppState extends State<SanketApp> {
  SessionController get session => widget.session;
  FlowStep step = FlowStep.welcome;
  SessionRecord? pastRecord;

  @override
  void initState() {
    super.initState();
    session.addListener(_changed);
    session.init();
  }

  @override
  void dispose() {
    session.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  Future<void> go(FlowStep next) async {
    final landscape = next == FlowStep.session;
    await Future.wait([
      SystemChrome.setPreferredOrientations(landscape
          ? const [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : const [DeviceOrientation.portraitUp]),
      SystemChrome.setEnabledSystemUIMode(landscape ? SystemUiMode.immersiveSticky : SystemUiMode.edgeToEdge),
    ]);
    if ((step == FlowStep.session || step == FlowStep.setup) && next != FlowStep.session) {
      // Camera and microphone never run outside setup and an active session.
      await session.releaseSensors();
    }
    if (mounted) setState(() => step = next);
  }

  FlowStep? get _backTarget => switch (step) {
        FlowStep.consent => FlowStep.welcome,
        FlowStep.profile => FlowStep.consent,
        FlowStep.setup => FlowStep.profile,
        FlowStep.history => FlowStep.welcome,
        FlowStep.pastResult => FlowStep.history,
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
        home: Builder(builder: (context) {
          if (step == FlowStep.session) {
            return SessionStage(session: session, onFinished: () => go(FlowStep.result));
          }
          final back = _backTarget;
          return PopScope(
            canPop: step == FlowStep.welcome,
            onPopInvoked: (didPop) {
              if (!didPop && back != null) go(back);
            },
            child: Scaffold(
              appBar: step == FlowStep.welcome
                  ? null
                  : AppBar(
                      backgroundColor: SanketColors.ground,
                      scrolledUnderElevation: 0,
                      leading: back == null
                          ? null
                          : IconButton(
                              tooltip: strings(T.back),
                              onPressed: () => go(back),
                              icon: const Icon(Icons.arrow_back_ios_new)),
                      automaticallyImplyLeading: false,
                      title: Text('⌁  ${strings(T.appName)}', style: const TextStyle(fontWeight: FontWeight.w800)),
                    ),
              body: SafeArea(child: _screen()),
            ),
          );
        }),
      ),
    );
  }

  Widget _screen() => switch (step) {
        FlowStep.welcome => WelcomeScreen(
            session: session,
            onStart: () => go(FlowStep.consent),
            onHistory: () => go(FlowStep.history),
          ),
        FlowStep.consent => ConsentScreen(session: session, onAgree: () => go(FlowStep.profile)),
        FlowStep.profile => ProfileScreen(session: session, onContinue: () => go(FlowStep.setup)),
        FlowStep.setup => SetupScreen(
            session: session,
            onBegin: () {
              session.beginSession();
              go(FlowStep.session);
            },
          ),
        FlowStep.result => ResultScreen(
            record: session.record!,
            saving: session.saving,
            saved: session.saved,
            // Leave the result screen first; the finished record is cleared after.
            onHistory: () => go(FlowStep.history).then((_) => session.resetForNewSession()),
            onHome: () => go(FlowStep.welcome).then((_) => session.resetForNewSession()),
          ),
        FlowStep.history => HistoryScreen(
            session: session,
            onNewSession: () => go(FlowStep.consent),
            onOpen: (r) {
              pastRecord = r;
              go(FlowStep.pastResult);
            },
          ),
        FlowStep.pastResult => ResultScreen(
            record: pastRecord!,
            saving: false,
            saved: true,
            onHistory: () => go(FlowStep.history),
            onHome: () => go(FlowStep.welcome),
          ),
        FlowStep.session => const SizedBox.shrink(),
      };
}
