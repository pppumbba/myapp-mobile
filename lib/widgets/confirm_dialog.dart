import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillViolet;
import 'pill_buttons.dart';
import 'tones.dart';
import 'bin_icon.dart';

const _pink = Color(0xFFFF5CA8);

/// Asks [title] (with an optional [message]) and resolves true only for [confirmLabel].
/// The card pops in from 72% with a small overshoot and shrinks to 86% as it fades away;
/// [destructive] paints the confirm button pink and shows a trash mark.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = false,
}) async {
  final ok = await Navigator.of(context, rootNavigator: true).push<bool>(PopInRoute<bool>(
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    cardKey: const ValueKey('confirm-card'),
    builder: (ctx) => _ConfirmCard(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      cancelLabel: cancelLabel,
      destructive: destructive,
    ),
  ));
  return ok == true;
}

double _seg(double x, double a, double b) => ((x - a) / (b - a)).clamp(0.0, 1.0);
double _lerp(double a, double b, double k) => a + (b - a) * k;

/// A card in the middle of a dim: it pops in from 72% with a small overshoot and shrinks to 86%
/// as it fades away; tapping the dim closes it. [cardKey] lands on the scaling card, for tests.
class PopInRoute<T> extends PopupRoute<T> {
  final WidgetBuilder builder;
  final Key? cardKey;
  PopInRoute({required this.builder, required this.barrierLabel, this.cardKey});

  @override
  final String barrierLabel;

  @override
  bool get barrierDismissible => true;

  // The dim is drawn with the card so it can follow the open and close timings.
  @override
  Color? get barrierColor => null;

  @override
  Duration get transitionDuration => const Duration(milliseconds: 420);

  @override
  Duration get reverseTransitionDuration => const Duration(milliseconds: 300);

  @override
  Widget buildPage(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation) =>
      builder(context);

  @override
  Widget buildTransitions(BuildContext context, Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final closing = animation.status == AnimationStatus.reverse;
        double scale, opacity, dim;
        if (!closing) {
          // Seconds since the tap: the card scales over 0.42s, fades in over 0.16s; the dim over 0.25s.
          final a = animation.value * 0.42;
          scale = _lerp(0.72, 1, Curves.easeOutBack.transform(_seg(a, 0, 0.42)));
          opacity = Curves.easeOutCubic.transform(_seg(a, 0, 0.16));
          dim = Curves.easeOutCubic.transform(_seg(a, 0, 0.25));
        } else {
          // Seconds since the close: a 0.06s beat, then shrink and fade over 0.24s.
          final b = (1 - animation.value) * 0.3;
          final k = Curves.easeOutCubic.transform(_seg(b, 0.06, 0.3));
          scale = _lerp(1, 0.86, k);
          opacity = 1 - k;
          dim = 1 - Curves.easeOutCubic.transform(_seg(b, 0.06, 0.25));
        }
        if (still) scale = 1;
        return Stack(fit: StackFit.expand, children: [
          IgnorePointer(child: ColoredBox(color: Colors.black.withValues(alpha: 0.55 * dim))),
          Center(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(key: cardKey, scale: scale, child: child),
            ),
          ),
        ]);
      },
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  final String title, confirmLabel, cancelLabel;
  final String? message;
  final bool destructive;
  const _ConfirmCard({
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.destructive,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final accent = destructive ? _pink : pillViolet;
    void close(bool v) => Navigator.of(context).pop(v);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: Semantics(
          scopesRoute: true,
          namesRoute: true,
          explicitChildNodes: true,
          label: title,
          child: Material(
            color: scheme.surfaceContainerHigh,
            elevation: 16,
            shadowColor: Colors.black,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(color: scheme.hairline),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: accent.withValues(alpha: 0.18), shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: destructive ? BinIcon(size: 20, color: accent) : Icon(Icons.help_outline, size: 20, color: accent),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700))),
                ]),
                if (message != null) ...[
                  const SizedBox(height: 12),
                  Text(message!, style: theme.textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant)),
                ],
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: SoftButton(onPressed: () => close(false), child: Text(cancelLabel))),
                  const SizedBox(width: 12),
                  Expanded(child: GradientButton(onPressed: () => close(true), destructive: destructive, child: Text(confirmLabel))),
                ]),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
