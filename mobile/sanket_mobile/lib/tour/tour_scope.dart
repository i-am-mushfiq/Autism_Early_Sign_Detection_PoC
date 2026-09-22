import 'package:flutter/material.dart';
import '../l10n/locale_scope.dart';
import '../l10n/strings.dart';

class TourScope extends InheritedWidget {
  const TourScope(
      {super.key,
      required this.enabled,
      required this.target,
      required super.child});
  final bool enabled;
  final String? target;
  static TourScope? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TourScope>();
  @override
  bool updateShouldNotify(TourScope oldWidget) =>
      enabled != oldWidget.enabled || target != oldWidget.target;
}

/// Decorates the existing control; never substitutes a tour navigation button.
class TourTarget extends StatefulWidget {
  const TourTarget({super.key, required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  State<TourTarget> createState() => _TourTargetState();
}

class _TourTargetState extends State<TourTarget> {
  bool highlighted = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final scope = TourScope.of(context);
    final next = scope?.enabled == true && scope?.target == widget.label;
    if (next && !highlighted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted)
          Scrollable.ensureVisible(context,
              duration: const Duration(milliseconds: 250), alignment: .8);
      });
    }
    highlighted = next;
  }

  @override
  Widget build(BuildContext context) => !highlighted
      ? widget.child
      : Container(
          key: const ValueKey('tour-highlight'),
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
              border: Border.all(color: const Color(0xffdb9a24), width: 3),
              borderRadius: BorderRadius.circular(20)),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(context.s(T.tourPressActual, {'action': widget.label}),
                textAlign: TextAlign.center,
                style:
                    const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            widget.child,
          ]));
}
