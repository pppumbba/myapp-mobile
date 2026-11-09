import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Watches vertical scrolling below it: scrolling down hides the bars above the content
/// (top bar, a grid's search and filters), scrolling up or reaching the top shows them again.
/// Changing [resetKey] (another tab or screen) shows them again too.
class ScrollChrome extends StatefulWidget {
  final Object? resetKey;
  final Widget Function(BuildContext context, ValueListenable<bool> shown) builder;
  const ScrollChrome({super.key, this.resetKey, required this.builder});

  /// The shown flag of the nearest [ScrollChrome], or null outside one (a pushed page, a sheet).
  static ValueListenable<bool>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ChromeScope>()?.shown;

  @override
  State<ScrollChrome> createState() => _ScrollChromeState();
}

class _ScrollChromeState extends State<ScrollChrome> {
  final _shown = ValueNotifier(true);
  double _travel = 0;

  @override
  void didUpdateWidget(ScrollChrome old) {
    super.didUpdateWidget(old);
    if (old.resetKey != widget.resetKey) _show();
  }

  @override
  void dispose() {
    _shown.dispose();
    super.dispose();
  }

  void _show() {
    _travel = 0;
    _shown.value = true;
  }

  bool _onScroll(ScrollNotification n) {
    final m = n.metrics;
    if (m.axis != Axis.vertical || n is! ScrollUpdateNotification) return false;
    final delta = n.scrollDelta ?? 0;
    // Near the top, or a list too short to be worth the room: always shown.
    if (m.pixels <= 8 || m.maxScrollExtent < 160) {
      _show();
      return false;
    }
    // A little travel in one direction before switching, so a shaky finger doesn't flicker it.
    _travel = (delta.sign == _travel.sign ? _travel : 0) + delta;
    if (_travel > 24 && m.extentAfter > 0) _shown.value = false;
    if (_travel < -24) _shown.value = true;
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: _ChromeScope(shown: _shown, child: Builder(builder: (context) => widget.builder(context, _shown))),
      );
}

class _ChromeScope extends InheritedWidget {
  final ValueListenable<bool> shown;
  const _ChromeScope({required this.shown, required super.child});

  @override
  bool updateShouldNotify(_ChromeScope old) => old.shown != shown;
}

/// [child] folding up out of sight (and fading) while [shown] is false.
class CollapseOnScroll extends StatelessWidget {
  final ValueListenable<bool>? shown;
  final Widget child;
  const CollapseOnScroll({super.key, required this.shown, required this.child});

  @override
  Widget build(BuildContext context) {
    final s = shown;
    if (s == null) return child;
    return ValueListenableBuilder<bool>(
      valueListenable: s,
      child: child,
      builder: (context, on, child) => ClipRect(
        child: AnimatedAlign(
          alignment: Alignment.bottomCenter,
          heightFactor: on ? 1 : 0,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: AnimatedOpacity(
            opacity: on ? 1 : 0,
            duration: const Duration(milliseconds: 200),
            child: IgnorePointer(ignoring: !on, child: child),
          ),
        ),
      ),
    );
  }
}
