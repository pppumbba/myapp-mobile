import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet, springAt;

double _easeInOutCubic(double k) {
  k = k.clamp(0.0, 1.0);
  return k < 0.5 ? 4 * k * k * k : 1 - math.pow(-2 * k + 2, 3) / 2;
}

/// The underline's edges [dt] seconds after a tap, moving from [from] to [to] (each a left/right
/// pair in px). The leading edge reaches the new label first and the trailing edge catches up.
({double left, double right}) inchwormEdges(double dt, ({double left, double right}) from, ({double left, double right}) to) {
  final lead = _easeInOutCubic(dt / 0.28), trail = _easeInOutCubic((dt - 0.12) / 0.3);
  final right = to.left > from.left;
  final l = right ? trail : lead, r = right ? lead : trail;
  return (left: from.left + (to.left - from.left) * l, right: from.right + (to.right - from.right) * r);
}

const _labelStyle = TextStyle(fontSize: 15, fontWeight: FontWeight.w600);
const _tabPad = 16.0;

/// A row of text tabs with a gradient underline that inches from one label to the next.
/// Scrolls sideways when the labels don't fit.
class InchwormTabBar extends StatefulWidget {
  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;
  const InchwormTabBar({super.key, required this.labels, required this.index, required this.onTap});

  @override
  State<InchwormTabBar> createState() => _InchwormTabBarState();
}

class _InchwormTabBarState extends State<InchwormTabBar> with SingleTickerProviderStateMixin {
  static const _span = Duration(milliseconds: 450);
  late final AnimationController _clock = AnimationController(vsync: this, duration: _span, value: 1);
  late int _from = widget.index;
  final _scroll = ScrollController();

  @override
  void didUpdateWidget(InchwormTabBar old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = old.index;
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
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scale = MediaQuery.textScalerOf(context);
    final dir = Directionality.of(context);
    // Each tab is its label plus padding; the underline spans the label plus 5 px a side.
    final textW = [
      for (final s in widget.labels)
        (TextPainter(text: TextSpan(text: s, style: _labelStyle), textDirection: dir, textScaler: scale, maxLines: 1)..layout()).width,
    ];
    final starts = <double>[];
    var x = 0.0;
    for (final w in textW) {
      starts.add(x);
      x += w + 2 * _tabPad;
    }
    final n = widget.labels.length;
    ({double left, double right}) edges(int i) {
      i = i.clamp(0, n - 1);
      final c = starts[i] + _tabPad + textW[i] / 2, h = (textW[i] + 10) / 2;
      return (left: c - h, right: c + h);
    }

    final gray = theme.colorScheme.onSurfaceVariant, ink = theme.colorScheme.onSurface;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Stack(children: [
        Positioned(
          left: 14,
          right: 14,
          bottom: 0,
          child: Container(height: 1.5, color: theme.colorScheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        SingleChildScrollView(
          controller: _scroll,
          scrollDirection: Axis.horizontal,
          child: AnimatedBuilder(
            animation: _clock,
            builder: (context, _) {
              final e = inchwormEdges(_clock.value * _span.inMilliseconds / 1000, edges(_from), edges(widget.index));
              final mid = (e.left + e.right) / 2;
              return SizedBox(
                width: x,
                height: 48,
                child: Stack(children: [
                  Row(children: [
                    for (var i = 0; i < n; i++)
                      Semantics(
                        button: true,
                        selected: i == widget.index,
                        // No splash or highlight: the inchworm moving is the feedback.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => widget.onTap(i),
                          child: SizedBox(
                            width: textW[i] + 2 * _tabPad,
                            height: 48,
                            child: Center(
                              child: Text(
                                widget.labels[i],
                                maxLines: 1,
                                style: _labelStyle.copyWith(
                                  color: Color.lerp(gray, ink, (1 - (mid - (starts[i] + _tabPad + textW[i] / 2)).abs() / 80).clamp(0.0, 1.0)),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ]),
                  if (e.right > e.left)
                    Positioned(
                      left: e.left,
                      width: e.right - e.left,
                      bottom: 2,
                      height: 4,
                      child: const IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.all(Radius.circular(2)),
                            gradient: LinearGradient(colors: [pillViolet, pillCyan]),
                            boxShadow: [BoxShadow(color: Color(0xB36E5BFF), blurRadius: 8)],
                          ),
                        ),
                      ),
                    ),
                ]),
              );
            },
          ),
        ),
      ]),
    );
  }
}

/// Pages side by side that slide to [index] on a spring. Only the pages in view are built.
class SpringPages extends StatefulWidget {
  final int index;
  final int count;
  final Widget Function(BuildContext, int) builder;
  const SpringPages({super.key, required this.index, required this.count, required this.builder});

  @override
  State<SpringPages> createState() => _SpringPagesState();
}

class _SpringPagesState extends State<SpringPages> with SingleTickerProviderStateMixin {
  static const _span = Duration(milliseconds: 1000);
  late final AnimationController _clock = AnimationController(vsync: this, duration: _span, value: 1);
  late int _from = widget.index;

  @override
  void didUpdateWidget(SpringPages old) {
    super.didUpdateWidget(old);
    if (old.index != widget.index) {
      _from = old.index;
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
    return ClipRect(
      child: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        return AnimatedBuilder(
          animation: _clock,
          builder: (context, _) {
            final to = widget.index.clamp(0, widget.count - 1), from = _from.clamp(0, widget.count - 1);
            final done = _clock.value >= 1;
            final pg = done ? to.toDouble() : from + (to - from) * springAt(_clock.value * _span.inMilliseconds / 1000, 13, 0.82);
            final first = pg.floor().clamp(0, widget.count - 1), last = pg.ceil().clamp(0, widget.count - 1);
            return Stack(children: [
              for (var i = first; i <= last; i++)
                Positioned(
                  key: ValueKey(i),
                  left: (i - pg) * w,
                  width: w,
                  top: 0,
                  bottom: 0,
                  child: widget.builder(context, i),
                ),
            ]);
          },
        );
      }),
    );
  }
}
