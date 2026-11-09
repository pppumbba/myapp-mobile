import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../nav/pill_bar.dart' show springAt;

const deleteRed = Color(0xFFF2475E);
const _redLeft = Color(0xFFFF6A78), _redRight = Color(0xFFD93160);

/// One button behind a swiped card. The [destructive] one goes last (outermost), turns red with
/// a bin, and a long swipe presses it. [onPressed] resolves to true when the record is gone.
class SwipeAction {
  final IconData icon;
  final String label;
  final Color color;
  final bool destructive;
  final Future<bool> Function() onPressed;
  const SwipeAction({required this.icon, required this.label, required this.color, required this.onPressed, this.destructive = false});
}

double _seg(double x, double a, double b) => ((x - a) / (b - a)).clamp(0.0, 1.0);
double _easeIn(double k) => math.pow(k.clamp(0.0, 1.0), 3).toDouble();

/// Swipe a card left to show its actions. When a destructive action succeeds, the card flies off
/// to the left and the space closes up on a spring, then [onRemoved] runs.
class SwipeActions extends StatefulWidget {
  final Widget child;
  final List<SwipeAction> actions;
  final VoidCallback? onRemoved;
  final BorderRadius radius;
  const SwipeActions({
    super.key,
    required this.child,
    required this.actions,
    this.onRemoved,
    this.radius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<SwipeActions> createState() => _SwipeActionsState();
}

class _SwipeActionsState extends State<SwipeActions> with TickerProviderStateMixin {
  static const _buttonW = 76.0;
  late final AnimationController _x = AnimationController.unbounded(vsync: this);
  late final AnimationController _remove = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
  double _width = 360;
  bool _armed = false;
  bool _busy = false;
  double _removeFrom = 0;

  double get _openW => widget.actions.length * _buttonW;
  bool get _hasDestructive => widget.actions.isNotEmpty && widget.actions.last.destructive;
  bool get _open => _x.value < -1;
  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _x.dispose();
    _remove.dispose();
    super.dispose();
  }

  void _settle(double to) {
    if (_still) {
      _x.value = to;
    } else {
      _x.animateTo(to, duration: const Duration(milliseconds: 260), curve: Curves.easeOutCubic);
    }
    _setArmed(false);
  }

  void _setArmed(bool v) {
    if (v == _armed) return;
    if (v) HapticFeedback.mediumImpact();
    setState(() => _armed = v);
  }

  void _drag(DragUpdateDetails d) {
    if (_busy) return;
    var next = _x.value + d.delta.dx;
    if (next > 0) next = 0;
    // Past the buttons the card drags on freely only when a long swipe can delete; otherwise it resists.
    if (!_hasDestructive && next < -_openW) next = _x.value + d.delta.dx * 0.3;
    _x.value = math.max(next, -_width);
    _setArmed(_hasDestructive && -_x.value > _width * 0.6);
  }

  void _dragEnd(DragEndDetails d) {
    if (_busy) return;
    if (_armed) {
      _press(widget.actions.last);
    } else if (-_x.value > _openW / 2 || d.velocity.pixelsPerSecond.dx < -400) {
      _settle(-_openW);
    } else {
      _settle(0);
    }
  }

  Future<void> _press(SwipeAction a) async {
    if (_busy) return;
    _busy = true;
    if (!a.destructive) _settle(0);
    final gone = await a.onPressed();
    if (!mounted) return;
    _busy = false;
    if (!a.destructive || !gone) {
      if (a.destructive) _settle(0);
      return;
    }
    _busy = true;
    _removeFrom = _x.value;
    if (_still) {
      widget.onRemoved?.call();
      return;
    }
    await _remove.forward(from: 0);
    if (mounted) widget.onRemoved?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.actions.isEmpty) return widget.child;
    return LayoutBuilder(builder: (context, box) {
      _width = box.maxWidth;
      return AnimatedBuilder(
        animation: Listenable.merge([_x, _remove]),
        builder: (context, _) {
          final v = _remove.value;
          // Removal: the card flies off (0–0.3), then the gap closes on a spring (ω₀ 15, ζ 0.62).
          final dx = v == 0 ? _x.value : _removeFrom + (-_width - 40 - _removeFrom) * _easeIn(_seg(v, 0, 0.3));
          final close = v == 0 ? 0.0 : springAt(_seg(v, 0.3, 1) * 0.8, 15, 0.62);
          final fold = _seg(v, 0.3, 0.6);
          final revealed = -dx;
          return ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: (1 - close).clamp(0.0, 1.0),
              child: Stack(children: [
                if (revealed > 0.5)
                  Positioned.fill(
                    child: Opacity(
                      opacity: 1 - fold,
                      child: ClipRRect(borderRadius: widget.radius, child: _buttons(revealed)),
                    ),
                  ),
                Transform.translate(
                  offset: Offset(dx, 0),
                  child: GestureDetector(
                    behavior: HitTestBehavior.translucent,
                    onHorizontalDragUpdate: _drag,
                    onHorizontalDragEnd: _dragEnd,
                    // While open, a tap on the card closes it instead of opening the record.
                    onTap: _open ? () => _settle(0) : null,
                    child: AbsorbPointer(absorbing: _open, child: widget.child),
                  ),
                ),
              ]),
            ),
          );
        },
      );
    });
  }

  Widget _buttons(double revealed) {
    final n = widget.actions.length;
    return LayoutBuilder(builder: (context, box) {
      final shown = math.min(revealed, box.maxWidth);
      return TweenAnimationBuilder<double>(
        tween: Tween(end: _armed ? 1 : 0),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        builder: (context, arm, _) {
          // Armed, the destructive button grows over the others to take the whole revealed width.
          final other = shown / n * (1 - arm);
          return Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < n; i++)
                SizedBox(
                  width: i == n - 1 ? shown - other * (n - 1) : other,
                  child: _button(widget.actions[i], revealed),
                ),
            ],
          );
        },
      );
    });
  }

  /// A round button with its name under it. It grows in as its slot is revealed; armed, the
  /// destructive one stretches into a pill across the whole revealed width.
  Widget _button(SwipeAction a, double revealed) {
    const d = 52.0;
    final lift = a.destructive ? _seg(revealed, _openW * 0.6, _openW) * 0.5 + (_armed ? 0.2 : 0) : 0.0;
    return Semantics(
      button: true,
      label: a.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _press(a),
        child: LayoutBuilder(builder: (context, box) {
          final room = box.maxWidth - 16;
          // Only an armed swipe widens the destructive slot past a normal button's width.
          final stretched = a.destructive && box.maxWidth > _buttonW + 1;
          final size = stretched ? d : room.clamp(0.0, d);
          final shadow = (a.destructive ? deleteRed : a.color).withValues(alpha: 0.35);
          return Center(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: stretched ? CrossAxisAlignment.end : CrossAxisAlignment.center,
                children: [
                  Container(
                    width: stretched ? room : size,
                    height: size,
                    alignment: stretched ? Alignment.centerRight : Alignment.center,
                    padding: stretched ? const EdgeInsets.only(right: (d - 28) / 2) : null,
                    decoration: ShapeDecoration(
                      shape: const StadiumBorder(),
                      color: a.destructive ? null : a.color,
                      gradient: a.destructive ? const LinearGradient(colors: [_redLeft, _redRight]) : null,
                      shadows: [BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 4))],
                    ),
                    child: size < 20
                        ? null
                        : a.destructive
                            ? CustomPaint(size: const Size(28, 28), painter: BinPainter(lid: -lift))
                            : Icon(a.icon, color: Colors.white, size: 24),
                  ),
                  const SizedBox(height: 6),
                  // The name fades in once there is room for it; on the pill it sits under the bin.
                  Opacity(
                    opacity: _seg(box.maxWidth, 44, _buttonW),
                    child: SizedBox(
                      width: stretched ? d + 24 : math.min(box.maxWidth, _buttonW),
                      child: Text(
                        a.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
}

/// A white bin whose lid tilts open by [lid] radians (negative lifts the right side).
class BinPainter extends CustomPainter {
  final double lid;
  BinPainter({required this.lid});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.save();
    canvas.translate(size.width / 2, size.height / 2 + s * 0.06);
    canvas.drawPath(
      Path()
        ..moveTo(-0.32 * s, -0.16 * s)
        ..lineTo(-0.25 * s, 0.44 * s)
        ..lineTo(0.25 * s, 0.44 * s)
        ..lineTo(0.32 * s, -0.16 * s)
        ..moveTo(-0.08 * s, -0.02 * s)
        ..lineTo(-0.06 * s, 0.3 * s)
        ..moveTo(0.08 * s, -0.02 * s)
        ..lineTo(0.06 * s, 0.3 * s),
      p,
    );
    canvas.translate(-0.42 * s, -0.28 * s);
    canvas.rotate(lid);
    canvas.drawPath(
      Path()
        ..moveTo(0, 0)
        ..lineTo(0.84 * s, 0)
        ..moveTo(0.28 * s, 0)
        ..lineTo(0.30 * s, -0.16 * s)
        ..lineTo(0.54 * s, -0.16 * s)
        ..lineTo(0.56 * s, 0),
      p,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(BinPainter old) => old.lid != lid;
}
