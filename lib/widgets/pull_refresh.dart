import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter/services.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet, springAt;

const refreshMint = Color(0xFF3DDBB0);

enum _Phase { idle, pulling, refreshing, done, closing }

double _easeIO(double k) {
  k = k.clamp(0.0, 1.0);
  return k < 0.5 ? 4 * k * k * k : 1 - math.pow(-2 * k + 2, 3) / 2;
}

/// How far the list moves for a finger pull of [raw] px: it follows the finger, then resists.
double pullOffset(double raw) => raw <= 0 ? 0 : 120 * (1 - math.exp(-raw / 160));

/// Pull a list down to refresh it. A ring fills as you pull, spins while [onRefresh] runs,
/// turns into a check, and the gap closes. [child] must be a scrollable that can always scroll.
class PullRefresh extends StatefulWidget {
  final Widget child;
  final Future<void> Function() onRefresh;
  const PullRefresh({super.key, required this.child, required this.onRefresh});

  /// Pull past this many px of list offset and let go to refresh.
  static const armAt = 58.0;

  @override
  State<PullRefresh> createState() => _PullRefreshState();
}

class _PullRefreshState extends State<PullRefresh> with TickerProviderStateMixin {
  late final AnimationController _settle = AnimationController(vsync: this);
  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
  late final AnimationController _check = AnimationController(vsync: this, duration: const Duration(milliseconds: 160));
  _Phase _phase = _Phase.idle;
  double _raw = 0;
  double _from = 0; // list offset when the current settle started
  bool _armed = false;

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _settle.dispose();
    _spin.dispose();
    _check.dispose();
    super.dispose();
  }

  /// The list's offset from the top, by phase.
  double get _offset {
    final t = _settle.value;
    return switch (_phase) {
      _Phase.idle => 0,
      _Phase.pulling => pullOffset(_raw),
      // Released past the mark: spring back to the refresh height (ω₀ 24, ζ 0.55).
      _Phase.refreshing || _Phase.done => PullRefresh.armAt + (_from - PullRefresh.armAt) * (1 - springAt(t * 0.5, 24, 0.55)),
      _Phase.closing => _from * (1 - _easeIO(t)),
    };
  }

  bool _onScroll(ScrollNotification n) {
    if (n.depth != 0 || _phase == _Phase.refreshing || _phase == _Phase.done) return false;
    final dragging = switch (n) {
      ScrollUpdateNotification(:final dragDetails) => dragDetails != null,
      OverscrollNotification(:final dragDetails) => dragDetails != null,
      _ => false,
    };
    if (n is OverscrollNotification && dragging && n.overscroll < 0 && n.metrics.extentBefore == 0) {
      // Clamping lists (Android) report the pull as overscroll.
      _pullBy(-n.overscroll);
    } else if (n is ScrollUpdateNotification && dragging && n.metrics.pixels < 0) {
      // Bouncing lists (iOS) move past the top themselves.
      _pullBy(-n.metrics.pixels - _raw);
    } else if (n is ScrollUpdateNotification && dragging && _raw > 0 && (n.scrollDelta ?? 0) > 0) {
      _pullBy(-(n.scrollDelta ?? 0));
    } else if (n is ScrollEndNotification || (n is UserScrollNotification && n.direction == ScrollDirection.idle)) {
      if (_phase == _Phase.pulling) _release();
    }
    return false;
  }

  void _pullBy(double d) {
    _settle.stop();
    setState(() {
      _phase = _Phase.pulling;
      _raw = math.max(0, _raw + d);
    });
    final armed = pullOffset(_raw) >= PullRefresh.armAt;
    if (armed && !_armed) HapticFeedback.lightImpact();
    _armed = armed;
  }

  Future<void> _release() async {
    final at = pullOffset(_raw);
    _raw = 0;
    _armed = false;
    if (at < PullRefresh.armAt) {
      await _close(at);
      return;
    }
    setState(() {
      _phase = _Phase.refreshing;
      _from = at;
    });
    _check.value = 0;
    if (!_still) {
      _spin.repeat();
      _settle.duration = const Duration(milliseconds: 600);
      _settle.forward(from: 0);
    } else {
      _settle.value = 1;
    }
    final started = DateTime.now();
    try {
      await widget.onRefresh();
    } catch (_) {
      // The list shows its own error; the indicator just closes.
    }
    // Spin at least a moment so a fast answer still reads as a refresh.
    final left = const Duration(milliseconds: 450) - DateTime.now().difference(started);
    if (left > Duration.zero && !_still) await Future<void>.delayed(left);
    if (!mounted) return;
    _spin.stop();
    setState(() => _phase = _Phase.done);
    if (!_still) {
      await _check.forward(from: 0);
      await Future<void>.delayed(const Duration(milliseconds: 220));
    } else {
      _check.value = 1;
    }
    if (mounted) await _close(PullRefresh.armAt);
  }

  Future<void> _close(double from) async {
    setState(() {
      _phase = _Phase.closing;
      _from = from;
    });
    if (!_still) {
      _settle.duration = const Duration(milliseconds: 260);
      await _settle.forward(from: 0);
    }
    if (mounted) setState(() => _phase = _Phase.idle);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: AnimatedBuilder(
        animation: Listenable.merge([_settle, _spin, _check]),
        child: widget.child,
        builder: (context, child) {
          final l = _offset;
          final pull = (pullOffset(_raw) / PullRefresh.armAt).clamp(0.0, 1.0);
          final fade = _phase == _Phase.closing ? 1 - (_settle.value * 2).clamp(0.0, 1.0) : 1.0;
          return Stack(children: [
            if (l > 0.5 && _phase != _Phase.idle)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: l + 3,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    maxHeight: double.infinity,
                    child: Padding(
                      padding: EdgeInsets.only(top: math.max(l / 2, 26) - 17),
                      child: Opacity(
                        opacity: (_phase == _Phase.pulling ? (pull * 1.6).clamp(0.0, 1.0) : 1.0) * fade,
                        child: Semantics(
                          label: MaterialLocalizations.of(context).refreshIndicatorSemanticLabel,
                          child: CustomPaint(
                            size: const Size(34, 34),
                            painter: _RingPainter(
                              pull: _phase == _Phase.pulling ? pull : 1,
                              spin: _phase == _Phase.refreshing ? _spin.value : null,
                              done: _phase == _Phase.done || _phase == _Phase.closing ? _check.value : 0,
                              track: scheme.outlineVariant,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Transform.translate(offset: Offset(0, l), child: child),
          ]);
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double pull;
  final double? spin;
  final double done;
  final Color track;
  _RingPainter({required this.pull, required this.spin, required this.done, required this.track});

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 14.0;
    final pop = done > 0 ? 0.85 + 0.15 * (1 + 2.9 * math.pow(done - 1, 3) + 1.9 * math.pow(done - 1, 2)) : 1.0;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.scale(pop);
    canvas.drawCircle(
      Offset.zero,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = Color.lerp(track, refreshMint, done)!,
    );
    if (done < 1) {
      final double len, start;
      if (spin != null) {
        len = math.pi * 2 * (0.3 + 0.35 * math.pow(math.sin(spin! * math.pi * 2), 2));
        start = -math.pi / 2 + spin! * math.pi * 4;
      } else {
        len = math.pi * 1.7 * pull;
        start = -math.pi / 2 + pull * math.pi * 0.6;
      }
      final rect = Rect.fromCircle(center: Offset.zero, radius: r);
      canvas.drawArc(
        rect,
        start,
        len,
        false,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5
          ..strokeCap = StrokeCap.round
          ..shader = const LinearGradient(colors: [pillViolet, pillCyan]).createShader(rect)
          ..color = Colors.white.withValues(alpha: 1 - done),
      );
    }
    if (done > 0) {
      const s = 20.0;
      final a = const Offset(-0.30 * s, 0.02 * s), b = const Offset(-0.09 * s, 0.23 * s), e = const Offset(0.32 * s, -0.20 * s);
      final l1 = (b - a).distance, l2 = (e - b).distance;
      var left = (l1 + l2) * done;
      final path = Path()..moveTo(a.dx, a.dy);
      final f1 = math.min(1.0, left / l1);
      path.lineTo(a.dx + (b.dx - a.dx) * f1, a.dy + (b.dy - a.dy) * f1);
      left -= l1;
      if (left > 0) {
        final f2 = math.min(1.0, left / l2);
        path.lineTo(b.dx + (e.dx - b.dx) * f2, b.dy + (e.dy - b.dy) * f2);
      }
      canvas.drawPath(
        path,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = refreshMint,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RingPainter old) => old.pull != pull || old.spin != spin || old.done != done || old.track != track;
}

/// A short violet glow over a record that a refresh just brought in. It plays when [generation]
/// changes while [active].
class NewRowGlow extends StatefulWidget {
  final bool active;
  final int generation;
  final Widget child;
  final BorderRadius radius;
  const NewRowGlow({
    super.key,
    required this.active,
    required this.generation,
    required this.child,
    this.radius = const BorderRadius.all(Radius.circular(12)),
  });

  @override
  State<NewRowGlow> createState() => _NewRowGlowState();
}

class _NewRowGlowState extends State<NewRowGlow> with SingleTickerProviderStateMixin {
  late final AnimationController _t = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200), value: 1);

  @override
  void initState() {
    super.initState();
    if (widget.active) _t.forward(from: 0);
  }

  @override
  void didUpdateWidget(NewRowGlow old) {
    super.didUpdateWidget(old);
    if (widget.active && widget.generation != old.generation) _t.forward(from: 0);
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      child: widget.child,
      builder: (context, child) {
        // Full for the first quarter, then fades out.
        final hl = 1 - ((_t.value - 0.25) / 0.6).clamp(0.0, 1.0);
        if (hl <= 0) return child!;
        return Stack(children: [
          child!,
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: widget.radius,
                  color: pillViolet.withValues(alpha: 0.14 * hl),
                  border: Border.all(color: const Color(0xFF9687FF).withValues(alpha: 0.75 * hl), width: 2),
                ),
              ),
            ),
          ),
        ]);
      },
    );
  }
}
