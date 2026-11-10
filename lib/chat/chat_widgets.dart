import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet, springAt;

/// A round violet→cyan button with a soft violet glow; it dips 12% when tapped and springs back.
/// Off (no [onPressed]): faded, without the glow.
class GlowButton extends StatefulWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final Widget child;
  final double size;
  const GlowButton({super.key, required this.tooltip, required this.onPressed, required this.child, this.size = 36});

  @override
  State<GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<GlowButton> with SingleTickerProviderStateMixin {
  late final AnimationController _press = AnimationController(vsync: this, duration: const Duration(milliseconds: 600), value: 1);

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  void _tap() {
    if (!(MediaQuery.maybeDisableAnimationsOf(context) ?? false)) _press.forward(from: 0);
    widget.onPressed?.call();
  }

  @override
  Widget build(BuildContext context) {
    final on = widget.onPressed != null;
    final s = widget.size;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        enabled: on,
        label: widget.tooltip,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: on ? _tap : null,
          // A 48 px target around the smaller circle.
          child: SizedBox.square(
            dimension: s < 48 ? 48 : s,
            child: Center(
              child: AnimatedBuilder(
                animation: _press,
                builder: (_, child) => Transform.scale(scale: 1 - 0.12 * (1 - springAt(_press.value * 0.6, 22, 0.45)), child: child),
                child: AnimatedOpacity(
                  opacity: on ? 1 : 0.45,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    width: s,
                    height: s,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const LinearGradient(colors: [pillViolet, pillCyan]),
                      boxShadow: on ? const [BoxShadow(color: Color(0x806E5BFF), blurRadius: 10)] : null,
                    ),
                    child: IconTheme(data: IconThemeData(color: Colors.white, size: s * 0.5), child: widget.child),
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

/// The send arrow: a shaft pointing up with an open head, in white strokes.
class SendArrow extends StatelessWidget {
  final double size;
  const SendArrow({super.key, this.size = 20});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: _ArrowPainter());
}

class _ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final c = size.center(Offset.zero);
    Offset p(double x, double y) => c + Offset(x * s, y * s);
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
      Path()
        ..moveTo(p(0, 0.38).dx, p(0, 0.38).dy)
        ..lineTo(p(0, -0.38).dx, p(0, -0.38).dy)
        ..moveTo(p(-0.30, -0.08).dx, p(-0.30, -0.08).dy)
        ..lineTo(p(0, -0.38).dx, p(0, -0.38).dy)
        ..lineTo(p(0.30, -0.08).dx, p(0.30, -0.08).dy),
      paint,
    );
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => false;
}

/// The chat's input look: a pill on a deep fill with a faint 2 px rim (the message box, the
/// people search).
InputDecoration composerDecoration(BuildContext context, {required String hint, Widget? prefixIcon, TextStyle? hintStyle}) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  final scheme = Theme.of(context).colorScheme;
  final rim = OutlineInputBorder(
    borderRadius: BorderRadius.circular(24),
    borderSide: BorderSide(color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.08), width: 2),
  );
  return InputDecoration(
    hintText: hint,
    hintStyle: hintStyle ?? TextStyle(color: dark ? const Color(0xFF6D6B88) : scheme.onSurfaceVariant),
    prefixIcon: prefixIcon,
    filled: true,
    fillColor: dark ? const Color(0xFF1C1B2B) : scheme.surfaceContainerHighest,
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
    border: rim,
    enabledBorder: rim,
    focusedBorder: rim.copyWith(borderSide: rim.borderSide.copyWith(color: pillCyan.withValues(alpha: 0.45))),
  );
}
