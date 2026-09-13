import 'dart:math' as math;
import 'dart:ui';

import '../../core/activity_capture.dart';
import '../../core/activity_catalog.dart';
import '../../core/prototype_parameters.dart';
import '../../core/samples.dart';
import '../../runtime/activity_controller.dart';
import 'bubble_trail_analyzer.dart';

/// A bubble's path is a pure function of time, shared by drawing and hit-testing.
class Bubble {
  Bubble({
    required this.id,
    required this.spawnMs,
    required this.x0,
    required this.drift,
    required this.sway,
    required this.radiusFraction,
    required this.color,
  });
  final int id, spawnMs;
  final double x0, drift, sway, radiusFraction;
  final int color;

  double progressAt(int tMs) => (tMs - spawnMs) / P.bubbleLifetimeMs;

  double radius(Size board) => board.shortestSide * radiusFraction;

  Offset centerAt(int tMs, Size board) {
    final p = progressAt(tMs).clamp(0.0, 1.0);
    final r = radius(board);
    final x = board.width * (x0 + drift * p) + math.sin(p * math.pi * 3) * sway * board.width;
    final y = board.height + r - p * (board.height + 2 * r);
    return Offset(x, y);
  }
}

class PoppedBubble {
  const PoppedBubble(this.center, this.radius, this.color, this.atMs);
  final Offset center;
  final double radius;
  final int color, atMs;
}

class BubbleTrailController extends ActivityController {
  BubbleTrailController(super.ctx);

  @override
  ActivityId get id => ActivityId.bubbleTrail;
  @override
  ActivityAnalyzer get analyzer => const BubbleTrailAnalyzer();
  @override
  VisionMode get visionMode => VisionMode.off;
  @override
  bool get requiresCamera => false;
  @override
  int get expectedDurationMs => P.bubbleDurationMs;

  static const palette = [0xfff4a5c6, 0xff79c7f2, 0xffa4d657, 0xfff5c745, 0xffb890df];

  final List<Bubble> alive = [];
  final List<PoppedBubble> popped = [];
  int poppedCount = 0;
  bool showHint = false;

  /// Set by the view once the board is laid out.
  Size? board;
  int _nextId = 0;
  int _lastSpawn = -100000;
  int _lastTouch = 0;

  @override
  void onStart() {
    alive.clear();
    popped.clear();
    poppedCount = 0;
    _nextId = 0;
    _lastSpawn = -100000;
    _lastTouch = now;
    showHint = false;
    _spawn();
    after(P.bubbleDurationMs, () => finish());
  }

  void _spawn() {
    final r = ctx.random;
    final b = Bubble(
      id: _nextId++,
      spawnMs: now,
      x0: 0.15 + r.nextDouble() * 0.7,
      drift: (r.nextDouble() - 0.5) * 0.2,
      sway: 0.02 + r.nextDouble() * 0.04,
      radiusFraction: 0.085 + r.nextDouble() * 0.035,
      color: palette[r.nextInt(palette.length)],
    );
    alive.add(b);
    _lastSpawn = now;
    record(BubbleTrailAnalyzer.spawn, {'id': b.id});
  }

  @override
  void onTick() {
    final t = now;
    alive.removeWhere((b) {
      if (b.progressAt(t) < 1) return false;
      record(BubbleTrailAnalyzer.expire, {'id': b.id});
      return true;
    });
    popped.removeWhere((p) => t - p.atMs > 450);
    if (alive.length < P.bubbleMaxConcurrent && t - _lastSpawn >= P.bubbleSpawnEveryMs) _spawn();
    final idle = t - _lastTouch;
    showHint = idle >= P.bubbleInactivityHintMs;
    if (idle >= P.bubbleInactivityStopMs) {
      record(BubbleTrailAnalyzer.inactivityStop);
      finish();
    }
  }

  /// A touch on the board at [position], with [pointers] fingers down.
  void touch(Offset position, int pointers) {
    final size = board;
    if (phase != ActivityPhase.running || size == null) return;
    _lastTouch = now;
    showHint = false;
    if (pointers > P.maxSimultaneousPointers) {
      record(BubbleTrailAnalyzer.rejected, {'pointers': pointers});
      return;
    }
    final t = now;
    Bubble? best;
    double bestDistance = double.infinity;
    for (final b in alive) {
      final d = (b.centerAt(t, size) - position).distance;
      if (d < bestDistance) {
        bestDistance = d;
        best = b;
      }
    }
    if (best != null && bestDistance <= best.radius(size) + P.bubbleHitSlopPx) {
      final r = best.radius(size);
      record(BubbleTrailAnalyzer.pop, {
        'id': best.id,
        'rtMs': t - best.spawnMs,
        'errorNorm': bestDistance / r,
      });
      popped.add(PoppedBubble(best.centerAt(t, size), r, best.color, t));
      alive.remove(best);
      poppedCount++;
    } else {
      record(BubbleTrailAnalyzer.miss, {
        'distanceNorm': best == null ? -1.0 : bestDistance / best.radius(size),
      });
    }
    notify();
  }
}
