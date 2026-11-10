import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// A list item that shrinks and fades away as it leaves its scroll view at the start (the top, or
/// the left of a sideways list), and grows in from nothing as it comes in at the end. [endInset]
/// is a bar drawn over the list's end (the tab bar under a vertical list): items grow in before
/// it. Off when animations are.
///
/// Worked out while painting, from where the item sits in the viewport, so nothing rebuilds while
/// scrolling; the item repaints itself as the list moves (list items sit in repaint boundaries).
class EdgeFade extends StatelessWidget {
  final Widget child;
  final double endInset;
  const EdgeFade({super.key, required this.child, this.endInset = 0});

  @override
  Widget build(BuildContext context) {
    final scrollable = Scrollable.maybeOf(context);
    if (scrollable == null || (MediaQuery.maybeDisableAnimationsOf(context) ?? false)) return child;
    return _EdgeFade(position: scrollable.position, viewport: scrollable.context, endInset: endInset, child: child);
  }
}

class _EdgeFade extends SingleChildRenderObjectWidget {
  final ScrollPosition position;
  final BuildContext viewport;
  final double endInset;
  const _EdgeFade({required this.position, required this.viewport, required this.endInset, required super.child});

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderEdgeFade(position, viewport, endInset);

  @override
  void updateRenderObject(BuildContext context, _RenderEdgeFade r) => r
    ..position = position
    ..viewport = viewport
    ..endInset = endInset;
}

class _RenderEdgeFade extends RenderProxyBox {
  _RenderEdgeFade(this._position, this.viewport, this.endInset);

  /// At most how far past an edge an item goes from whole to gone.
  static const _zone = 96.0;

  /// The smallest an item gets right at the edge.
  static const _minScale = 0.6;

  ScrollPosition _position;
  BuildContext viewport;
  double endInset;

  set position(ScrollPosition p) {
    if (p == _position) return;
    if (attached) _position.removeListener(markNeedsPaint);
    _position = p;
    if (attached) _position.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _position.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _position.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  bool get _vertical => _position.axis == Axis.vertical;

  /// 1 while the item is wholly in view; once it crosses an edge, the share of it (up to [_zone])
  /// still in view, down to 0 when it has gone. And whether that edge is the start.
  (double, bool) _shown() {
    final view = viewport.findRenderObject();
    if (view is! RenderBox || !view.attached || !hasSize) return (1, true);
    final at = localToGlobal(Offset.zero, ancestor: view);
    final start = _vertical ? at.dy : at.dx;
    final length = _vertical ? size.height : size.width;
    if (length == 0) return (1, true);
    final end = start + length;
    final floor = (_vertical ? view.size.height : view.size.width) - endInset;
    final span = length < _zone ? length : _zone;
    if (start < 0) return ((end / span).clamp(0.0, 1.0), true);
    if (end > floor) return (((floor - start) / span).clamp(0.0, 1.0), false);
    return (1, true);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final c = child;
    if (c == null) return;
    final (t, atStart) = _shown();
    if (t >= 1) {
      layer = null;
      context.paintChild(c, offset);
      return;
    }
    if (t <= 0) {
      layer = null;
      return;
    }
    final eased = Curves.easeOut.transform(t);
    final scale = lerpDouble(_minScale, 1, eased)!;
    // Shrinks into the side still in view: its far side while leaving at the start, its near
    // side while coming in at the end.
    final pivot = _vertical
        ? Offset(size.width / 2, atStart ? size.height : 0)
        : Offset(atStart ? size.width : 0, size.height / 2);
    final transform = Matrix4.identity()
      ..translateByDouble(pivot.dx, pivot.dy, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1)
      ..translateByDouble(-pivot.dx, -pivot.dy, 0, 1);
    layer = context.pushOpacity(offset, (eased * 255).round(), (context, offset) {
      context.pushTransform(needsCompositing, offset, transform, (context, offset) => context.paintChild(c, offset));
    }, oldLayer: layer as OpacityLayer?);
  }
}
