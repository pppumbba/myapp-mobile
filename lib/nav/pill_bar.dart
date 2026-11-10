import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

import '../widgets/edge_fade.dart';

/// One tab of [PillNavBar].
class PillDestination {
  final IconData icon;
  final String label;
  const PillDestination({required this.icon, required this.label});
}

const pillViolet = Color(0xFF6E5BFF);
const pillCyan = Color(0xFF38C6FF);
// See-through, over a blur of whatever scrolls behind the bar.
const _barFill = Color(0xB81B1A28), _barFillLight = Color(0xD9FFFFFF);
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

  // --- Scrolling bar (from [_scrollFrom] tabs on) -------------------------------------------
  // The tabs scroll sideways, [_visible] at a time, from the first to the last; tabs leaving at
  // one end shrink away and those coming in at the other grow in (EdgeFade). The pill rides
  // along with its tab.

  static const _scrollFrom = 6;
  static const _visible = 4.5;
  ScrollController? _scroll;
  double _tab = 0;

  bool get _scrolls => widget.destinations.length >= _scrollFrom;

  /// The offset that puts tab [index] in the middle, as far as the strip's ends allow.
  double _centred(int index, double view) =>
      ((index + 0.5) * _tab - view / 2).clamp(0.0, (widget.destinations.length * _tab - view).clamp(0.0, double.infinity));

  /// Lays the strip out for [width]: the first time, with the picked tab as near the middle as fits.
  void _ensureStrip(double width) {
    final tab = width / _visible;
    if (_scroll != null && tab == _tab) return;
    final keep = _scroll != null && _scroll!.hasClients ? _scroll!.offset / _tab : null;
    _tab = tab;
    _scroll?.dispose();
    _scroll = ScrollController(initialScrollOffset: keep != null ? keep * tab : _centred(widget.selectedIndex, width));
  }

  @override
  void didUpdateWidget(PillNavBar old) {
    super.didUpdateWidget(old);
    if (old.destinations.length != widget.destinations.length) {
      _scroll?.dispose();
      _scroll = null;
    }
    if (old.selectedIndex != widget.selectedIndex) {
      _from = old.selectedIndex;
      if (_scrolls) _bringIntoView(widget.selectedIndex);
      if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
        _clock.value = 1;
      } else {
        _clock.forward(from: 0);
      }
    }
  }

  /// Scrolls a tab picked while off screen (by back, or the menu search) toward the middle.
  void _bringIntoView(int index) {
    final s = _scroll;
    if (s == null || !s.hasClients) return;
    final view = s.position.viewportDimension;
    final left = index * _tab, right = left + _tab;
    if (left >= s.offset && right <= s.offset + view) return;
    final to = _centred(index, view);
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      s.jumpTo(to);
    } else {
      s.animateTo(to, duration: const Duration(milliseconds: 420), curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _scroll?.dispose();
    super.dispose();
  }

  Widget _strip(BuildContext context, double width) {
    _ensureStrip(width);
    final scroll = _scroll!;
    final n = widget.destinations.length;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnimatedBuilder(
      animation: Listenable.merge([_clock, scroll]),
      builder: (context, _) {
        final offset = scroll.hasClients ? scroll.offset : scroll.initialScrollOffset;
        final to = widget.selectedIndex.clamp(0, n - 1), from = _from.clamp(0, n - 1);
        final t = _clock.value * _settle.inMilliseconds / 1000;
        // The pill's edges along the strip, on the same two springs as the fixed bar; the bar's
        // ends squeeze it as its tab scrolls off.
        final half = (_tab - 2 * 8.25) / 2;
        final fast = springAt(t, 19, 0.55), slow = springAt(t, 11, 0.72);
        final right = to > from;
        final pl = from + (to - from) * (right ? slow : fast);
        final pr = from + (to - from) * (right ? fast : slow);
        double x(double p) => _tab * (p + 0.5) - offset;
        final left = (x(pl) - half).clamp(6.0, width - 6), rightEdge = (x(pr) + half).clamp(6.0, width - 6);
        final mid = (x(pl) + x(pr)) / 2;
        return CustomPaint(
          painter: _BarPainter(left: left, right: rightEdge, dark: dark),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: ListView.builder(
              controller: scroll,
              scrollDirection: Axis.horizontal,
              itemExtent: _tab,
              itemCount: n,
              itemBuilder: (context, i) => EdgeFade(
                child: _Tab(
                  d: widget.destinations[i],
                  selected: i == to,
                  color: Color.lerp(_gray, Colors.white, (1 - (mid - x(i.toDouble())).abs() / (_tab * 0.78)).clamp(0.0, 1.0))!,
                  onTap: () => widget.onDestinationSelected(i),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.destinations.length;
    final bottom = MediaQuery.paddingOf(context).bottom;
    if (_scrolls) {
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
            LayoutBuilder(builder: (context, box) => _strip(context, box.maxWidth)),
          ]),
        ),
      );
    }
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
                painter: _BarPainter(left: e.left, right: e.right, dark: Theme.of(context).brightness == Brightness.dark),
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
  final bool dark;
  _BarPainter({required this.left, required this.right, required this.dark});

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
        ..color = Colors.black.withValues(alpha: dark ? 0.45 : 0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9),
    );
    canvas.restore();
    canvas.drawRRect(bar, Paint()..color = dark ? _barFill : _barFillLight);
    canvas.drawRRect(
      bar.deflate(0.5),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = (dark ? Colors.white : Colors.black).withValues(alpha: 0.08),
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
  bool shouldRepaint(_BarPainter old) => old.left != left || old.right != right || old.dark != dark;
}
