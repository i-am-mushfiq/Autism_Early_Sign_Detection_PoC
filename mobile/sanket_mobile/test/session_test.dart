import 'dart:convert';
import 'dart:math' as math;

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanket_mobile/core/activity_capture.dart';
import 'package:sanket_mobile/core/activity_catalog.dart';
import 'package:sanket_mobile/core/interpretation.dart';
import 'package:sanket_mobile/core/measurement.dart';
import 'package:sanket_mobile/core/prototype_parameters.dart';
import 'package:sanket_mobile/core/session.dart';
import 'package:sanket_mobile/core/session_repository.dart';
import 'package:sanket_mobile/runtime/activity_controller.dart';
import 'package:sanket_mobile/runtime/calibration_controller.dart';
import 'package:sanket_mobile/runtime/session_controller.dart';

import 'support/fakes.dart';
import 'support/sim_child.dart';

class SessionRun {
  SessionRun(this.controller, this.store, this.elapsedMs);
  final SessionController controller;
  final MemoryStore store;
  final int elapsedMs;
  SessionRecord get record => controller.record!;
  SessionOutcome get outcome => record.outcome!;
}

/// A full session — permissions, calibration, every planned activity — driven
/// by a simulated child through the real controllers and analyzers.
SessionRun runSession({
  ChildBehaviour behaviour = const ChildBehaviour(),
  ChildProfile profile = const ChildProfile(nickname: 'Rafi', ageMonths: 30),
  ConsentChoices consents = const ConsentChoices(processing: true, storeOnDevice: true),
  MemoryStore? store,
  int stopAfterActivities = 99,
}) {
  late SessionRun run;
  final memory = store ?? MemoryStore();
  fakeAsync((async) {
    final clock = ManualClock(() => async.elapsed.inMilliseconds);
    final hub = FakeSensorHub(clock: clock);
    final session = SessionController(
      repository: SessionRepository(memory),
      sensorFactory: () => hub,
      permissions: FakePermissions(),
      clock: () => DateTime(2026, 9, 13, 10).add(async.elapsed),
      random: math.Random(3),
    );
    session.init();
    async.flushMicrotasks();
    session.setConsents(consents);
    session.setProfile(profile);
    session.requestAndStartSensors();
    async.flushMicrotasks();
    session.beginSession();

    final sim = SimChild(hub, behaviour);
    final calibration = CalibrationController(hub)..start();
    drive(async, (t) => sim.stepCalibration(calibration, t), () => calibration.phase == CalibrationPhase.done);
    session.setCalibration(calibration.result);

    var completed = 0;
    while (session.currentActivity != null && !session.sessionFinished) {
      if (completed >= stopAfterActivities) {
        session.finalize(SessionStatus.stoppedEarly);
        break;
      }
      final a = session.createController(session.currentActivity!)..start();
      drive(async, (t) => sim.step(a, t), () => a.phase == ActivityPhase.done, maxMs: 180000);
      session.completeActivity(a.result!);
      a.dispose();
      completed++;
      session.advance();
    }
    async.flushMicrotasks();
    async.elapse(const Duration(seconds: 1));
    run = SessionRun(session, memory, async.elapsed.inMilliseconds);
    session.dispose();
  });
  return run;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Result states are reached through real session conditions', () {
    test('engaged child → No strong follow-up signal observed', () {
      final run = runSession();
      expect(run.outcome.state, ObservationState.noStrongSignal);
      expect(run.outcome.validActivities, 6);
      expect(run.record.status, SessionStatus.completed);
    });

    test('no orienting to name → Monitor', () {
      final run = runSession(behaviour: const ChildBehaviour(respondsToName: false));
      expect(run.outcome.state, ObservationState.monitor);
      expect(run.outcome.counted.single.note, PatternNote.nameNoOrienting);
    });

    test('emerging construct alone can raise to Monitor but no further', () {
      final run = runSession(behaviour: const ChildBehaviour(imitates: false));
      expect(run.outcome.state, ObservationState.monitor);
    });

    test('no orienting and no gaze following → Discuss with a professional', () {
      final run = runSession(behaviour: const ChildBehaviour(respondsToName: false, followsLook: false));
      expect(run.outcome.state, ObservationState.discussProfessional);
      expect(run.outcome.counted, hasLength(2));
    });

    test('child not present → Inconclusive, never a pattern', () {
      final run = runSession(behaviour: const ChildBehaviour(present: false, tapsBubbles: false, tapsSwitch: false));
      expect(run.outcome.state, ObservationState.inconclusive);
      expect(run.outcome.patterns, isEmpty);
    });

    test('too dark for the camera → Inconclusive (touch alone is not enough)', () {
      final run = runSession(behaviour: const ChildBehaviour(lighting: .04));
      expect(run.outcome.state, ObservationState.inconclusive);
      expect(run.outcome.inconclusiveReason, InconclusiveReason.tooFewEvidenceBackedActivities);
      expect(run.record.observations.firstWhere((o) => o.activity == ActivityId.bubbleTrail).valid, isTrue);
    });

    test('reported hearing concern: no-orienting pattern is not interpreted', () {
      final run = runSession(
        behaviour: const ChildBehaviour(respondsToName: false),
        profile: const ChildProfile(nickname: 'Rafi', ageMonths: 30, hearingConcern: true),
      );
      expect(run.outcome.state, ObservationState.noStrongSignal);
      expect(run.outcome.patterns.single.suppressedBy, ContextFactor.hearingConcern);
    });

    test('under 24 months: five activities, Switch It recorded as not offered', () {
      final run = runSession(profile: const ChildProfile(nickname: 'Mim', ageMonths: 20));
      expect(run.controller.plan, isNot(contains(ActivityId.switchIt)));
      expect(run.record.observations.firstWhere((o) => o.activity == ActivityId.switchIt).status,
          ActivityStatus.notOffered);
      expect(run.outcome.state, ObservationState.noStrongSignal);
    });

    test('a complete session fits the 6–8 minute design (activities stage)', () {
      final run = runSession();
      // Calibration + six activities, excluding caregiver reading time between them.
      expect(run.elapsedMs, lessThan(6 * 60 * 1000));
      expect(run.elapsedMs, greaterThan(3 * 60 * 1000));
    });
  });

  group('Interpretation rules', () {
    ActivityObservation obs(ActivityId id, {bool valid = true, List<PatternNote> notes = const []}) =>
        ActivityObservation(
            activity: id, status: valid ? ActivityStatus.valid : ActivityStatus.insufficient, notes: notes);
    const interpreter = SessionInterpreter();
    const ctx = ChildContext(ageMonths: 30);

    test('patterns from invalid activities are never counted', () {
      final o = interpreter.interpret([
        obs(ActivityId.socialStory),
        obs(ActivityId.followMyLook),
        obs(ActivityId.bubbleTrail),
        obs(ActivityId.nameResponse, valid: false, notes: [PatternNote.nameNoOrienting]),
      ], ctx);
      expect(o.state, ObservationState.noStrongSignal);
      expect(o.patterns, isEmpty);
    });

    test('too few valid activities → inconclusive even with patterns', () {
      final o = interpreter.interpret([
        obs(ActivityId.nameResponse, notes: [PatternNote.nameNoOrienting]),
        obs(ActivityId.followMyLook, notes: [PatternNote.lookNoFollow]),
      ], ctx);
      expect(o.state, ObservationState.inconclusive);
      expect(o.inconclusiveReason, InconclusiveReason.tooFewValidActivities);
    });

    test('descriptive activities never escalate', () {
      final o = interpreter.interpret([
        obs(ActivityId.socialStory),
        obs(ActivityId.nameResponse),
        obs(ActivityId.bubbleTrail),
        obs(ActivityId.switchIt),
      ], ctx);
      expect(o.state, ObservationState.noStrongSignal);
    });

    test('vision concern suppresses gaze-based patterns', () {
      final o = interpreter.interpret([
        obs(ActivityId.socialStory, notes: [PatternNote.storyNonSocialPreference]),
        obs(ActivityId.followMyLook, notes: [PatternNote.lookNoFollow]),
        obs(ActivityId.nameResponse),
      ], const ChildContext(ageMonths: 30, visionConcern: true));
      expect(o.state, ObservationState.noStrongSignal);
      expect(o.patterns.every((p) => p.suppressedBy == ContextFactor.visionConcern), isTrue);
    });

    test('outcome is reproducible from stored JSON', () {
      final run = runSession(behaviour: const ChildBehaviour(respondsToName: false, followsLook: false));
      final stored = jsonDecode(run.store.values[SessionRepository.key]!) as List;
      final record = SessionRecord.fromJson(Map<String, dynamic>.from(stored.single as Map));
      final recomputed = record.computeOutcome();
      expect(recomputed.state, run.outcome.state);
      expect(jsonEncode(recomputed.toJson()), jsonEncode(record.outcome!.toJson()));
      expect(record.outcome!.rulesVersion, PrototypeParameters.rulesVersion);
    });
  });

  group('Session integrity', () {
    test('activity can only complete from running state', () {
      final machine = ActivityStateMachine();
      expect(machine.transition(TrialPhase.completed), isFalse);
      expect(machine.transition(TrialPhase.ready), isTrue);
      expect(machine.transition(TrialPhase.running), isTrue);
      expect(machine.transition(TrialPhase.completed), isTrue);
      expect(machine.transition(TrialPhase.running), isFalse);
    });

    test('completed session is saved exactly once despite repeated finalize calls', () {
      fakeAsync((async) {
        final store = MemoryStore();
        final hub = FakeSensorHub(clock: ManualClock(() => async.elapsed.inMilliseconds));
        final s = SessionController(
            repository: SessionRepository(store), sensorFactory: () => hub, permissions: FakePermissions());
        s.setConsents(const ConsentChoices(processing: true, storeOnDevice: true));
        s.setProfile(const ChildProfile(nickname: 'Rafi', ageMonths: 30));
        s.beginSession();
        async.flushMicrotasks();
        final f1 = s.finalize(SessionStatus.stoppedEarly);
        final f2 = s.finalize(SessionStatus.completed);
        expect(identical(f1, f2), isTrue);
        s.finalize(SessionStatus.timeLimit);
        async.flushMicrotasks();
        final saved = jsonDecode(store.values[SessionRepository.key]!) as List;
        expect(saved, hasLength(1));
        expect((saved.single as Map)['status'], 'stoppedEarly');
        s.dispose();
      });
    });

    test('ending early keeps finished activities and marks the rest as not run', () {
      final run = runSession(stopAfterActivities: 2);
      expect(run.record.status, SessionStatus.stoppedEarly);
      expect(run.record.observations.where((o) => o.valid), hasLength(2));
      expect(run.record.observations.where((o) => o.reason == ReasonCode.stoppedEarly), hasLength(4));
      expect(run.outcome.state, ObservationState.inconclusive);
    });

    test('an app close mid-session is recovered as interrupted, not duplicated', () {
      fakeAsync((async) {
        final store = MemoryStore();
        final repo = SessionRepository(store);
        final hub = FakeSensorHub(clock: ManualClock(() => async.elapsed.inMilliseconds));
        final s = SessionController(repository: repo, sensorFactory: () => hub, permissions: FakePermissions());
        s.setConsents(const ConsentChoices(processing: true, storeOnDevice: true));
        s.setProfile(const ChildProfile(nickname: 'Rafi', ageMonths: 30));
        s.beginSession();
        s.completeActivity(const ActivityObservation(activity: ActivityId.socialStory, status: ActivityStatus.valid));
        async.flushMicrotasks();
        // "App killed": a new controller starts from the same storage.
        final next = SessionController(
            repository: SessionRepository(store), sensorFactory: () => hub, permissions: FakePermissions());
        next.init();
        async.flushMicrotasks();
        expect(next.history, hasLength(1));
        expect(next.history.single.status, SessionStatus.interrupted);
        expect(next.history.single.outcome!.state, ObservationState.inconclusive);
        next.init();
        async.flushMicrotasks();
        expect(next.history, hasLength(1));
      });
    });

    test('retrying an activity replaces its earlier attempt', () {
      final r = SessionRecord(
          id: 'x',
          startedAt: DateTime(2026),
          profile: const ChildProfile(nickname: 'R', ageMonths: 30),
          consents: const ConsentChoices(processing: true),
          sensors: SensorAvailability.all,
          appLanguage: 'en');
      r.putObservation(const ActivityObservation(activity: ActivityId.copyMe, status: ActivityStatus.insufficient));
      r.putObservation(
          const ActivityObservation(activity: ActivityId.copyMe, status: ActivityStatus.valid, attempt: 2));
      expect(r.observations, hasLength(1));
      expect(r.observations.single.attempt, 2);
    });

    test('retry allowance is limited and never forced', () {
      fakeAsync((async) {
        final hub = FakeSensorHub(clock: ManualClock(() => async.elapsed.inMilliseconds))..started = true;
        final s = SessionController(
            repository: SessionRepository(MemoryStore()), sensorFactory: () => hub, permissions: FakePermissions());
        s.setProfile(const ChildProfile(nickname: 'R', ageMonths: 30));
        s.setConsents(const ConsentChoices(processing: true));
        s.beginSession();
        s.createController(ActivityId.socialStory).dispose();
        expect(s.canRetry(ActivityId.socialStory), isTrue);
        s.createController(ActivityId.socialStory).dispose();
        expect(s.canRetry(ActivityId.socialStory), isFalse);
      });
    });

    test('without storage consent nothing is written', () {
      final run = runSession(consents: const ConsentChoices(processing: true));
      expect(run.store.values[SessionRepository.key], isNull);
      expect(run.controller.saved, isFalse);
      expect(run.outcome.state, ObservationState.noStrongSignal);
    });

    test('two disengaged activities in a row suggest a break', () {
      fakeAsync((async) {
        final hub = FakeSensorHub(clock: ManualClock(() => async.elapsed.inMilliseconds));
        final s = SessionController(
            repository: SessionRepository(MemoryStore()), sensorFactory: () => hub, permissions: FakePermissions());
        s.setProfile(const ChildProfile(nickname: 'R', ageMonths: 30));
        s.setConsents(const ConsentChoices(processing: true));
        s.beginSession();
        const off = ActivityObservation(activity: ActivityId.socialStory, status: ActivityStatus.nonParticipation);
        s.completeActivity(off);
        expect(s.breakSuggested, isFalse);
        s.completeActivity(const ActivityObservation(activity: ActivityId.nameResponse, status: ActivityStatus.nonParticipation));
        expect(s.breakSuggested, isTrue);
        s.dismissBreak();
        expect(s.breakSuggested, isFalse);
      });
    });

    test('maximum session duration is enforced', () {
      fakeAsync((async) {
        final hub = FakeSensorHub(clock: ManualClock(() => async.elapsed.inMilliseconds));
        final s = SessionController(
            repository: SessionRepository(MemoryStore()), sensorFactory: () => hub, permissions: FakePermissions());
        s.setProfile(const ChildProfile(nickname: 'R', ageMonths: 30));
        s.setConsents(const ConsentChoices(processing: true));
        s.beginSession();
        async.elapse(const Duration(milliseconds: P.maxActivityStageMs + 10));
        expect(s.timeLimitReached, isTrue);
        expect(s.canRetry(ActivityId.socialStory), isFalse);
      });
    });

    test('legacy demo history is removed and corrupt records are skipped', () async {
      final store = MemoryStore()
        ..values[SessionRepository.legacyKey] = 'x'
        ..values[SessionRepository.key] = '[{"id": "broken"}]';
      final repo = SessionRepository(store);
      expect(await repo.loadAll(), isEmpty);
      expect(store.values.containsKey(SessionRepository.legacyKey), isFalse);
    });

    test('history is newest first and delete-all clears it', () async {
      final store = MemoryStore();
      final repo = SessionRepository(store);
      for (final day in [3, 9, 5]) {
        final r = SessionRecord(
            id: 'd$day',
            startedAt: DateTime(2026, 9, day),
            profile: const ChildProfile(nickname: 'R', ageMonths: 30),
            consents: const ConsentChoices(processing: true, storeOnDevice: true),
            sensors: SensorAvailability.all,
            appLanguage: 'bn')
          ..finish(SessionStatus.completed, DateTime(2026, 9, day, 1));
        await repo.save(r);
        await repo.save(r); // double save → still one
      }
      final all = await repo.loadAll();
      expect(all.map((r) => r.id), ['d9', 'd5', 'd3']);
      await repo.deleteAll();
      expect(await repo.loadAll(), isEmpty);
    });
  });
}
