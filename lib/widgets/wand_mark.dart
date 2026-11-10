import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

/// The Wand Studio mark: three descending violet squares on a white tile, as on the launcher icon.
class WandMark extends StatelessWidget {
  final double size;
  const WandMark({super.key, this.size = 72});

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Wand Studio',
        image: true,
        child: SizedBox.square(dimension: size, child: const CustomPaint(painter: _MarkPainter())),
      );
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter();

  static const _violet = Color(0xFF4F39F6);
  // In logo.svg's 512 box: x = y, size, radius, opacity.
  static const _squares = [(56.0, 170.0, 12.0, 1.0), (246.0, 116.0, 9.0, 0.55), (382.0, 74.0, 6.0, 0.22)];

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 512;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(112 * u)),
      Paint()..color = Colors.white,
    );
    for (final (at, side, radius, alpha) in _squares) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(at * u, at * u, side * u, side * u), Radius.circular(radius * u)),
        Paint()..color = _violet.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) => false;
}

/// Where tool/build_app.dart puts the app meta's own icon (see json_config.mobile.icon); absent: the Wand mark.
const appIconAsset = 'assets/app/icon.png';

/// The app's mark: its own icon when the build bundled one, else the Wand mark. Rounded like the
/// launcher icon; shown on the splash, the error page before sign-in, and the sign-in page.
class AppMark extends StatelessWidget {
  final double size;
  const AppMark({super.key, this.size = 72});

  /// Looked up once: the bundle doesn't change while the app runs.
  static final Future<bool> _bundled = _has();

  static Future<bool> _has() async {
    try {
      await rootBundle.load(appIconAsset);
      return true;
    } catch (_) {
      return false; // not bundled: the Wand mark
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<bool>(
        future: _bundled,
        builder: (context, has) => has.data == true
            ? Semantics(
                image: true,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(size * 112 / 512),
                  child: Image.asset(appIconAsset, width: size, height: size, fit: BoxFit.cover),
                ),
              )
            : WandMark(size: size),
      );
}
