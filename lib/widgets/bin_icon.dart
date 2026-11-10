import 'package:flutter/material.dart';

/// The swipe Delete button's red, used wherever something is deleted.
const binRedLeft = Color(0xFFFF6A78), binRedRight = Color(0xFFD93160);

/// A bin whose lid tilts open by [lid] radians (negative lifts the right side), drawn in [color].
/// The app's delete mark: the swipe button, menus, the confirm dialog and the line page use it.
class BinPainter extends CustomPainter {
  final double lid;
  final Color color;
  BinPainter({required this.lid, this.color = Colors.white});

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final p = Paint()
      ..color = color
      // 2.4 at the swipe button's 28px; small icons keep a visible line.
      ..strokeWidth = (s * 2.4 / 28).clamp(1.6, 2.4)
      ..style = PaintingStyle.stroke
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
  bool shouldRepaint(BinPainter old) => old.lid != lid || old.color != color;
}

/// The bin as an icon, in place of Icons.delete_outline.
class BinIcon extends StatelessWidget {
  final double size;
  final Color color;
  final double lid;
  const BinIcon({super.key, this.size = 20, this.color = Colors.white, this.lid = 0});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: BinPainter(lid: lid, color: color));
}

/// A round red Delete button like the swipe one, for a top bar: the lid lifts while pressed.
class DeleteButton extends StatefulWidget {
  final String tooltip;
  final VoidCallback? onPressed;
  final double size;
  const DeleteButton({super.key, required this.tooltip, required this.onPressed, this.size = 40});

  @override
  State<DeleteButton> createState() => _DeleteButtonState();
}

class _DeleteButtonState extends State<DeleteButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.size;
    return Tooltip(
      message: widget.tooltip,
      child: Semantics(
        button: true,
        label: widget.tooltip,
        excludeSemantics: true,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _down = true),
          onTapCancel: () => setState(() => _down = false),
          onTapUp: (_) => setState(() => _down = false),
          onTap: widget.onPressed,
          // 48px to tap, the circle inside.
          child: SizedBox.square(
            dimension: d < 48 ? 48 : d,
            child: Center(
              child: AnimatedScale(
                scale: _down ? 0.9 : 1,
                duration: const Duration(milliseconds: 120),
                child: Container(
                  width: d,
                  height: d,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(colors: [binRedLeft, binRedRight]),
                    boxShadow: [BoxShadow(color: binRedRight.withValues(alpha: 0.35), blurRadius: 12, offset: const Offset(0, 4))],
                  ),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: _down ? -0.5 : 0),
                    duration: const Duration(milliseconds: 160),
                    builder: (_, lid, _) => BinIcon(size: d * 0.5, lid: lid),
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
