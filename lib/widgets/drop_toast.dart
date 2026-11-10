import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet;

double _seg(double a, double a0, double a1) => ((a - a0) / (a1 - a0)).clamp(0.0, 1.0);

double _spring(double t, double w0, double z) {
  if (t <= 0) return 0;
  final wd = w0 * math.sqrt(1 - z * z);
  return 1 - math.exp(-z * w0 * t) * (math.cos(wd * t) + (z * w0 / wd) * math.sin(wd * t));
}

/// Where the drop toast is at [a] seconds: it falls out of the top edge (0–0.36s), springs open
/// into the toast, holds until [hold] seconds, then shrinks and is pulled back up.
/// Positions are in [fall] units: 0 hidden inside the top, 1 resting.
class DropPose {
  final double fall; // drop centre, 0 (hidden) .. 1 (rest)
  final double open; // 0 drop .. 1 toast (overshoots a little)
  final double? droplet; // trailing droplet centre in fall units, or null
  final double content; // opacity of the text
  const DropPose(this.fall, this.open, this.droplet, this.content);

  factory DropPose.at(double a, {double hold = 3.0}) {
    final d = hold - 3.0; // the closing phase runs on the spec's clock, shifted by the longer hold
    final fall = a < 3.36 + d ? math.pow(_seg(a, 0, 0.36), 2).toDouble() : 1 - math.pow(_seg(a, 3.36 + d, 3.66 + d), 2).toDouble();
    final open = a < 3.15 + d ? _spring(a - 0.33, 13, 0.55) : 1 - math.pow(_seg(a, 3.15 + d, 3.36 + d), 3).toDouble();
    double? droplet;
    if (a < 0.5) {
      droplet = math.pow(_seg(a - 0.07, 0, 0.36), 2).toDouble();
    } else if (a > 3.3 + d) {
      droplet = a < 3.36 + d
          ? math.pow(_seg(a - 0.07, 0, 0.36), 2).toDouble()
          : 1 - math.pow(_seg(a + 0.07, 3.36 + d, 3.66 + d), 2).toDouble();
    }
    final content = a < 3.0 + d ? _seg(a, 0.5, 0.7) : 1 - _seg(a, 3.0 + d, 3.12 + d);
    return DropPose(fall, open, droplet, content);
  }

  /// Seconds until the drop is back inside the top edge.
  static double total({double hold = 3.0}) => 3.66 + hold - 3.0;
}

/// Shows a notification that drips out of the top of the screen as a liquid drop and spreads
/// into a toast. [onTap] runs (and the toast leaves) when it is tapped. Only one at a time.
/// [icon] goes in the white disc in place of the title's initial (a confirmation rather than a message).
void showDropToast(BuildContext context, {required String title, String? body, String time = '', IconData? icon, VoidCallback? onTap}) {
  _current?.remove();
  final overlay = Overlay.of(context, rootOverlay: true);
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => DropToast(
      title: title,
      body: body,
      time: time,
      icon: icon,
      onTap: onTap,
      onDone: () {
        if (_current == entry) _current = null;
        if (entry.mounted) entry.remove();
      },
    ),
  );
  _current = entry;
  overlay.insert(entry);
}

OverlayEntry? _current;

class DropToast extends StatefulWidget {
  final String title, time;
  final String? body;
  final VoidCallback? onTap;
  final IconData? icon;
  final VoidCallback onDone;
  final double hold;
  const DropToast({super.key, required this.title, this.body, this.time = '', this.icon, this.onTap, required this.onDone, this.hold = 4.5});

  @override
  State<DropToast> createState() => _DropToastState();
}

