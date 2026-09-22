import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/measurement.dart';
import '../../core/quality.dart';
import '../../core/samples.dart';
import '../../l10n/locale_scope.dart';
import '../../l10n/strings.dart';
import '../../runtime/session_controller.dart';
import '../../sensors/sensor_hub.dart';
import '../theme.dart';

enum CheckState { good, checking, problem, unavailable }

class LiveCheck {
  const LiveCheck(this.state, this.label);
  final CheckState state;
  final T label;
}

/// Live environment readiness computed from the last two seconds of real
/// camera and microphone samples, using the same quality gates as analysis.
class EnvironmentReadiness {
  static const windowMs = 2000;

  static LiveCheck lighting(List<VisionFrame> recent) {
    final q = assessLighting(recent);
    if (q.status == QualityStatus.unavailable)
      return const LiveCheck(CheckState.checking, T.statusChecking);
    if (q.usable) return const LiveCheck(CheckState.good, T.statusGood);
    return LiveCheck(CheckState.problem,
        q.reason == ReasonCode.tooBright ? T.statusTooBright : T.statusTooDark);
  }

  static LiveCheck camera(List<VisionFrame> recent, {required bool available}) {
    if (!available)
      return const LiveCheck(CheckState.unavailable, T.statusUnavailable);
    if (recent.isEmpty)
      return const LiveCheck(CheckState.checking, T.statusChecking);
    final q = assessCamera(recent, windowMs, available: true);
    return q.usable
        ? const LiveCheck(CheckState.good, T.statusGood)
        : const LiveCheck(CheckState.problem, T.statusSlow);
  }

  static LiveCheck face(List<VisionFrame> recent) {
    if (recent.isEmpty)
      return const LiveCheck(CheckState.checking, T.statusChecking);
    final q = assessFace(recent, minFraction: 0.6);
    if (q.usable) return const LiveCheck(CheckState.good, T.statusGood);
    return LiveCheck(
        CheckState.problem,
        switch (q.reason) {
          ReasonCode.faceTooFar => T.statusTooFar,
          ReasonCode.faceTooClose => T.statusTooClose,
          ReasonCode.tooDark => T.statusTooDark,
          ReasonCode.tooBright => T.statusTooBright,
          _ => T.statusNoFace,
        });
  }

  static LiveCheck noise(List<AudioLevel> recent, {required bool available}) {
    if (!available)
      return const LiveCheck(CheckState.unavailable, T.statusUnavailable);
    if (recent.length < 5)
      return const LiveCheck(CheckState.checking, T.statusChecking);
    final q = assessAudioFloor(recent, available: true);
    return q.usable
        ? const LiveCheck(CheckState.good, T.statusGood)
        : const LiveCheck(CheckState.problem, T.statusNoisy);
  }
}

class SetupScreen extends StatefulWidget {
  const SetupScreen(
      {super.key,
      required this.session,
      required this.onBegin,
      this.isTour = false});
  final SessionController session;
  final VoidCallback onBegin;

