import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet;

/// An outline that, at [glow] > 0, lays a glowing violet → cyan stroke (or [color]) over the
/// plain one, keeping the gap the floating label sits in. Focus animates [glow] 0 → 1.
class GlowOutlineBorder extends OutlineInputBorder {
  final double glow;
  final Color? color;

  const GlowOutlineBorder({
    super.borderSide = const BorderSide(color: Color(0x24FFFFFF), width: 2),
    super.borderRadius = const BorderRadius.all(Radius.circular(12)),
    super.gapPadding,
    this.glow = 0,
    this.color,
  });

  @override
  GlowOutlineBorder copyWith({BorderSide? borderSide, BorderRadius? borderRadius, double? gapPadding, double? glow, Color? color}) =>
      GlowOutlineBorder(
        borderSide: borderSide ?? this.borderSide,
        borderRadius: borderRadius ?? this.borderRadius,
        gapPadding: gapPadding ?? this.gapPadding,
        glow: glow ?? this.glow,
        color: color ?? this.color,
      );

  @override
  ShapeBorder? lerpFrom(ShapeBorder? a, double t) {
    if (a is GlowOutlineBorder) return _lerp(a, this, t);
    return super.lerpFrom(a, t);
  }

  @override
  ShapeBorder? lerpTo(ShapeBorder? b, double t) {
    if (b is GlowOutlineBorder) return _lerp(this, b, t);
    return super.lerpTo(b, t);
  }

  static GlowOutlineBorder _lerp(GlowOutlineBorder a, GlowOutlineBorder b, double t) => GlowOutlineBorder(
        borderSide: BorderSide.lerp(a.borderSide, b.borderSide, t),
        borderRadius: BorderRadius.lerp(a.borderRadius, b.borderRadius, t)!,
        gapPadding: lerpDouble(a.gapPadding, b.gapPadding, t)!,
        glow: lerpDouble(a.glow, b.glow, t)!,
        color: t < 0.5 ? a.color ?? b.color : b.color ?? a.color,
      );

  @override
  void paint(Canvas canvas, Rect rect, {double? gapStart, double gapExtent = 0.0, double gapPercentage = 0.0, TextDirection? textDirection}) {
    super.paint(canvas, rect, gapStart: gapStart, gapExtent: gapExtent, gapPercentage: gapPercentage, textDirection: textDirection);
    if (glow <= 0) return;
    final shape = borderRadius.toRRect(rect);
    canvas.save();
    if (gapStart != null && gapExtent > 0 && gapPercentage > 0) {
      // Keep the label's gap open: the same span the plain outline leaves out.
      final extent = lerpDouble(0.0, gapExtent + gapPadding * 2.0, gapPercentage)!;
      final start = textDirection == TextDirection.rtl ? gapStart + gapPadding - extent : gapStart - gapPadding;
      final gap = Rect.fromLTWH(rect.left + math.max(0.0, start), rect.top - 8, extent, 16);
      canvas.clipPath(Path.combine(PathOperation.difference, Path()..addRect(rect.inflate(24)), Path()..addRect(gap)));
    }
    final alpha = glow.clamp(0.0, 1.0);
    final glowPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = (color ?? pillViolet).withValues(alpha: 0.45 * alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawRRect(shape, glowPaint);
    final stroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    if (color != null) {
      stroke.color = color!.withValues(alpha: color!.a * alpha);
    } else {
      stroke.shader = LinearGradient(colors: [pillViolet.withValues(alpha: alpha), pillCyan.withValues(alpha: alpha)])
          .createShader(rect);
    }
    canvas.drawRRect(shape, stroke);
    canvas.restore();
  }

  @override
  bool operator ==(Object other) => other is GlowOutlineBorder && super == other && other.glow == glow && other.color == color;

  @override
  int get hashCode => Object.hash(super.hashCode, glow, color);
}

/// The outline set for a form field: plain at rest, glowing on focus, red with an error.
InputDecoration withGlowBorders(InputDecoration d, ColorScheme scheme) => d.copyWith(
      border: const GlowOutlineBorder(),
      enabledBorder: const GlowOutlineBorder(),
      focusedBorder: const GlowOutlineBorder(glow: 1),
      errorBorder: GlowOutlineBorder(borderSide: BorderSide(color: scheme.error.withValues(alpha: 0.7), width: 2)),
      focusedErrorBorder: GlowOutlineBorder(glow: 1, color: scheme.error),
      disabledBorder: const GlowOutlineBorder(borderSide: BorderSide(color: Color(0x14FFFFFF), width: 2)),
    );
