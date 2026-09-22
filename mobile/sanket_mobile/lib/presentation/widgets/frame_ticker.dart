import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Rebuilds every display frame with the current session time, so drawn
/// stimuli (bubbles, talking guide) use the same clock as the measurements.
class FrameTicker extends StatefulWidget {
  const FrameTicker(
      {super.key,
      required this.nowMs,
      required this.builder,
      this.active = true});
  final int Function() nowMs;
  final Widget Function(BuildContext context, int nowMs) builder;
  final bool active;

  @override
  State<FrameTicker> createState() => _FrameTickerState();
}

class _FrameTickerState extends State<FrameTicker>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker((_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    if (widget.active) _ticker.start();
  }

  @override
  void didUpdateWidget(FrameTicker old) {
    super.didUpdateWidget(old);
    if (widget.active && !_ticker.isActive) _ticker.start();
    if (!widget.active && _ticker.isActive) _ticker.stop();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context, widget.nowMs());
}
