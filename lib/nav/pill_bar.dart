import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

/// One tab of [PillNavBar].
class PillDestination {
  final IconData icon;
  final String label;
  const PillDestination({required this.icon, required this.label});
}

const pillViolet = Color(0xFF6E5BFF);
const pillCyan = Color(0xFF38C6FF);
// See-through, over a blur of whatever scrolls behind the bar.
const _barFill = Color(0xB81B1A28);
const _gray = Color(0xFF8C8AA8);

/// Damped spring from 0 to 1, [t] seconds after the tap (0 before it).
double springAt(double t, double w0, double zeta) {
  if (t <= 0) return 0;
  final wd = w0 * math.sqrt(1 - zeta * zeta);
  return 1 - math.exp(-zeta * w0 * t) * (math.cos(wd * t) + (zeta * w0 / wd) * math.sin(wd * t));
}

/// The pill's left and right edges in px, [t] seconds after moving from tab [from] to tab [to].
/// The leading edge (the side it moves toward) rides a fast spring and the trailing edge a slower
/// one, so the pill stretches in flight and lands at its rest width. Both edges stay [inset] px
/// inside the bar's ends.
({double left, double right}) pillEdges({
  required double t,
  required int from,
  required int to,
  required int count,
  required double width,
  double inset = 6,
}) {
  final tab = width / count;
  final half = (tab - 2 * 8.25) / 2; // 86 px pill in a 102.5 px tab
  final fast = springAt(t, 19, 0.55), slow = springAt(t, 11, 0.72);
  final right = to > from;
  final pl = from + (to - from) * (right ? slow : fast);
  final pr = from + (to - from) * (right ? fast : slow);
  double x(double p) => tab * (p + 0.5);
  return (
    left: (x(pl) - half).clamp(inset, width - inset),
    right: (x(pr) + half).clamp(inset, width - inset),
  );
}

/// A floating bottom tab bar whose gradient pill stretches between tabs on two springs.
class PillNavBar extends StatefulWidget {
  final int selectedIndex;
  final List<PillDestination> destinations;
  final ValueChanged<int> onDestinationSelected;

  const PillNavBar({
    super.key,
    required this.selectedIndex,
    required this.destinations,
    required this.onDestinationSelected,
  });

  @override
  State<PillNavBar> createState() => _PillNavBarState();
}

class _PillNavBarState extends State<PillNavBar> with SingleTickerProviderStateMixin {
  static const _settle = Duration(milliseconds: 1200);
  late final AnimationController _clock = AnimationController(vsync: this, duration: _settle, value: 1);
  late int _from = widget.selectedIndex;

  @override
  void didUpdateWidget(PillNavBar old) {
    super.didUpdateWidget(old);
    if (old.selectedIndex != widget.selectedIndex) {
      _from = old.selectedIndex;
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _clock.value = 1;
      } else {
        _clock.forward(from: 0);
      }
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.destinations.length;
    final bottom = MediaQuery.paddingOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, 12 + bottom),
      child: SizedBox(
        height: 64,
        child: Stack(fit: StackFit.expand, children: [
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18), child: const SizedBox.expand()),
            ),
          ),
          LayoutBuilder(builder: (context, box) {
          final width = box.maxWidth;
          final tab = width / n;
          return AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final to = widget.selectedIndex.clamp(0, n - 1);
              final e = pillEdges(
                t: _clock.value * _settle.inMilliseconds / 1000,
                from: _from.clamp(0, n - 1),
                to: to,
                count: n,
                width: width,
              );
              final mid = (e.left + e.right) / 2;
              return CustomPaint(
                painter: _BarPainter(left: e.left, right: e.right),
                child: Row(children: [
                  for (var i = 0; i < n; i++)
                    Expanded(
                      child: _Tab(
                        d: widget.destinations[i],
                        selected: i == to,
                        // The icon under the pill turns white.
                        color: Color.lerp(_gray, Colors.white, (1 - (mid - tab * (i + 0.5)).abs() / (tab * 0.78)).clamp(0.0, 1.0))!,
                        onTap: () => widget.onDestinationSelected(i),
                      ),
                    ),
                ]),
              );
            },
          );
        }),
        ]),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final PillDestination d;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _Tab({required this.d, required this.selected, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: d.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        // Icons only; the name shows on long-press and is read out by screen readers.
        child: Tooltip(message: d.label, child: Center(child: Icon(d.icon, color: color, size: 26))),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final double left, right;
  _BarPainter({required this.left, required this.right});

  @override
  void paint(Canvas canvas, Size size) {
    final bar = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(24));
    // Soft shadow 6 px down (outside the bar only, so it does not darken the see-through fill),
    // then the fill and a 1 px inner border.
    canvas.save();
    canvas.clipPath(Path.combine(
      PathOperation.difference,
      Path()..addRect((Offset.zero & size).inflate(40)),
      Path()..addRRect(bar),
    ));
    canvas.drawRRect(
      bar.shift(const Offset(0, 6)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.restore();
    canvas.drawRRect(bar, Paint()..color = _barFill);
    canvas.drawRRect(
      bar.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Colors.white.withValues(alpha: 0.08),
    );

    final w = right - left;
    if (w <= 0) return;
    const h = 48.0;
    final rect = Rect.fromLTWH(left, (size.height - h) / 2, w, h);
    final pill = RRect.fromRectAndRadius(rect, Radius.circular(math.min(h, w) / 2));
    canvas.drawRRect(
      pill,
      Paint()
        ..color = pillViolet.withValues(alpha: 0.65)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );
    canvas.drawRRect(
      pill,
      Paint()..shader = const LinearGradient(colors: [pillViolet, pillCyan]).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_BarPainter old) => old.left != left || old.right != right;
}
