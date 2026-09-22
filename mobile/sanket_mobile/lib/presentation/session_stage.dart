import 'dart:async';
import '../tour/tour_scope.dart';
import '../tour/tour_timing.dart';
import '../tour/tour_activity_completion.dart';
import '../tour/tour_calibration_controller.dart';
import 'package:flutter/material.dart';

import '../activities/bubble_trail/bubble_trail_controller.dart';
import '../activities/bubble_trail/bubble_trail_view.dart';
import '../activities/copy_me/copy_me_controller.dart';
import '../activities/copy_me/copy_me_view.dart';
import '../activities/follow_my_look/follow_my_look_controller.dart';
import '../activities/follow_my_look/follow_my_look_view.dart';
import '../activities/name_response/name_response_controller.dart';
import '../activities/name_response/name_response_view.dart';
import '../activities/social_story/social_story_controller.dart';
import '../activities/social_story/social_story_view.dart';
import '../activities/switch_it/switch_it_controller.dart';
import '../activities/switch_it/switch_it_view.dart';
import '../core/measurement.dart';
import '../core/session.dart';
import '../l10n/locale_scope.dart';
import '../l10n/strings.dart';
import '../runtime/activity_controller.dart';
import '../runtime/calibration_controller.dart';
import '../runtime/session_controller.dart';
import 'calibration_view.dart';
import 'theme.dart';
import 'widgets/board.dart';

/// Reasons a second attempt of the same activity cannot overcome.
const notFixedByRetry = {
  ReasonCode.cameraUnavailable,
  ReasonCode.cameraPermissionDenied,
  ReasonCode.lowFrameRate,
  ReasonCode.gazeNotCalibrated,
  ReasonCode.gazeCalibrationUnusable,
  ReasonCode.calibrationTooFewSamples,
  ReasonCode.calibrationTargetsNotSeparable,
  ReasonCode.calibrationUnstable,
};

/// Landscape activity stage: calibration, then each planned activity with a
/// caregiver panel on the left and the child's board on the right.
class SessionStage extends StatefulWidget {
  const SessionStage(
      {super.key,
      required this.session,
      required this.onFinished,
      this.isTour = false,
      this.onExitTour});
  final SessionController session;
  final VoidCallback onFinished;
  final bool isTour;
  final VoidCallback? onExitTour;

  @override
  State<SessionStage> createState() => _SessionStageState();
}

