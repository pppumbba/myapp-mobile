import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet, springAt;

/// One option of [SpeedDialFab].
class SpeedDialItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  const SpeedDialItem({required this.icon, required this.label, required this.color, required this.onTap});
}

/// Colors the options take in turn, bottom first.
const speedDialColors = [Color(0xFF3DDBB0), Color(0xFFFF5CA8), pillCyan, Color(0xFFFFD166), pillViolet];

double _seg(double x, double a, double b) => ((x - a) / (b - a)).clamp(0.0, 1.0);
double _ease(double k) => 1 - math.pow(1 - k.clamp(0.0, 1.0), 3).toDouble();
double _easeIO(double k) {
  k = k.clamp(0.0, 1.0);
  return k < 0.5 ? 4 * k * k * k : 1 - math.pow(-2 * k + 2, 3) / 2;
}

/// The round gradient + button. With two or more [items] a tap opens them above it (the + turns
/// into ×, the screen dims); with none it just calls [onPressed].
class SpeedDialFab extends StatefulWidget {
  final String tooltip;
  final List<SpeedDialItem> items;
  final VoidCallback? onPressed;
  const SpeedDialFab({super.key, required this.tooltip, this.items = const [], this.onPressed});

  @override
  State<SpeedDialFab> createState() => _SpeedDialFabState();
}

class _SpeedDialFabState extends State<SpeedDialFab> {
  bool _down = false;

  void _tap() {
    if (widget.items.length < 2) {
      widget.onPressed?.call();
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    final center = box.localToGlobal(box.size.center(Offset.zero));
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    Navigator.of(context, rootNavigator: true).push(_DialRoute(
      center: center,
      items: widget.items,
      tooltip: widget.tooltip,
      still: still,
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        excludeSemantics: true,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: _tap,
          // Squeezes a little under the finger.
          child: AnimatedScale(
            scale: _down ? 0.92 : 1,
            duration: Duration(milliseconds: _down ? 90 : 260),
            curve: _down ? Curves.easeOut : Curves.elasticOut,
            child: const _FabFace(turn: 0),
          ),
        ),
      ),
    );
  }
}

/// The button itself: a gradient circle with a + turned by [turn] (0 = +, 1 = ×).
class _FabFace extends StatelessWidget {
  final double turn;
  const _FabFace({required this.turn});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pillViolet, pillCyan]),
        boxShadow: [BoxShadow(color: Color(0x8C6E5BFF), blurRadius: 18, offset: Offset(0, 6))],
      ),
      child: Transform.rotate(angle: 0.75 * math.pi * turn, child: const Icon(Icons.add, color: Colors.white, size: 28)),
    );
  }
}

class _DialRoute extends PopupRoute<void> {
  final Offset center;
  final List<SpeedDialItem> items;
  final String tooltip;
  final bool still;
  _DialRoute({required this.center, required this.items, required this.tooltip, required this.still});

  @override
  Color? get barrierColor => null; // the dim is drawn with the animation
  @override
  bool get barrierDismissible => false; // the dim handles taps itself
  @override
  String? get barrierLabel => null;
  @override
  Duration get transitionDuration => still ? Duration.zero : const Duration(milliseconds: 700);
  @override
  Duration get reverseTransitionDuration => still ? Duration.zero : const Duration(milliseconds: 320);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final closing = animation.status == AnimationStatus.reverse || animation.status == AnimationStatus.dismissed;
        final t = animation.value * 0.7, d = (1 - animation.value) * 0.32;
        final done = still || (!closing && animation.status == AnimationStatus.completed);
        // Opens on springs, closes in about 0.3 s, top option first.
        final o = done ? 1.0 : closing ? 1 - _easeIO(d / 0.3) : springAt(t, 15, 0.6);
        final kY = done ? 1.0 : closing ? 1 - _ease(_seg(d, 0, 0.28)) : springAt(t - 0.05, 17, 0.58);
        final n = items.length;
        final scheme = Theme.of(context).colorScheme;
        final children = <Widget>[
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => Navigator.of(context).pop(),
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.55 * o.clamp(0.0, 1.0))),
            ),
          ),
        ];
        for (var j = 0; j < n; j++) {
          final kj = done
              ? 1.0
              : closing
                  ? 1 - _ease(_seg(d, 0.04 * (n - 1 - j), 0.04 * (n - 1 - j) + 0.2))
                  : springAt(t - 0.05 - 0.07 * j, 17, 0.58);
          if (kj <= 0.002) continue;
          final y = center.dy + (-56.0 * (j + 1)) * kY;
          final sc = kj.clamp(0.0, 1.15), al = (3 * kj).clamp(0.0, 1.0), la = (2 * (kj - 0.5)).clamp(0.0, 1.0);
          final item = items[j];
          void run() {
            Navigator.of(context).pop();
            item.onTap();
          }

          children.add(Positioned(
            right: MediaQuery.sizeOf(context).width - center.dx + 30 - 12 * (1 - la),
            top: y - 15,
            child: Opacity(
              opacity: la,
              child: GestureDetector(
                onTap: run,
                child: Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.inverseSurface,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.5),
                  ),
                  child: Text(item.label, style: TextStyle(color: scheme.onInverseSurface, fontSize: 13, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ));
          children.add(Positioned(
            left: center.dx - 20,
            top: y - 20,
            child: Opacity(
              opacity: al,
              child: Transform.scale(
                scale: sc,
                child: Semantics(
                  button: true,
                  label: item.label,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: run,
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2A2840),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1.5),
                        boxShadow: const [BoxShadow(color: Color(0x73000000), blurRadius: 10)],
                      ),
                      child: Icon(item.icon, color: item.color, size: 20),
                    ),
                  ),
                ),
              ),
            ),
          ));
        }
        // The button again, above the dim, turning into ×.
        children.add(Positioned(
          left: center.dx - 28,
          top: center.dy - 28,
          child: Semantics(
            button: true,
            label: MaterialLocalizations.of(context).closeButtonTooltip,
            excludeSemantics: true,
            child: GestureDetector(onTap: () => Navigator.of(context).pop(), child: _FabFace(turn: o)),
          ),
        ));
        return Material(type: MaterialType.transparency, child: Stack(children: children));
      },
    );
  }
}
