import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet, springAt;
import 'tones.dart';

/// One choice of a [LiquidToggle].
class LiquidOption<T> {
  final T value;
  final IconData icon;
  final String label;
  const LiquidOption(this.value, this.icon, this.label);
}

/// Icons on a soft track with a violet → cyan drop under the picked one. Picking another pulls
/// the drop across like liquid: the front runs ahead, the back follows, the middle thins to a
/// neck, then it gathers into a pill with a wobble. The icons go white as the liquid covers them.
/// It moves at once; if [onChanged] fails it flows back, and a new [value] from outside moves it too.
class LiquidToggle<T> extends StatefulWidget {
  final List<LiquidOption<T>> options;
  final T value;
  /// Saves the pick; when it throws, the drop flows back to [value].
  final Future<void> Function(T value) onChanged;
  final double slotWidth, height;
  const LiquidToggle({super.key, required this.options, required this.value, required this.onChanged, this.slotWidth = 44, this.height = 34});

  @override
  State<LiquidToggle<T>> createState() => _LiquidToggleState<T>();
}

class _LiquidToggleState<T> extends State<LiquidToggle<T>> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..value = 1;
  late int _to = _indexOf(widget.value);
  late double _from = _to.toDouble();

  int _indexOf(T v) => math.max(0, widget.options.indexWhere((o) => o.value == v));

  @override
  void didUpdateWidget(LiquidToggle<T> old) {
    super.didUpdateWidget(old);
    final i = _indexOf(widget.value);
    if (i != _to) _go(i);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  /// Where the drop's front and back are now, in slots.
  ({double back, double front}) _ends(double t) {
    final fast = springAt(t * 0.9, 19, 0.55), slow = springAt(t * 0.9, 10, 0.62);
    return (back: _from + (_to - _from) * slow, front: _from + (_to - _from) * fast);
  }

  void _go(int i) {
    // From wherever the drop is (mid-move too): its middle.
    final e = _ends(_t.value);
    setState(() {
      _from = (e.back + e.front) / 2;
      _to = i;
    });
    _t.forward(from: 0);
  }

  void _pick(int i) {
    if (i == _to) return;
    HapticFeedback.selectionClick();
    _go(i);
    widget.onChanged(widget.options[i].value).catchError((Object _) {
      if (mounted) _go(_indexOf(widget.value));
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = widget.slotWidth, h = widget.height;
    final n = widget.options.length;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: ShapeDecoration(color: scheme.softFill, shape: const StadiumBorder()),
      child: SizedBox(
        width: w * n,
        height: h,
        child: AnimatedBuilder(
          animation: _t,
          builder: (context, _) {
            final e = _ends(_t.value);
            // Kept inside the track: past an end the bounce squashes the drop instead (never thinner than round).
            final left = (math.min(e.back, e.front) * w).clamp(0.0, w * n - h);
            final right = (math.max(e.back, e.front) * w + w).clamp(left + h, w * n);
            return Stack(children: [
              Positioned.fill(child: CustomPaint(painter: _DropPainter(left: left, right: right, slot: w, front: e.front > e.back ? 1 : -1))),
              Row(children: [
                for (final (i, o) in widget.options.indexed)
                  Tooltip(
                    message: o.label,
                    child: Semantics(
                      button: true,
                      selected: i == _to,
                      label: o.label,
                      excludeSemantics: true,
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pick(i),
                        child: SizedBox(
                          width: w,
                          height: h,
                          child: Icon(
                            o.icon,
                            size: 19,
                            // White as far as the liquid covers the icon.
                            color: Color.lerp(scheme.onSurfaceVariant, Colors.white,
                                ((math.min(right, i * w + w / 2 + 10) - math.max(left, i * w + w / 2 - 10)) / 20).clamp(0.0, 1.0)),
                          ),
                        ),
                      ),
                    ),
                  ),
              ]),
            ]);
          },
        ),
      ),
    );
  }
}

/// The drop from [left] to [right]: round ends joined by a neck that thins as it stretches, the
/// front end a little fuller than the back (it carries the liquid).
class _DropPainter extends CustomPainter {
  final double left, right, slot;
  final int front; // 1: the front is the right end
  _DropPainter({required this.left, required this.right, required this.slot, required this.front});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final r = size.height / 2;
    final stretch = ((right - left) / slot - 1).clamp(0.0, 3.0); // 0 at rest
    // A stretched drop holds the same liquid: thinner overall, thinnest in the middle.
    final rFront = r * (1 - 0.06 * stretch).clamp(0.8, 1.0);
    final rBack = r * (1 - 0.22 * stretch).clamp(0.55, 1.0);
    final neck = r * (1 - 0.45 * stretch).clamp(0.3, 1.0);
    final rl = front > 0 ? rBack : rFront, rr = front > 0 ? rFront : rBack;
    final lx = left + r, rx = math.max(lx, right - r); // end centres
    final mid = (lx + rx) / 2;
    // A quadratic through the neck height at the middle: control point twice as far out.
    double ctl(double end1, double end2) => 2 * neck - (end1 + end2) / 2;
    final path = Path()
      ..moveTo(lx, cy - rl)
      ..quadraticBezierTo(mid, cy - ctl(rl, rr), rx, cy - rr)
      ..arcToPoint(Offset(rx, cy + rr), radius: Radius.circular(rr))
      ..quadraticBezierTo(mid, cy + ctl(rl, rr), lx, cy + rl)
      ..arcToPoint(Offset(lx, cy - rl), radius: Radius.circular(rl))
      ..close();
    final bounds = Rect.fromLTRB(left, 0, right, size.height);
    canvas.drawPath(
      path,
      Paint()
        ..color = pillViolet.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawPath(path, Paint()..shader = const LinearGradient(colors: [pillViolet, pillCyan]).createShader(bounds));
  }

  @override
  bool shouldRepaint(_DropPainter old) => old.left != left || old.right != right || old.front != front;
}