class _DropToastState extends State<DropToast> with SingleTickerProviderStateMixin {
  late final double _total = DropPose.total(hold: widget.hold);
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: (_total * 1000).round()),
  )..forward().whenComplete(() => widget.onDone());

  @override
  void dispose() {
    _clock.dispose();
    super.dispose();
  }

  /// Skips ahead to the closing phase (a tap leaves early).
  void _leave() {
    final closeAt = (widget.hold) / _total;
    if (_clock.value < closeAt) _clock.forward(from: closeAt);
  }

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final still = mq.disableAnimations;
    final width = math.min(mq.size.width - 32, 420.0);
    final restY = mq.padding.top + 48; // toast centre at rest
    return Positioned(
      left: 0,
      right: 0,
      top: 0,
      height: restY + 60,
      child: AnimatedBuilder(
        animation: _clock,
        builder: (context, _) {
          final a = _clock.value * _total;
          final p = DropPose.at(a, hold: widget.hold);
          if (still) {
            // No liquid: the toast just fades in and out where it rests.
            final op = a < widget.hold ? _seg(a, 0, 0.25) : 1 - _seg(a, widget.hold, widget.hold + 0.25);
            return Opacity(opacity: op, child: _body(context, width, restY, 1, 1));
          }
          final y = -20 + (restY + 20) * p.fall;
          final w = 44 + (width - 44) * p.open;
          final h = 44 + 22 * p.open.clamp(0.0, 1.0);
          final dropY = p.droplet == null ? null : -20 + (restY + 20) * p.droplet!;
          return Stack(clipBehavior: Clip.none, children: [
            Positioned.fill(
              child: IgnorePointer(
                child: RepaintBoundary(
                  child: CustomPaint(painter: _GooPainter(y: y, w: w, h: h, dropY: dropY, width: mq.size.width)),
                ),
              ),
            ),
            if (p.content > 0) Opacity(opacity: p.content, child: _body(context, w, y, p.open, 0)),
          ]);
        },
      ),
    );
  }

  /// The message on the pill: initial in a white disc, title, body, time; [fill] paints its own pill.
  Widget _body(BuildContext context, double w, double mid, double open, double fill) {
    final initial = widget.title.trim().isEmpty ? '•' : widget.title.trim().characters.first.toUpperCase();
    // The overlay sits outside any page, so the toast brings its own text styling.
    return Material(
      type: MaterialType.transparency,
      child: Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: EdgeInsets.only(top: math.max(0, mid - 33)),
        child: Semantics(
          liveRegion: true,
          button: widget.onTap != null,
          label: [widget.title, ?widget.body].join('. '),
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.onTap?.call();
              _leave();
            },
            onVerticalDragEnd: (d) {
              if ((d.primaryVelocity ?? 0) < 0) _leave();
            },
            child: Container(
              width: w,
              height: 66,
              decoration: fill > 0
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(33),
                      gradient: const LinearGradient(colors: [pillViolet, pillCyan]),
                    )
                  : null,
              padding: const EdgeInsets.only(left: 13, right: 20),
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  maxWidth: math.max(w - 33, 200),
                  child: Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: widget.icon != null
                          ? Icon(widget.icon, color: pillViolet, size: 24)
                          : Text(initial, style: const TextStyle(color: pillViolet, fontSize: 19, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600)),
                        if (widget.body?.isNotEmpty == true)
                          Text(widget.body!, maxLines: 1, overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: Colors.white.withValues(alpha: 0.82), fontSize: 14, fontWeight: FontWeight.w500)),
                      ]),
                    ),
                    const SizedBox(width: 8),
                    if (widget.time.isNotEmpty)
                      Text(widget.time, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 13, fontWeight: FontWeight.w600)),
                  ]),
                ),
              ),
            ),
          ),
        ),
      ),
      ),
    );
  }
}

/// The spout at the top edge, the drop or pill and the trailing droplet, blurred together and
/// their alpha sharpened again (×26 − 11) so they merge like liquid, filled violet → cyan with a glow.
class _GooPainter extends CustomPainter {
  final double y, w, h, width;
  final double? dropY;
  _GooPainter({required this.y, required this.w, required this.h, required this.dropY, required this.width});

  // Alpha × 26 − 11 (in 0–255 units the offset is −11 × 255).
  static const _threshold = ColorFilter.matrix(<double>[
    0, 0, 0, 0, 255, //
    0, 0, 0, 0, 255,
    0, 0, 0, 0, 255,
    0, 0, 0, 26, -11 * 255,
  ]);

  void _shapes(Canvas canvas, Paint white) {
    final cx = width / 2;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTRB(cx - 58, -30, cx + 58, 8), const Radius.circular(19)), white);
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromCenter(center: Offset(cx, y), width: w, height: h), Radius.circular(h / 2)), white);
    if (dropY != null) canvas.drawCircle(Offset(cx, dropY!), 11, white);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final white = Paint()..color = Colors.white;
    final blur = Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 8, sigmaY: 8, tileMode: TileMode.decal);
    final shader = const LinearGradient(colors: [pillViolet, pillCyan])
        .createShader(Rect.fromCenter(center: Offset(width / 2, y), width: math.max(w, 120), height: 228));

    // Glow: the same shapes, softer and violet, under the liquid.
    canvas.saveLayer(bounds, Paint()..imageFilter = ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14, tileMode: TileMode.decal));
    _shapes(canvas, Paint()..color = pillViolet.withValues(alpha: 0.45));
    canvas.restore();

    // Liquid: blur → sharpen alpha → fill with the gradient.
    canvas.saveLayer(bounds, Paint());
    canvas.saveLayer(bounds, Paint()..colorFilter = _threshold);
    canvas.saveLayer(bounds, blur);
    _shapes(canvas, white);
    canvas.restore();
    canvas.restore();
    canvas.drawRect(bounds, Paint()
      ..shader = shader
      ..blendMode = BlendMode.srcIn);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_GooPainter old) => old.y != y || old.w != w || old.h != h || old.dropY != dropY || old.width != width;
}
