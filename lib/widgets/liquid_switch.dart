import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet;

const _w0 = 16.0, _z = 0.5;
final _wd = _w0 * math.sqrt(1 - _z * _z);

/// The damped spring every part follows: 0 → 1 with a small overshoot, settled in about 0.6s.
double liquidSpring(double t) {
  if (t <= 0) return 0;
  return 1 - math.exp(-_z * _w0 * t) * (math.cos(_wd * t) + (_z * _w0 / _wd) * math.sin(_wd * t));
}

/// A switch whose knob slides like a drop of liquid: it stretches with its speed, two droplets
/// trail it and melt into it, it squashes against the end, and the track fills violet → cyan.
class LiquidSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  const LiquidSwitch({super.key, required this.value, required this.onChanged});

  static const size = Size(60, 30);

  @override
  State<LiquidSwitch> createState() => _LiquidSwitchState();
}

class _LiquidSwitchState extends State<LiquidSwitch> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  // The spring runs from [_from] to [_to] since [_since] seconds on [_clock].
  late double _from = widget.value ? 1 : 0, _to = _from;
  // _now = _base + time since the ticker started.
  double _since = -10, _now = 0, _base = 0;

  double _at(double t) => _from + (_to - _from) * liquidSpring(t - _since);

  void _tick(Duration elapsed) {
    setState(() => _now = _base + elapsed.inMicroseconds / 1e6);
    if (_now - _since > 1.2) _ticker.stop();
  }

  @override
  void didUpdateWidget(LiquidSwitch old) {
    super.didUpdateWidget(old);
    if (old.value == widget.value) return;
    final target = widget.value ? 1.0 : 0.0;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _from = _to = target;
      return;
    }
    // Spring on from wherever it is now.
    _from = _at(_now);
    _to = target;
    _since = _now;
    if (!_ticker.isActive) {
      _base = _now;
      _ticker.start();
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _at(_now);
    final speed = (_at(_now + 0.004) - _at(_now - 0.004)) / 0.008;
    final enabled = widget.onChanged != null;
    return Semantics(
      toggled: widget.value,
      enabled: enabled,
      child: GestureDetector(
        onTap: enabled ? () => widget.onChanged!(!widget.value) : null,
        child: Opacity(
          opacity: enabled ? 1 : 0.5,
          child: CustomPaint(
            size: LiquidSwitch.size,
            painter: LiquidSwitchPainter(
              p: p,
              speed: speed,
              trail1: _at(_now - 0.045),
              trail2: _at(_now - 0.095),
              dark: Theme.of(context).brightness == Brightness.dark,
            ),
          ),
        ),
      ),
    );
  }
}

/// Paints the switch at on-amount [p] (may overshoot), knob speed [speed] (per second) and the
/// two droplets' on-amounts. Drawn on the spec's 236×118 track, scaled to the size.
class LiquidSwitchPainter extends CustomPainter {
  final double p, speed, trail1, trail2;
  /// The off track: deep on the dark theme, pale on the light one.
  final bool dark;
  LiquidSwitchPainter({required this.p, required this.speed, required this.trail1, required this.trail2, this.dark = true});

  static const _tw = 236.0, _th = 118.0;
  static const _threshold = ColorFilter.matrix(<double>[
    0, 0, 0, 0, 255, //
    0, 0, 0, 0, 255,
    0, 0, 0, 0, 255,
    0, 0, 0, 26, -11 * 255,
  ]);

  @override
  void paint(Canvas canvas, Size size) {
    final k = size.width / _tw;
    canvas.save();
    canvas.scale(k);
    final track = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, _tw, _th), const Radius.circular(_th / 2));
    final on = p.clamp(0.0, 1.0);
    final gradient = const LinearGradient(colors: [pillViolet, pillCyan]).createShader(const Rect.fromLTWH(0, 0, _tw, _th));

    // Glow, track, its gradient and a faint inner border.
    if (on > 0) {
      canvas.drawRRect(track, Paint()
        ..shader = gradient
        ..color = Colors.white.withValues(alpha: 0.75 * on)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10.6));
    }
    canvas.drawRRect(track, Paint()..color = dark ? const Color(0xFF262534) : const Color(0xFFDCDBE8));
    if (on > 0) {
      canvas.saveLayer(null, Paint()..color = Colors.white.withValues(alpha: on));
      canvas.drawRRect(track, Paint()..shader = gradient);
      canvas.restore();
    }
    canvas.drawRRect(track.deflate(0.5 / k), Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1 / k
      ..color = dark ? const Color(0x17FFFFFF) : const Color(0x14000000));

    // Knob pose: stretched with speed, squashed past the ends, kept 14px from either end.
    final s = math.min(speed.abs() * 0.055, 0.55);
    var sx = 1 + s, sy = 1 / math.sqrt(1 + s);
    final over = p > 1 ? p - 1 : (p < 0 ? -p : 0.0);
    sx *= 1 - 1.6 * over;
    sy *= 1 + 1.1 * over;
    double place(double q, double r, double scale) => (59 + 118 * q.clamp(0.0, 1.0)).clamp(14 + r * scale, _tw - 14 - r * scale);
    final kx = place(p, 45, sx);

    // The liquid is drawn in the widget's own pixels (the blur does not follow the scale).
    canvas.restore();
    final cy = _th / 2 * k;
    Offset at(double x) => Offset(x * k, cy);

    // Soft shadow under the knob.
    canvas.save();
    canvas.translate(kx * k, cy + 3 * k);
    canvas.scale(sx, sy);
    canvas.drawCircle(Offset.zero, 45 * k, Paint()
      ..color = Colors.black.withValues(alpha: 0.35)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 * k));
    canvas.restore();

    // Knob and droplets blurred together, alpha sharpened (×26 − 11), filled with the knob gradient.
    final bounds = Rect.fromLTWH(-20 * k, -20 * k, (_tw + 40) * k, (_th + 40) * k);
    final blur = 7.7 * k;
    canvas.saveLayer(bounds, Paint());
    canvas.saveLayer(bounds, Paint()..colorFilter = _threshold);
    // Each blob blurred on its own (a layer blur gets cut at the blobs' bounds on some renderers);
    // where the soft edges overlap they add up and bridge, like one blurred picture.
    final white = Paint()
      ..color = Colors.white
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    canvas.drawCircle(at(place(trail2, 18, 1)), 18 * k, white);
    canvas.drawCircle(at(place(trail1, 27, 1)), 27 * k, white);
    canvas.save();
    canvas.translate(kx * k, cy);
    canvas.scale(sx, sy);
    canvas.drawCircle(Offset.zero, 45 * k, white);
    canvas.restore();
    canvas.restore();
    canvas.drawRect(bounds, Paint()
      ..blendMode = BlendMode.srcIn
      ..shader = ui.Gradient.radial(Offset((kx - 12) * k, cy - 12 * k), 60 * k, const [Color(0xFFFFFFFF), Color(0xFFDCDCF0)]));
    canvas.restore();
  }

  @override
  bool shouldRepaint(LiquidSwitchPainter old) =>
      old.p != p || old.speed != speed || old.trail1 != trail1 || old.trail2 != trail2 || old.dark != dark;
}
