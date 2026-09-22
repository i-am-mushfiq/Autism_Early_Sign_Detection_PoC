import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanket_mobile/core/app_preferences.dart';
import 'package:sanket_mobile/core/session_repository.dart';
import 'package:sanket_mobile/l10n/strings.dart';
import 'package:sanket_mobile/main.dart';
import 'package:sanket_mobile/runtime/session_controller.dart';

import 'support/fakes.dart';

class Harness {
  Harness(WidgetTester tester, {bool camera = true}) {
    final start = tester.binding.clock.now();
    hub = FakeSensorHub(
        clock: ManualClock(
            () => tester.binding.clock.now().difference(start).inMilliseconds),
        cameraAvailable: camera);
    session = SessionController(
        repository: SessionRepository(store),
        sensorFactory: () => hub,
        permissions: permissions);
  }
  final store = MemoryStore();
  final permissions = FakePermissions();
  late final FakeSensorHub hub;
  late final SessionController session;
}

Future<void> portrait(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1080, 2340);
  tester.view.devicePixelRatio = 2.75;
}

Future<void> landscape(WidgetTester tester) async {
  tester.view.physicalSize = const Size(2340, 1080);
  tester.view.devicePixelRatio = 2.75;
}

Future<void> tapText(WidgetTester tester, String text) async {
  final f = find.text(text).last;
  await tester.ensureVisible(f);
  await tester.pump();
  await tester.tap(f);
  await settle(tester);
}

/// Lets platform-channel futures (orientation changes, storage) complete.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 3; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await tester
        .runAsync(() => Future<void>.delayed(const Duration(milliseconds: 10)));
  }
  await tester.pump();
}

/// Advances time; like a real camera with nobody in view, the hub keeps
/// delivering frames without a face.
Future<void> wait(WidgetTester tester, Duration d, [FakeSensorHub? hub]) async {
  final steps = d.inMilliseconds ~/ 100;
  for (var i = 0; i < steps; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (hub != null && hub.cameraAvailable)
      hub.emitFrame(noFace(hub.clock.nowMs()));
  }
}

Future<void> fillProfile(WidgetTester tester,
    {required String name, required String age}) async {
  await tester.enterText(find.byType(TextFormField).at(0), name);
  await tester.enterText(find.byType(TextFormField).at(1), age);
  await tester.pump();
}