  /// The demo tour has no real camera/microphone to grant, so this screen
  /// never shows the permission request step for it.
  final bool isTour;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  SessionController get session => widget.session;
  final _frames = <VisionFrame>[];
  final _audio = <AudioLevel>[];
  StreamSubscription<VisionFrame>? _frameSub;
  StreamSubscription<AudioLevel>? _audioSub;
  Timer? _refresh;
  bool _starting = false;
  bool _requested = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Skips the "Allow camera/mic" step from the very first frame, so it
    // never flashes a button there is nothing real to grant.
    if (widget.isTour) _requested = true;
    _init();
  }

  Future<void> _init() async {
    if (widget.isTour) {
      await session.refreshPermissions();
      await session.startSensors();
      if (mounted) setState(() {});
      return;
    }
    await session.refreshPermissions();
    final p = session.permissionResult!;
    if (p.camera == PermissionState.granted ||
        p.microphone == PermissionState.granted) {
      _requested = true;
      await _startSensors(request: false);
    }
    if (mounted) setState(() {});
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Returning from system settings: pick up newly granted permissions.
    if (!widget.isTour && state == AppLifecycleState.resumed && _requested)
      _startSensors(request: false);
  }

  Future<void> _startSensors({required bool request}) async {
    if (_starting) return;
    setState(() => _starting = true);
    if (request) {
      await session.requestAndStartSensors();
      _requested = true;
    } else {
      await session.refreshPermissions();
      await session.startSensors();
    }
    _listen();
    if (mounted) setState(() => _starting = false);
  }

  void _listen() {
    _frameSub?.cancel();
    _audioSub?.cancel();
    final hub = session.sensors;
    hub.mode = VisionMode.face;
    _frameSub = hub.frames.listen(_frames.add);
    if (hub.availability.microphone) _audioSub = hub.audio.listen(_audio.add);
    _refresh ??= Timer.periodic(const Duration(milliseconds: 400), (_) {
      final now = session.sensors.clock.nowMs();
      _frames.removeWhere((f) => now - f.tMs > EnvironmentReadiness.windowMs);
      _audio.removeWhere((a) => now - a.tMs > EnvironmentReadiness.windowMs);
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _refresh?.cancel();
    _frameSub?.cancel();
    _audioSub?.cancel();
    session.sensors.mode = VisionMode.off;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final name = session.childName;
    final p = session.permissionResult;
    final a = session.availability;
    final checks = <(T, LiveCheck)>[
      (
        T.checkCamera,
        EnvironmentReadiness.camera(_frames, available: a.camera)
      ),
      if (a.camera) (T.checkLighting, EnvironmentReadiness.lighting(_frames)),
      if (a.camera) (T.checkFace, EnvironmentReadiness.face(_frames)),
      (
        T.checkQuiet,
        EnvironmentReadiness.noise(_audio, available: a.microphone)
      ),
      (T.checkTouch, const LiveCheck(CheckState.good, T.statusGood)),
    ];
    if (widget.isTour) {
      for (var i = 0; i < checks.length; i++) {
        checks[i] =
            (checks[i].$1, const LiveCheck(CheckState.good, T.statusGood));
      }
    }
    final allGood = checks.every((c) => c.$2.state == CheckState.good);
    final preview = session.sensors.preview();
    final permanentlyDenied = p != null &&
        (p.camera == PermissionState.permanentlyDenied ||
            p.microphone == PermissionState.permanentlyDenied);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionHeader(
            overline: s(T.setupOverline),
            title: s(T.setupTitle),
            lead: s(T.setupLead, {'name': name})),
        if (!_requested) ...[
          InfoCard(
            color: SanketColors.mint,
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                const Icon(Icons.videocam_outlined,
                    color: SanketColors.primary),
                const SizedBox(width: 6),
                const Icon(Icons.mic_none, color: SanketColors.primary),
                const SizedBox(width: 10),
                Expanded(
                    child: Text(s(T.setupPermissionTitle),
                        style: const TextStyle(fontWeight: FontWeight.w800))),
              ]),
              const SizedBox(height: 8),
              Text(s(T.setupPermissionBody, {'name': name})),
            ]),
          ),
          PrimaryButton(
              label: s(T.setupAllow),
              icon: Icons.lock_open,
              onPressed: _starting ? null : () => _startSensors(request: true)),
        ] else ...[
          if (widget.isTour)
            IconNote(
                icon: Icons.info_outline,
                color: SanketColors.cream,
                text: s(T.tourActualPrivacy)),
          if (preview != null)
            InfoCard(
              padding: 8,
              color: const Color(0xff123d35),
              child: Column(children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 260),
                      child: preview),
                ),
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Text(s(T.setupTipFace, {'name': name}),
                      style: const TextStyle(
                          color: Colors.white, fontWeight: FontWeight.w600)),
                ),
              ]),
            ),
          if (!a.camera && p?.camera != PermissionState.granted)
            IconNote(
                icon: Icons.videocam_off_outlined,
                iconColor: SanketColors.warn,
                color: SanketColors.warnSoft,
                text: s(T.setupCameraDenied)),
          if (!a.microphone && p?.microphone != PermissionState.granted)
            IconNote(
                icon: Icons.mic_off_outlined,
                iconColor: SanketColors.warn,
                color: SanketColors.warnSoft,
                text: s(T.setupMicDenied, {'name': name})),
          if (permanentlyDenied)
            PrimaryButton(
                label: s(T.setupOpenSettings),
                pale: true,
                icon: Icons.settings,
                onPressed: session.permissions.openSettings)
          else if (!a.camera || !a.microphone)
            PrimaryButton(
                label: s(T.setupAllow),
                pale: true,
                onPressed:
                    _starting ? null : () => _startSensors(request: true)),
          const SizedBox(height: 18),
          Text(s(T.setupChecksTitle),
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          InfoCard(
            padding: 6,
            child: Column(children: [
              for (final (label, check) in checks)
                Semantics(
                  label: '${s(label)}: ${s(check.label)}',
                  excludeSemantics: true,
                  child: ListTile(
                    leading: Icon(
                      switch (check.state) {
                        CheckState.good => Icons.check_circle,
                        CheckState.checking => Icons.hourglass_empty,
                        CheckState.problem => Icons.warning_amber_rounded,
                        CheckState.unavailable => Icons.remove_circle_outline,
                      },
                      color: check.state == CheckState.good
                          ? SanketColors.leaf
                          : SanketColors.warn,
                    ),
                    title: Text(s(label),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    trailing: Text(s(check.label),
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: check.state == CheckState.good
                                ? SanketColors.primary
                                : SanketColors.warn)),
                  ),
                ),
            ]),
          ),
          if (!allGood)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(s(T.setupContinueAnyway),
                  style: const TextStyle(color: SanketColors.muted)),
            ),
          const SizedBox(height: 6),
          Text(s(T.setupRotateHint),
              style: const TextStyle(color: SanketColors.muted, fontSize: 13)),
          PrimaryButton(
            label: s(T.setupBegin),
            icon: Icons.screen_rotation_alt,
            onPressed: _starting ? null : widget.onBegin,
          ),
        ],
      ]),
    );
  }
}
