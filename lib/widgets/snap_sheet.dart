import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import 'tones.dart';

/// The three heights a [showSnapSheet] rests at.
enum SnapHeight { peek, half, full }

/// Share of the space below the status bar each height takes.
const _snapShare = {SnapHeight.peek: 0.42, SnapHeight.half: 0.64, SnapHeight.full: 1.0};

/// Let go part-way, the sheet springs on into a height, overshooting it a little.
final _spring = SpringDescription.withDampingRatio(mass: 1, stiffness: 225, ratio: 0.6);

/// A bottom sheet dragged by its handle between Peek, Half and Full. Let go, it springs into the
/// nearest height in the direction it was moving; flung down from Peek, it closes. The app behind
/// dims more the higher it goes. Pops with a value like any route (`Navigator.pop(context, value)`).
Future<T?> showSnapSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  SnapHeight initial = SnapHeight.half,
}) =>
    Navigator.of(context, rootNavigator: true).push(_SnapSheetRoute<T>(
      builder: builder,
      initial: initial,
      label: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    ));

class _SnapSheetRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final SnapHeight initial;
  final String label;
  _SnapSheetRoute({required this.builder, required this.initial, required this.label});

  @override
  Color? get barrierColor => null; // the sheet draws its own dim, which follows its height

  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => label;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 260);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      _SnapSheet(route: this);
}

class _SnapSheet extends StatefulWidget {
  final _SnapSheetRoute route;
  const _SnapSheet({required this.route});

  @override
  State<_SnapSheet> createState() => _SnapSheetState();
}

class _SnapSheetState extends State<_SnapSheet> with SingleTickerProviderStateMixin {
  /// The sheet's height in px; unbounded, so the spring can overshoot.
  late final AnimationController _h = AnimationController.unbounded(vsync: this);
  late SnapHeight _at = widget.route.initial;
  Map<SnapHeight, double> _heights = const {};
  bool _started = false;
  bool _dragging = false;

  @override
  void dispose() {
    _h.dispose();
    super.dispose();
  }

  double _heightOf(SnapHeight s) => _heights[s]!;

  void _snapTo(SnapHeight s, {double velocity = 0}) {
    _at = s;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _h.value = _heightOf(s);
      return;
    }
    _h.animateWith(SpringSimulation(_spring, _h.value, _heightOf(s), velocity));
  }

  void _close() => Navigator.of(context).maybePop();

  void _dragBy(double dy) {
    _dragging = true;
    _h.stop();
    final full = _heightOf(SnapHeight.full);
    var h = _h.value - dy;
    if (h > full) h = full + (h - full) * 0.3; // stiff past the top
    _h.value = h.clamp(0, full + 40);
  }

  /// [velocity] in px/s, positive upwards. Goes one height in the direction of a fling, else the nearest.
  void _release(double velocity) {
    _dragging = false;
    final h = _h.value;
    final order = SnapHeight.values;
    SnapHeight target;
    if (velocity.abs() > 500) {
      final up = velocity > 0;
      target = up
          ? order.firstWhere((s) => _heightOf(s) > h + 1, orElse: () => SnapHeight.full)
          : order.reversed.firstWhere((s) => _heightOf(s) < h - 1, orElse: () => SnapHeight.peek);
      if (!up && h < _heightOf(SnapHeight.peek) + 1) return _close();
    } else {
      if (h < _heightOf(SnapHeight.peek) * 0.6) return _close();
      target = order.reduce((a, b) => (_heightOf(a) - h).abs() <= (_heightOf(b) - h).abs() ? a : b);
    }
    _snapTo(target, velocity: velocity);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final scheme = Theme.of(context).colorScheme;
    return LayoutBuilder(builder: (context, box) {
      final room = box.maxHeight - mq.padding.top - 8;
      _heights = {for (final e in _snapShare.entries) e.key: room * e.value};
      if (!_started) {
        _started = true;
        _h.value = _heightOf(_at);
      } else if (!_dragging && !_h.isAnimating && (_h.value - _heightOf(_at)).abs() > 0.5) {
        _h.value = _heightOf(_at); // rotated or resized: stay at the same named height
      }
      // A keyboard needs the room: go to the top.
      if (mq.viewInsets.bottom > 0 && _at != SnapHeight.full) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _at != SnapHeight.full) _snapTo(SnapHeight.full);
        });
      }
      final peek = _heightOf(SnapHeight.peek), full = _heightOf(SnapHeight.full);
      final enter = widget.route.animation!;
      return AnimatedBuilder(
        animation: Listenable.merge([_h, enter]),
        child: _body(context, scheme),
        builder: (context, body) {
          final open = enter.status == AnimationStatus.reverse
              ? Curves.easeInCubic.transform(enter.value)
              : Curves.easeOutBack.transform(enter.value);
          final h = _h.value;
          final dim = (0.18 + 0.42 * ((h - peek) / (full - peek)).clamp(0.0, 1.0)) * enter.value.clamp(0.0, 1.0);
          return Stack(children: [
            Positioned.fill(
              child: Semantics(
                label: widget.route.label,
                button: true,
                child: GestureDetector(
                  onTap: _close,
                  child: ColoredBox(color: const Color(0xFF05050A).withValues(alpha: dim)),
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              // Runs 80px past the bottom, so an overshoot never shows a gap.
              top: box.maxHeight - h * open,
              height: h + 80,
              child: body!,
            ),
          ]);
        },
      );
    });
  }

  Widget _body(BuildContext context, ColorScheme scheme) {
    return Material(
      color: scheme.surfaceContainer,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        side: BorderSide(color: scheme.hairline, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      shadowColor: Colors.black,
      child: Column(children: [
          // The handle: the sheet's grip.
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragUpdate: (d) => _dragBy(d.delta.dy),
            onVerticalDragEnd: (d) => _release(-d.velocity.pixelsPerSecond.dy),
            child: Semantics(
              label: 'Drag handle',
              child: SizedBox(
                height: 28,
                width: double.infinity,
                child: Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(color: scheme.onSurfaceVariant.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2.5)),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            // Pulling the content down past its top drags the sheet too.
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is OverscrollNotification && n.dragDetails != null && n.overscroll < 0) {
                  _dragBy(-n.overscroll);
                } else if (n is ScrollEndNotification && _dragging) {
                  _release(-(n.dragDetails?.velocity.pixelsPerSecond.dy ?? 0));
                }
                return false;
              },
              child: Padding(
                padding: const EdgeInsets.only(bottom: 80), // the part past the screen's bottom
                // The sheet starts below the status bar.
                child: MediaQuery.removePadding(context: context, removeTop: true, child: Builder(builder: widget.route.builder)),
              ),
            ),
          ),
        ]),
    );
  }
}