void main() {
  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
        .resetPhysicalSize();
  });

  testWidgets(
      'tour uses actual screens and buttons without child input or sensors',
      (tester) async {
    await portrait(tester);
    final h = Harness(tester);
    await tester.pumpWidget(SanketApp(session: h.session));
    await settle(tester);
    for (var replay = 0; replay < 2; replay++) {
      await tapText(tester, 'Full demo tour');
      expect(find.text('What happens in a session'), findsOneWidget);
      expect(find.byKey(const ValueKey('tour-next')), findsNothing);
      expect(find.byKey(const ValueKey('tour-highlight')), findsOneWidget);
      await tapText(tester, 'Continue to child information');
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          'Adiba');
      await tapText(tester, T.continueLabel.en);
      expect(find.text(T.consentTitle.en), findsOneWidget);
      await tapText(tester, T.consentAgree.en);
      expect(find.text(T.setupTitle.en), findsOneWidget);
      expect(find.text(T.setupAllow.en), findsNothing);
      await tapText(tester, T.setupBegin.en);
      await landscape(tester);
      await settle(tester);
      await tapText(tester, T.stageGuideClose.en);
      await tapText(tester, T.calStart.en);
      await tapText(tester, T.calContinueWithout.en);
      for (var index = 0; index < 6; index++) {
        await tapText(tester, T.stageGuideClose.en);
        expect(find.byKey(const ValueKey('tour-highlight')), findsOneWidget);
        await tapText(tester, T.stageStartActivity.en);
        // No name call, movement or board taps. Only the tour completion timer.
        await wait(tester, const Duration(seconds: 6));
        expect(find.text(T.tourSimulatedResponse.en), findsNothing,
            reason: 'No activity timeout may end the tour preview early');
        await wait(tester, const Duration(seconds: 3));
        await tapText(
            tester, index == 5 ? T.stageSeeSummary.en : T.stageNextActivity.en);
      }
      await portrait(tester);
      await settle(tester);
      expect(find.text(T.stateInconclusiveTitle.en), findsWidgets);
      await tapText(tester, T.resultHistory.en);
      expect(find.text(T.historyTitle.en), findsOneWidget);
      expect(find.text('Adiba · 30 months'), findsOneWidget);
      await tapText(tester, T.historyNewSession.en);
      expect(find.text('Take a guided session'), findsOneWidget);
      expect(h.hub.started, isFalse);
      expect(h.permissions.requested, isFalse);
      expect(h.session.profile, isNull);
      expect(h.session.record, isNull);
      expect(h.session.history, isEmpty);
      expect(h.store.values, isEmpty);
    }
    await tapText(tester, 'Full demo tour');
    await tester.tap(find.byKey(const ValueKey('tour-exit')));
    await settle(tester);
    expect(find.text('Take a guided session'), findsOneWidget);
  });
  testWidgets(
      'complete journey: overview → profile → consent → setup → activities → result → history',
      (tester) async {
    await portrait(tester);
    final h = Harness(tester);
    await tester.pumpWidget(SanketApp(session: h.session));
    await settle(tester);

    expect(find.text('Take a guided session'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('History'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);
    await tapText(tester, 'View session details');
    expect(find.text('What happens in a session'), findsOneWidget);
    expect(find.text(T.nameName.en), findsOneWidget);
    await tapText(tester, 'Continue to child information');

    // Profile validation.
    await tapText(tester, T.continueLabel.en);
    expect(find.text(T.profileNameMissing.en), findsOneWidget);
    await fillProfile(tester, name: 'Tuktuki', age: '40');
    await tapText(tester, T.continueLabel.en);
    expect(find.text(T.profileAgeInvalid.en), findsOneWidget);
    await fillProfile(tester, name: 'Tuktuki', age: '22');
    expect(find.text(T.profileUnder24Note.en), findsOneWidget);
    await tapText(tester, T.profileHearing.en); // scroll target only
    await tapText(tester, T.continueLabel.en);

    // Consent: required choice gates the button; optional choices are separate.
    expect(find.text(T.consentNeedProcessing.en), findsOneWidget);
    final agree = find.widgetWithText(FilledButton, T.consentAgree.en);
    await tester.ensureVisible(agree);
    expect(tester.widget<FilledButton>(agree).onPressed, isNull);
    await tapText(tester, T.consentProcessingTitle.en);
    await tapText(tester, T.consentStoreTitle.en);
    expect(h.session.consents.processing, isTrue);
    expect(h.session.consents.storeOnDevice, isTrue);
    expect(h.session.consents.research, isFalse);
    await tapText(tester, T.consentAgree.en);

    // Setup: permission request, live checks.
    expect(find.textContaining('Tuktuki'), findsWidgets);
    await tapText(tester, T.setupAllow.en);
    await tester.pump();
    expect(h.permissions.requested, isTrue);
    expect(find.text(T.checkLighting.en), findsOneWidget);
    await tapText(tester, T.setupBegin.en);
    await landscape(tester);
    await settle(tester);

    // Calibration with nobody in view must NOT pass.
    expect(find.text(T.calTitle.en), findsWidgets);
    expect(find.text(T.stageGuideClose.en), findsOneWidget);
    await tapText(tester, T.stageGuideClose.en);
    expect(find.text(T.stageGuide.en), findsOneWidget);
    await tapText(tester, T.calStart.en);
    await wait(tester, const Duration(seconds: 20), h.hub);
    expect(find.text(T.calUnusable.en), findsOneWidget);
    expect(find.text(T.calContinueWithout.en), findsOneWidget);
    await tapText(tester, T.calContinueWithout.en);

    // Five activities for 22 months; the entered name is used.
    expect(find.text(T.storyName.en), findsWidgets);
    expect(find.text(T.stageGuideClose.en), findsOneWidget);
    await tapText(tester, T.stageGuideClose.en);
    expect(find.text('Activity 1 of 5'), findsOneWidget);
    expect(find.text(T.stageGuide.en), findsOneWidget);
    expect(find.textContaining('Tuktuki'), findsWidgets);
    await tapText(tester, T.stageSkipActivity.en); // Social Story
    await tapText(tester, T.stageGuideClose.en);
    expect(find.text(T.nameName.en), findsWidgets);
    expect(find.text(T.nameParent.en.replaceAll('{name}', 'Tuktuki')),
        findsOneWidget);

    // Name Response: start and let attention time out (nobody in view).
    await tapText(tester, T.stageStartActivity.en);
    await wait(tester, const Duration(seconds: 36), h.hub);
    expect(find.text(T.doneNoParticipation.en.replaceAll('{name}', 'Tuktuki')),
        findsOneWidget);
    await tapText(tester, T.stageNextActivity.en);

    await tapText(tester, T.stageGuideClose.en);
    await tapText(tester, T.stageSkipActivity.en); // Follow My Look
    // Bubble Trail: runs without a camera requirement; no taps → ends early.
    await tapText(tester, T.stageGuideClose.en);
    await tapText(tester, T.stageStartActivity.en);
    await wait(tester, const Duration(seconds: 11), h.hub);
    expect(find.text(T.bubbleInactive.en.replaceAll('{name}', 'Tuktuki')),
        findsOneWidget);
    await wait(tester, const Duration(seconds: 13), h.hub);
    // Two disengaged activities in a row → break suggestion.
    expect(find.text(T.breakTitle.en.replaceAll('{name}', 'Tuktuki')),
        findsOneWidget);
    await tapText(tester, T.stageNextActivity.en);
    await tapText(tester, T.stageGuideClose.en);
    await tapText(
        tester, T.stageSkipActivity.en); // Copy Me → last planned activity

    // Result.
    await settle(tester);
    await portrait(tester);
    await settle(tester);
    expect(find.text(T.stateInconclusiveTitle.en), findsWidgets);
    expect(
        find.text(T.stateInconclusiveBody.en.replaceAll('{name}', 'Tuktuki')),
        findsOneWidget);
    expect(find.text(T.aNotOffered.en), findsOneWidget);
    expect(find.text(T.resultSaved.en), findsOneWidget);
    expect(h.hub.disposed, isTrue,
        reason: 'camera and microphone stop after the session');

    await tapText(tester, T.resultHome.en);
    await wait(tester, const Duration(milliseconds: 300));
    expect(find.text('Your observations'), findsOneWidget);
    expect(find.text('Completed sessions'), findsOneWidget);
    expect(find.text('Latest summary'), findsOneWidget);
    await tapText(tester, 'History');
    expect(find.text(T.historyTrendEmpty.en), findsOneWidget);
    expect(find.text('Tuktuki · 22 months'), findsOneWidget);
    expect(h.session.history, hasLength(1));
  });

  testWidgets('Bangla experience end to end, including validation and result',
      (tester) async {
    await portrait(tester);
    final h = Harness(tester, camera: false);
    await tester.pumpWidget(SanketApp(session: h.session));
    await settle(tester);

    await tapText(tester, T.switchLanguage.en); // "বাংলা"
    expect(find.text('একটি নির্দেশিত সেশন নিন'), findsOneWidget);
    await tapText(tester, 'সেশন সম্পর্কে জানুন');
    expect(find.text('আজকের সেশনে যা থাকবে'), findsOneWidget);
    await tapText(tester, 'শিশুর তথ্য দিন');
    await tapText(tester, T.continueLabel.bn);
    expect(find.text(T.profileNameMissing.bn), findsOneWidget);
    await fillProfile(tester, name: 'টুকটুকি', age: '30');
    await tapText(tester, T.continueLabel.bn);
    expect(find.text(T.consentTitle.bn), findsOneWidget);
    await tapText(tester, T.consentProcessingTitle.bn);
    await tapText(tester, T.consentAgree.bn);
    await tapText(tester, T.setupAllow.bn);
    await tester.pump();
    await tapText(tester, T.setupBegin.bn);
    await landscape(tester);
    await settle(tester);

    // No camera: calibration reports it immediately; camera activities say so.
    await tapText(tester, T.stageGuideClose.bn);
    await tapText(tester, T.calStart.bn);
    expect(find.text(T.calUnusable.bn), findsOneWidget);
    await tapText(tester, T.calContinueWithout.bn);
    expect(find.text(T.stageGuideClose.bn), findsOneWidget);
    await tapText(tester, T.stageGuideClose.bn);
    expect(find.text('কার্যক্রম ১ / ৬'), findsOneWidget);
    expect(find.text(T.needsCamera.bn), findsOneWidget);

    // End the session early from the stage.
    await tapText(tester, T.stageStop.bn);
    await tapText(tester, T.stageStop.bn);
    await settle(tester);
    await portrait(tester);
    await settle(tester);
    expect(find.text(T.stateInconclusiveTitle.bn), findsWidgets);
    expect(find.text(T.resultNotSaved.bn), findsOneWidget);
    expect(find.text(T.resultBoundary.bn), findsOneWidget);
  });

  testWidgets(
      'history shows only real saved sessions and a trend only with two',
      (tester) async {
    await portrait(tester);
    final h = Harness(tester);
    await tester.pumpWidget(SanketApp(session: h.session));
    await settle(tester);
    await tapText(tester, 'History');
    expect(find.text(T.historyEmpty.en), findsOneWidget);
    expect(find.text(T.historyTrendEmpty.en), findsOneWidget);
    expect(find.text(T.historyDeleteAll.en), findsNothing);
  });

  testWidgets('onboarding appears once and persists completion',
      (tester) async {
    await portrait(tester);
    final preferenceStore = MemoryStore();
    final h = Harness(tester);
    await tester.pumpWidget(SanketApp(
      session: h.session,
      preferences: AppPreferences(preferenceStore),
    ));
    await settle(tester);

    expect(find.text('Notice small developmental changes'), findsOneWidget);
    await tapText(tester, 'Skip');
    // A brand-new user lands straight in the demo tour, not an empty shell.
    expect(find.text('What happens in a session'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await settle(tester);
    final next = Harness(tester);
    await tester.pumpWidget(SanketApp(
      session: next.session,
      preferences: AppPreferences(preferenceStore),
    ));
    await settle(tester);
    expect(find.text('Notice small developmental changes'), findsNothing);
    expect(find.text('Take a guided session'), findsOneWidget);
  });
}
