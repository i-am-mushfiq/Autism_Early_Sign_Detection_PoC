import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../activities/bubble_trail/bubble_trail_controller.dart';
import '../activities/copy_me/copy_me_controller.dart';
import '../activities/follow_my_look/follow_my_look_controller.dart';
import '../activities/name_response/name_response_controller.dart';
import '../activities/social_story/social_story_controller.dart';
import '../activities/switch_it/switch_it_controller.dart';
import '../core/activity_capture.dart';
import '../core/activity_catalog.dart';
import '../core/calibration.dart';
import '../core/measurement.dart';
import '../core/prototype_parameters.dart';
import '../core/session.dart';
import '../core/session_repository.dart';
import '../l10n/locale_scope.dart';
import '../sensors/sensor_hub.dart';
import 'activity_controller.dart';

/// App-level state for one caregiver's journey: language, consent, profile,
/// sensors, the running session record, and saved history.
class SessionController extends ChangeNotifier {
  SessionController({
    required this.repository,
    required SensorHub Function() sensorFactory,
    required this.permissions,
    this.allowAutomaticActivityFinish = true,
    DateTime Function()? clock,
    math.Random? random,
  })  : _sensorFactory = sensorFactory,
        _now = clock ?? DateTime.now,
        random = random ?? math.Random() {
    sensors = _sensorFactory();
  }

  final SessionRepository repository;
  final PermissionGateway permissions;
  final bool allowAutomaticActivityFinish;
  final SensorHub Function() _sensorFactory;
  final DateTime Function() _now;
  final math.Random random;
  late SensorHub sensors;

  AppLanguage language = AppLanguage.en;
  ConsentChoices consents = const ConsentChoices();
  ChildProfile? profile;
  PermissionResult? permissionResult;
  List<SessionRecord> history = [];

  SessionRecord? record;
  List<ActivityId> plan = [];
  int index = 0;
  final Map<ActivityId, int> _attempts = {};
  int _disengagedInRow = 0;
  bool breakSuggested = false;
  bool timeLimitReached = false;
  Timer? _timeLimit;
  Future<void>? _finalizing;
  bool saving = false;
  bool saved = false;

  String get childName => profile?.nickname ?? '';
  ActivityId? get currentActivity =>
      record == null || index >= plan.length ? null : plan[index];
  bool get sessionFinished => record?.finished ?? false;

  Future<void> init() async {
    await repository.recoverInterrupted(_now());
    history = await repository.loadAll();
    notifyListeners();
  }

  void setLanguage(AppLanguage l) {
    language = l;
    notifyListeners();
  }

  void setConsents(ConsentChoices c) {
    consents = c;
    notifyListeners();
  }

  void setProfile(ChildProfile p) {
    profile = p;
    notifyListeners();
  }

  // ── Permissions & sensors ────────────────────────────────────────────
  Future<void> refreshPermissions() async {
    permissionResult = await permissions.current();
    notifyListeners();
  }

  Future<SensorAvailability> requestAndStartSensors() async {
    permissionResult = await permissions.request();
    return startSensors();
  }

  Future<SensorAvailability> startSensors() async {
    final p = permissionResult ?? await permissions.current();
    permissionResult = p;
    final a = await sensors.start(
        camera: p.camera == PermissionState.granted,
        microphone: p.microphone == PermissionState.granted);
    notifyListeners();
    return a;
  }

  SensorAvailability get availability {
    final a = sensors.availability;
    final p = permissionResult;
    return SensorAvailability(
      camera: a.camera,
      microphone: a.microphone,
      cameraDenied: p != null && p.camera != PermissionState.granted,
      microphoneDenied: p != null && p.microphone != PermissionState.granted,
    );
  }

  /// Stops the camera and microphone and prepares a fresh hub for next time.
  Future<void> releaseSensors() async {
    final old = sensors;
    sensors = _sensorFactory();
    await old.dispose();
  }

  // ── Session lifecycle ────────────────────────────────────────────────
  void beginSession() {
    final p = profile!;
    final started = _now();
    record = SessionRecord(
      id: '${started.microsecondsSinceEpoch}-${random.nextInt(1 << 32)}',
      startedAt: started,
      profile: p,
      consents: consents,
      sensors: availability,
      appLanguage: language.name,
    );
    plan = [
      for (final d in activityCatalog)
        if (d.offeredFor(p.ageMonths)) d.id
    ];
    for (final d in activityCatalog.where((d) => !d.offeredFor(p.ageMonths))) {
      record!.putObservation(
          ActivityObservation.skipped(d.id, ReasonCode.notOfferedForAge));
    }
    index = 0;
    _attempts.clear();
    _disengagedInRow = 0;
    breakSuggested = false;
    timeLimitReached = false;
    _finalizing = null;
    saving = false;
    saved = false;
    _timeLimit?.cancel();
    _timeLimit = Timer(const Duration(milliseconds: P.maxActivityStageMs), () {
      timeLimitReached = true;
      notifyListeners();
    });
    _saveDraft();
    notifyListeners();
  }