class _SessionStageState extends State<SessionStage>
    with WidgetsBindingObserver {
  SessionController get session => widget.session;
  late final CalibrationController calibration = widget.isTour
      ? TourCalibrationController(session.sensors)
      : CalibrationController(session.sensors);
  Timer? _demoCompletion;
  bool calibrationDone = false;
  ActivityController? activity;
  bool pausedNote = false;
  bool _recorded = false;
  bool _ending = false;

  String get name => session.childName;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session.addListener(_onSession);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !calibrationDone) _showCalibrationGuide();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.removeListener(_onSession);
    _demoCompletion?.cancel();
    activity?.dispose();
    calibration.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      if (activity?.phase == ActivityPhase.running) _pause();
      if (calibration.phase == CalibrationPhase.running ||
          calibration.phase == CalibrationPhase.waitingForFace) {
        calibration.cancel();
      }
    }
  }

  void _onSession() {
    if (session.timeLimitReached && !_ending) _end(SessionStatus.timeLimit);
  }

  void _startActivity() {
    final id = session.currentActivity;
    if (id == null) return;
    _demoCompletion?.cancel();
    activity?.dispose();
    _recorded = false;
    pausedNote = false;
    final a = session.createController(id);
    a.addListener(() {
      if (a.phase == ActivityPhase.done &&
          !_recorded &&
          a.result != null &&
          mounted) {
        _recorded = true;
        session.completeActivity(a.result!);
        setState(() {});
      }
    });
    setState(() => activity = a);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && identical(activity, a) && a.phase == ActivityPhase.intro) {
        _showGuide(a);
      }
    });
  }

  void _continueAfterCalibration() {
    session.setCalibration(calibration.result);
    setState(() => calibrationDone = true);
    _startActivity();
  }

  void _next() {
    session.dismissBreak();
    session.advance();
    if (session.sessionFinished) {
      _finish();
    } else {
      _startActivity();
    }
  }

  void _retry() => _startActivity();

  void _simulateActivity() {
    final a = activity;
    if (a == null || a.phase != ActivityPhase.intro) return;
    a.start();
    _demoCompletion?.cancel();
    _demoCompletion = Timer(TourTiming.activityPreview, () {
      if (mounted &&
          identical(activity, a) &&
          a.phase == ActivityPhase.running) {
        completeTourActivity(a);
      }
    });
  }

  Future<void> _showGuide(ActivityController a) async {
    final s = context.s;
    await showDialog<void>(
      context: context,
      builder: (context) => TourScope(
          enabled: widget.isTour,
          target: s(T.stageGuideClose),
          child: AlertDialog(
            title: Text(s.activityName(a.id)),
            content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.parentInstruction(a.id, name)),
                  const SizedBox(height: 12),
                  Text(s(T.stageWeObserve, {'construct': s.construct(a.id)}),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ]),
            actions: [
              TourTarget(
                  label: s(T.stageGuideClose),
                  child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(s(T.stageGuideClose)))),
            ],
          )),
    );
  }

  Future<void> _showCalibrationGuide() async {
    final s = context.s;
    await showDialog<void>(
      context: context,
      builder: (context) => TourScope(
          enabled: widget.isTour,
          target: s(T.stageGuideClose),
          child: AlertDialog(
            title: Text(s(T.calTitle)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s(T.calParent, {'name': name})),
                  const SizedBox(height: 12),
                  Text(s(T.calWhy),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(s(T.calFramingHint, {'name': name})),
                ],
              ),
            ),
            actions: [
              TourTarget(
                  label: s(T.stageGuideClose),
                  child: FilledButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(s(T.stageGuideClose)))),
            ],
          )),
    );
  }

  void _skip() {
    activity?.cancelAttempt();
    session.skipCurrent();
    if (session.sessionFinished) {
      _finish();
    } else {
      _startActivity();
    }
  }

  void _pause() {
    activity?.cancelAttempt();
    setState(() => pausedNote = true);
  }

  Future<void> _confirmEnd() async {
    final s = context.s;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => TourScope(
          enabled: widget.isTour,
          target: s(T.stageGuideClose),
          child: AlertDialog(
            title: Text(s(T.stageStopTitle)),
            content: Text(s(T.stageStopBody)),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(s(T.stageKeepGoing))),
              FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: Text(s(T.stageStop))),
            ],
          )),
    );
    if (ok == true) await _end(SessionStatus.stoppedEarly);
  }

  Future<void> _end(SessionStatus status) async {
    if (_ending) return;
    _ending = true;
    final reason = status == SessionStatus.timeLimit
        ? ReasonCode.sessionTimeLimit
        : ReasonCode.stoppedEarly;
    final a = activity;
    if (a != null && a.phase == ActivityPhase.running) {
      // Keep whatever was measured before the stop; the analyzer decides validity.
      final o = a.finish(endedBy: reason);
      if (!_recorded) {
        _recorded = true;
        session.completeActivity(o);
      }
    }
    calibration.cancel();
    if (!calibrationDone && calibration.phase == CalibrationPhase.done) {
      session.setCalibration(calibration.result);
    }
    if (status == SessionStatus.timeLimit && mounted) {
      final s = context.s;
      await showDialog<void>(
        context: context,
        builder: (context) => TourScope(
            enabled: widget.isTour,
            target: s(T.stageGuideClose),
            child: AlertDialog(
              title: Text(s(T.timeLimitTitle)),
              content: Text(s(T.timeLimitBody)),
              actions: [
                FilledButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(s(T.stageSeeSummary)))
              ],
            )),
      );
    }
    await session.finalize(status);
    _finish();
  }

  bool _finished = false;
  void _finish() {
    if (_finished) return;
    _finished = true;
    widget.onFinished();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final target = !calibrationDone
        ? s(calibration.phase == CalibrationPhase.intro
            ? T.calStart
            : T.calContinueWithout)
        : s(activity?.phase == ActivityPhase.intro
            ? T.stageStartActivity
            : session.index >= session.plan.length - 1
                ? T.stageSeeSummary
                : T.stageNextActivity);
    return TourScope(
        enabled: widget.isTour,
        target: target,
        child: PopScope(
          canPop: false,
          onPopInvoked: (didPop) {
            if (!didPop) _confirmEnd();
          },
          child: Scaffold(
            backgroundColor: SanketColors.board,
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LayoutBuilder(builder: (context, constraints) {
                  final panelWidth =
                      (constraints.maxWidth * .32).clamp(250.0, 360.0);
                  return Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SizedBox(
                          width: panelWidth,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (widget.isTour)
                                  Row(children: [
                                    Expanded(
                                        child: Text(s(T.tourActivityAuto),
                                            style:
                                                const TextStyle(fontSize: 11))),
                                    TextButton(
                                        key: const ValueKey('tour-exit'),
                                        onPressed: widget.onExitTour,
                                        child: Text(s(T.tourExit))),
                                  ]),
                                Row(children: [
                                  Expanded(
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: calibrationDone &&
                                              session.currentActivity != null
                                          ? FittedBox(
                                              fit: BoxFit.scaleDown,
                                              child: StatusPill(
                                                  text: s(T.stageActivityOf, {
                                                    'n': session.index + 1,
                                                    'total': session.plan.length
                                                  }),
                                                  background: Colors.white),
                                            )
                                          : const SizedBox.shrink(),
                                    ),
                                  ),
                                  TextButton.icon(
                                    onPressed: _confirmEnd,
                                    style: TextButton.styleFrom(
                                        minimumSize: const Size(48, 48)),
                                    icon: const Icon(Icons.stop_circle_outlined,
                                        size: 20),
                                    label: Text(s(T.stageStop),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                            color: SanketColors.primary)),
                                  ),
                                ]),
                                Expanded(
                                  child: SingleChildScrollView(
                                    // A new scroll position for every step, so each panel starts at its title.
                                    key: ValueKey(
                                        '$calibrationDone-${calibration.phase}-${activity?.id}-${activity?.phase}'),
                                    padding: const EdgeInsets.only(
                                        right: 6, top: 6, bottom: 6),
                                    child: calibrationDone
                                        ? _activityPanelBody(context)
                                        : CalibrationBody(
                                            controller: calibration,
                                            name: name,
                                            onShowGuide: _showCalibrationGuide),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Pinned outside the scroll area so the primary action is
                                // always visible without scrolling.
                                calibrationDone
                                    ? _activityPanelActions(context)
                                    : CalibrationActions(
                                        controller: calibration,
                                        onContinue: _continueAfterCalibration),
                              ]),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                            child: calibrationDone
                                ? _board(context)
                                : CalibrationBoard(
                                    controller: calibration,
                                    preview: session.sensors.preview())),
                      ]);
                }),
              ),
            ),
          ),
        ));
  }

  Widget _activityPanelBody(BuildContext context) {
    final a = activity;
    if (a == null) return const SizedBox.shrink();
    final s = context.s;
    return AnimatedBuilder(
      animation: Listenable.merge([a, session]),
      builder: (context, _) {
        final title =
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text(s.activityName(a.id),
                style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: SanketColors.ink,
                    height: 1.1)),
          ),
          TextButton.icon(
            onPressed: () => _showGuide(a),
            icon: const Icon(Icons.help_outline, color: SanketColors.primary),
            label: Text(s(T.stageGuide)),
          ),
        ]);
        switch (a.phase) {
          case ActivityPhase.intro:
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 10),
                  Text(s.parentInstruction(a.id, name),
                      style: const TextStyle(
                          fontSize: 16, color: Color(0xff415b56))),
                  InfoCard(
                      margin: 12,
                      padding: 12,
                      child: Text(
                          s(T.stageWeObserve, {'construct': s.construct(a.id)}),
                          style: const TextStyle(fontWeight: FontWeight.w600))),
                  if (pausedNote)
                    IconNote(
                        icon: Icons.pause_circle_outline,
                        color: SanketColors.cream,
                        text: s(T.stagePausedBody)),
                  if (a is FollowMyLookController &&
                      !a.gazeAvailable &&
                      a.canRun)
                    IconNote(
                        icon: Icons.info_outline,
                        iconColor: SanketColors.warn,
                        color: SanketColors.warnSoft,
                        text: s(T.lookGazeUnavailable, {'name': name})),
                  if (!a.canRun)
                    IconNote(
                        icon: Icons.videocam_off_outlined,
                        iconColor: SanketColors.warn,
                        color: SanketColors.warnSoft,
                        text: s(T.needsCamera)),
                ]);
          case ActivityPhase.running:
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                        value: a.progress, minHeight: 8),
                  ),
                  const SizedBox(height: 12),
                  _livePanel(a),
                ]);
          case ActivityPhase.done:
            final o = a.result!;
            final valid = o.status == ActivityStatus.valid;
            final canRetry = !widget.isTour &&
                !valid &&
                a.canRun &&
                o.status != ActivityStatus.skipped &&
                !notFixedByRetry.contains(o.reason) &&
                session.canRetry(a.id);
            return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  title,
                  InfoCard(
                    margin: 12,
                    color: valid ? SanketColors.mint : SanketColors.cream,
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(valid ? Icons.check_circle : Icons.help_outline,
                              color: valid
                                  ? SanketColors.leaf
                                  : SanketColors.warn),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                      widget.isTour
                                          ? s(T.tourSimulatedResponse)
                                          : o.status ==
                                                  ActivityStatus
                                                      .nonParticipation
                                              ? s(T.doneNoParticipation,
                                                  {'name': name})
                                              : s(valid
                                                  ? T.doneMeasured
                                                  : T.doneNotEnough),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  if (o.trials.isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text(
                                        s(T.doneValidTrials, {
                                          'n': o.validTrials,
                                          'total': o.trials.length
                                        }),
                                        style: const TextStyle(
                                            color: SanketColors.muted)),
                                  ],
                                  if (!widget.isTour &&
                                      !valid &&
                                      o.reason != null &&
                                      o.status !=
                                          ActivityStatus.nonParticipation) ...[
                                    const SizedBox(height: 4),
                                    Text(s.reason(o.reason!, name)),
                                  ],
                                  if (canRetry) ...[
                                    const SizedBox(height: 4),
                                    Text(s(T.doneRetryOffer),
                                        style: const TextStyle(
                                            color: SanketColors.muted)),
                                  ],
                                ]),
                          ),
                        ]),
                  ),
                  if (session.breakSuggested)
                    InfoCard(
                      color: SanketColors.warnSoft,
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(s(T.breakTitle, {'name': name}),
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800)),
                            const SizedBox(height: 4),
                            Text(s(T.breakBody, {'name': name})),
                          ]),
                    ),
                ]);
        }
      },
    );
  }

  Widget _activityPanelActions(BuildContext context) {
    final a = activity;
    if (a == null) return const SizedBox.shrink();
    final s = context.s;
    return AnimatedBuilder(
      animation: Listenable.merge([a, session]),
      builder: (context, _) {
        switch (a.phase) {
          case ActivityPhase.intro:
            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PrimaryButton(
                      label: a.canRun
                          ? s(pausedNote ? T.stageResume : T.stageStartActivity)
                          : s(T.continueLabel),
                      icon: Icons.play_arrow_rounded,
                      onPressed: widget.isTour ? _simulateActivity : a.start),
                  if (a.canRun && !widget.isTour)
                    PrimaryButton(
                        label: s(T.stageSkipActivity),
                        pale: true,
                        onPressed: _skip),
                ]);
          case ActivityPhase.running:
            if (widget.isTour) return Text(s(T.tourActivityAuto));
            return OutlinedButton.icon(
                onPressed: _pause,
                icon: const Icon(Icons.pause_circle_outline),
                label: Text(s(T.stagePause)));
          case ActivityPhase.done:
            final o = a.result!;
            final valid = o.status == ActivityStatus.valid;
            final isLast = session.index >= session.plan.length - 1;
            final canRetry = !widget.isTour &&
                !valid &&
                a.canRun &&
                o.status != ActivityStatus.skipped &&
                !notFixedByRetry.contains(o.reason) &&
                session.canRetry(a.id);
            return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (session.breakSuggested)
                    PrimaryButton(
                        label: s(T.stageStop),
                        onPressed: () => _end(SessionStatus.stoppedEarly)),
                  if (canRetry)
                    PrimaryButton(
                        label: s(T.tryAgain),
                        icon: Icons.refresh,
                        pale: true,
                        onPressed: _retry),
                  PrimaryButton(
                      label:
                          s(isLast ? T.stageSeeSummary : T.stageNextActivity),
                      icon: Icons.arrow_forward_rounded,
                      onPressed: _next),
                ]);
        }
      },
    );
  }

  Widget _livePanel(ActivityController a) => switch (a) {
        SocialStoryController c => SocialStoryPanel(controller: c, name: name),
        NameResponseController c =>
          NameResponsePanel(controller: c, name: name),
        FollowMyLookController c =>
          FollowMyLookPanel(controller: c, name: name),
        CopyMeController c => CopyMePanel(
            controller: c, name: name, preview: session.sensors.preview()),
        _ => const SizedBox.shrink(),
      };

  Widget _board(BuildContext context) {
    final a = activity;
    if (a == null) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: a,
      builder: (context, _) {
        if (a.phase == ActivityPhase.intro) {
          return ActivityBoard(
            colors: const [Color(0xfff0f7f1), Color(0xffdff1e6)],
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Mascot('curious', height: 150),
                const SizedBox(height: 10),
                StatusPill(text: context.s.activityName(a.id)),
              ]),
            ),
          );
        }
        if (a.phase == ActivityPhase.done) {
          return ActivityBoard(
            colors: const [Color(0xfff0f7f1), Color(0xffdff1e6)],
            child: Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Mascot('excited', height: 160),
                const SizedBox(height: 10),
                StatusPill(text: context.s(T.reward)),
              ]),
            ),
          );
        }
        return switch (a) {
          SocialStoryController c => SocialStoryBoard(controller: c),
          NameResponseController c =>
            NameResponseBoard(controller: c, name: name),
          FollowMyLookController c => FollowMyLookBoard(controller: c),
          BubbleTrailController c =>
            BubbleTrailBoard(controller: c, name: name),
          CopyMeController c => CopyMeBoard(controller: c),
          SwitchItController c => SwitchItBoard(controller: c),
          _ => const SizedBox.shrink(),
        };
      },
    );
  }
}
