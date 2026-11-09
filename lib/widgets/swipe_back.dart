import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show PredictiveBackEvent;

/// Page transitions for every pushed page: it slides in from the right and can be dragged back
/// from its left edge; the page underneath follows with parallax under a dim that lifts as the
/// top page leaves, and the dragged edge glows cyan while the finger is down.
class SwipeBackTransitionsBuilder extends PageTransitionsBuilder {
  const SwipeBackTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // The iOS route gives the slide, the parallax and the edge drag with its fly-off.
    final page = CupertinoRouteTransitionMixin.buildPageTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      _SystemBack(
        route: route,
        child: Stack(fit: StackFit.passthrough, children: [
          child,
          Positioned(left: 0, top: 0, bottom: 0, width: 14, child: _EdgeGlow(route: route, animation: animation)),
        ]),
      ),
    );
    return Stack(fit: StackFit.passthrough, children: [
      page,
      // Dim over this page while another one covers it.
      Positioned.fill(
        child: IgnorePointer(
          child: AnimatedBuilder(
            animation: secondaryAnimation,
            builder: (_, _) => secondaryAnimation.value == 0
                ? const SizedBox.shrink()
                : ColoredBox(color: Colors.black.withValues(alpha: 0.4 * secondaryAnimation.value)),
          ),
        ),
      ),
    ]);
  }
}

/// Android with gesture navigation keeps the screen edge for its own back swipe and reports its
/// progress instead; this drives the same drag from it, so the page follows the system swipe.
class _SystemBack extends StatefulWidget {
  final PageRoute<dynamic> route;
  final Widget child;
  const _SystemBack({required this.route, required this.child});

  @override
  State<_SystemBack> createState() => _SystemBackState();
}

class _SystemBackState extends State<_SystemBack> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  bool handleStartBackGesture(PredictiveBackEvent backEvent) {
    if (backEvent.isButtonEvent || !widget.route.isCurrent || !widget.route.popGestureEnabled) return false;
    widget.route.handleStartBackGesture(progress: 1 - backEvent.progress);
    return true;
  }

  @override
  void handleUpdateBackGestureProgress(PredictiveBackEvent backEvent) =>
      widget.route.handleUpdateBackGestureProgress(progress: 1 - backEvent.progress);

  @override
  void handleCancelBackGesture() => widget.route.handleCancelBackGesture();

  @override
  void handleCommitBackGesture() => widget.route.handleCommitBackGesture();

  @override
  Widget build(BuildContext context) => widget.child;
}

/// A cyan fade along the page's left edge, lit while the page is being dragged back.
class _EdgeGlow extends StatelessWidget {
  final PageRoute<dynamic> route;
  final Animation<double> animation;
  const _EdgeGlow({required this.route, required this.animation});

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, _) => AnimatedOpacity(
            opacity: route.popGestureInProgress ? 1 : 0,
            duration: const Duration(milliseconds: 150),
            child: const DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(colors: [Color(0xBF38C6FF), Color(0x0038C6FF)])),
            ),
          ),
        ),
      );
}