  void setCalibration(CalibrationResult result) {
    record?.calibration = result;
    _saveDraft();
    notifyListeners();
  }

  int attemptsOf(ActivityId id) => _attempts[id] ?? 0;

  bool canRetry(ActivityId id) =>
      !timeLimitReached && attemptsOf(id) <= P.maxRetriesPerActivity;

  ActivityController createController(ActivityId id) {
    final attempt = attemptsOf(id) + 1;
    _attempts[id] = attempt;
    final ctx = ActivityContext(
      sensors: sensors,
      calibration: record?.calibration ?? CalibrationResult.notRun,
      profile: profile!,
      attempt: attempt,
      allowAutomaticFinish: allowAutomaticActivityFinish,
      random: random,
    );
    return switch (id) {
      ActivityId.socialStory => SocialStoryController(ctx),
      ActivityId.nameResponse => NameResponseController(ctx),
      ActivityId.followMyLook => FollowMyLookController(ctx),
      ActivityId.bubbleTrail => BubbleTrailController(ctx),
      ActivityId.copyMe => CopyMeController(ctx),
      ActivityId.switchIt => SwitchItController(ctx),
    };
  }

  /// Records an activity attempt. A retry replaces the earlier attempt.
  void completeActivity(ActivityObservation o) {
    final r = record;
    if (r == null || r.finished) return;
    r.putObservation(o);
    if (o.status == ActivityStatus.nonParticipation) {
      _disengagedInRow++;
    } else if (o.status == ActivityStatus.valid ||
        o.status == ActivityStatus.insufficient) {
      _disengagedInRow = 0;
    }
    breakSuggested = _disengagedInRow >= P.disengagedActivitiesBeforeBreak;
    _saveDraft();
    notifyListeners();
  }

  /// The caregiver chose to keep going after a break suggestion.
  void dismissBreak() {
    if (!breakSuggested) return;
    breakSuggested = false;
    _disengagedInRow = 0;
    notifyListeners();
  }

  void skipCurrent() {
    final id = currentActivity;
    if (id == null) return;
    completeActivity(
        ActivityObservation.skipped(id, ReasonCode.skippedByCaregiver)
            .copyWith(attempt: attemptsOf(id)));
    advance();
  }

  /// Moves to the next activity, or completes the session after the last one.
  void advance() {
    if (record == null || record!.finished) return;
    index++;
    if (index >= plan.length) {
      finalize(SessionStatus.completed);
    }
    notifyListeners();
  }

  /// Ends the session exactly once. Repeated calls (double taps, the time
  /// limit firing during a stop) return the same future and save once.
  Future<void> finalize(SessionStatus status) =>
      _finalizing ??= _finalize(status);

  Future<void> _finalize(SessionStatus status) async {
    final r = record!;
    _timeLimit?.cancel();
    final missingReason = status == SessionStatus.timeLimit
        ? ReasonCode.sessionTimeLimit
        : ReasonCode.stoppedEarly;
    for (final id in plan) {
      if (!r.observations.any((o) => o.activity == id)) {
        r.putObservation(ActivityObservation.skipped(id, missingReason));
      }
    }
    r.finish(status, _now());
    index = plan.length;
    notifyListeners();
    if (r.consents.storeOnDevice) {
      saving = true;
      notifyListeners();
      await repository.save(r);
      history = await repository.loadAll();
      saving = false;
      saved = true;
    }
    notifyListeners();
  }

  void _saveDraft() {
    final r = record;
    if (r == null || r.finished || !r.consents.storeOnDevice) return;
    unawaited(repository.save(r));
  }

  Future<void> deleteAllHistory() async {
    await repository.deleteAll();
    history = await repository.loadAll();
    notifyListeners();
  }

  /// Clears the finished session so a new one can begin (profile is kept).
  void resetForNewSession() {
    record = null;
    plan = [];
    index = 0;
    _finalizing = null;
    saved = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _timeLimit?.cancel();
    unawaited(sensors.dispose());
    super.dispose();
  }
}
