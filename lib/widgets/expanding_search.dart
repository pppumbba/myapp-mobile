import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet;

double _seg(double x, double a, double b) => ((x - a) / (b - a)).clamp(0.0, 1.0);
double _easeIO(double k) {
  k = k.clamp(0.0, 1.0);
  return k < 0.5 ? 4 * k * k * k : 1 - math.pow(-2 * k + 2, 3) / 2;
}

/// 0 → 1, overshooting to about 1.12 near the middle.
double easeBack(double k) {
  k = k.clamp(0.0, 1.0);
  return 1 + 2.9 * math.pow(k - 1, 3) + 1.9 * math.pow(k - 1, 2);
}

/// A round gradient search button that stretches left into a full search bar when tapped.
/// It folds back when it loses focus while empty, or when × is pressed on an empty bar.
class ExpandingSearch extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  final double height;

  /// Shown at the left while the bar is closed (the screen's title); the bar covers it as it stretches.
  final Widget? behind;

  /// Always a full bar: it never folds into the button, and × only clears.
  final bool alwaysOpen;

  /// Takes the keyboard as soon as it shows (with [alwaysOpen], e.g. the lookup picker).
  final bool autofocus;
  const ExpandingSearch({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.hint,
    this.height = 48,
    this.behind,
    this.alwaysOpen = false,
    this.autofocus = false,
  });

  @override
  State<ExpandingSearch> createState() => _ExpandingSearchState();
}

class _ExpandingSearchState extends State<ExpandingSearch> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
    reverseDuration: const Duration(milliseconds: 350),
    // Opens with a search already typed (e.g. after coming back to the tab).
    value: widget.controller.text.isEmpty && !widget.alwaysOpen ? 0 : 1,
  );
  final _focus = FocusNode();
  bool _down = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (mounted) setState(() {}); // the rim brightens while typing
      if (!_focus.hasFocus && widget.controller.text.isEmpty) _close();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    _focus.dispose();
    super.dispose();
  }

  bool get _still => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  void _open() {
    _still ? _c.value = 1 : _c.forward();
    _focus.requestFocus();
  }

  void _close() {
    if (widget.alwaysOpen) {
      if (_focus.hasFocus) _focus.unfocus();
      return;
    }
    if (_focus.hasFocus) _focus.unfocus();
    _still ? _c.value = 0 : _c.reverse();
  }

  void _clear() {
    if (widget.controller.text.isEmpty) return _close();
    widget.controller.clear();
    widget.onChanged('');
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final h = widget.height;
    return SizedBox(
      height: h,
      child: LayoutBuilder(builder: (context, box) {
        final maxW = box.maxWidth;
        return AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final opening = _c.status == AnimationStatus.forward || _c.status == AnimationStatus.completed;
            // Stretches with a little overshoot, folds back smoothly.
            final e = opening ? easeBack(_c.value) : _easeIO(_c.value);
            final ec = e.clamp(0.0, 1.0);
            final w = (h + (maxW - h) * math.min(e, 1)) * (1 + 0.02 * math.max(0, e - 1));
            final ga = 1 - _seg(ec, 0, 0.4); // the coloured button fading into the bar
            final open = ec > 0.6;
            final textA = _seg(ec, 0.8, 1);
            // On the light page the open bar keeps a quiet rim (like the menu search), brighter while typing.
            final light = Theme.of(context).brightness == Brightness.light;
            final rim = ec * (light ? (_focus.hasFocus ? 0.7 : 0.28) : 1);

            final bar = Container(
              width: w,
              height: h,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(h / 2),
                gradient: LinearGradient(colors: [
                  pillViolet.withValues(alpha: rim),
                  pillCyan.withValues(alpha: rim),
                ]),
                boxShadow: [
                  // Kept small: the title bar above would cut off a wider glow.
                  if (ec > 0 && (!light || _focus.hasFocus)) BoxShadow(color: pillViolet.withValues(alpha: (light ? 0.1 : 0.18) * ec), blurRadius: 6),
                  if (ga > 0) BoxShadow(color: pillViolet.withValues(alpha: 0.4 * ga), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(h / 2),
                  color: scheme.surfaceContainerHigh,
                  gradient: ga > 0
                      ? LinearGradient(colors: [
                          Color.lerp(scheme.surfaceContainerHigh, pillViolet, ga)!,
                          Color.lerp(scheme.surfaceContainerHigh, pillCyan, ga)!,
                        ])
                      : null,
                ),
                child: Stack(children: [
                  // The icon keeps its place at the bar's left end, so it travels with the stretch.
                  Positioned(
                    left: (h - 4) / 2 - 12,
                    top: 0,
                    bottom: 0,
                    child: Icon(Icons.search, size: 24, color: Color.lerp(Colors.white, scheme.onSurfaceVariant, ec)),
                  ),
                  if (open)
                    Positioned(
                      left: h - 4 + 2,
                      right: h - 8,
                      top: 0,
                      bottom: 0,
                      child: Opacity(
                        opacity: textA,
                        child: Center(
                          child: TextField(
                            controller: widget.controller,
                            focusNode: _focus,
                            autofocus: widget.autofocus,
                            onChanged: (s) {
                              widget.onChanged(s);
                              setState(() {});
                            },
                            onTapOutside: (_) => _focus.unfocus(),
                            textInputAction: TextInputAction.search,
                            cursorColor: pillCyan,
                            decoration: InputDecoration(
                              hintText: widget.hint,
                              isDense: true,
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                  if (open && (!widget.alwaysOpen || widget.controller.text.isNotEmpty))
                    Positioned(
                      right: 4,
                      top: 0,
                      bottom: 0,
                      child: Opacity(
                        opacity: textA,
                        child: Center(
                          child: IconButton(
                            tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                            visualDensity: VisualDensity.compact,
                            style: IconButton.styleFrom(backgroundColor: scheme.surfaceContainerHighest),
                            iconSize: 16,
                            onPressed: _clear,
                            icon: const Icon(Icons.close),
                          ),
                        ),
                      ),
                    ),
                ]),
              ),
            );

            final button = OverflowBox(
              minWidth: 0,
              maxWidth: double.infinity,
              alignment: Alignment.centerRight,
              child: open
                  ? bar
                  : Tooltip(
                      message: widget.hint,
                      child: Semantics(
                        button: true,
                        label: widget.hint,
                        excludeSemantics: true,
                        child: GestureDetector(
                          onTapDown: (_) => setState(() => _down = true),
                          onTapCancel: () => setState(() => _down = false),
                          onTapUp: (_) => setState(() => _down = false),
                          onTap: _open,
                          // Squeezes a little under the finger.
                          child: AnimatedScale(
                            scale: _down ? 0.88 : 1,
                            duration: Duration(milliseconds: _down ? 90 : 260),
                            curve: _down ? Curves.easeOut : Curves.elasticOut,
                            child: bar,
                          ),
                        ),
                      ),
                    ),
            );
            if (widget.behind == null) return button;
            final ba = 1 - _seg(ec, 0, 0.5);
            return Stack(children: [
              if (ba > 0)
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  right: h + 8,
                  child: IgnorePointer(child: Opacity(opacity: ba, child: Align(alignment: Alignment.centerLeft, child: widget.behind))),
                ),
              button,
            ]);
          },
        );
      }),
    );
  }
}
