import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillCyan, pillViolet;
import 'tones.dart';

const pillPink = Color(0xFFFF5CA8), pillCoral = Color(0xFFFF7B8C);

/// The quiet choice (Cancel, Back, Save and add): a 48px pill in a faint white tint.
class SoftButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  const SoftButton({super.key, required this.onPressed, required this.child});

  @override
  Widget build(BuildContext context) => TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.softFill,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(horizontal: 20),
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontFamily: appFont, fontWeight: FontWeight.w600),
        ),
        child: child,
      );
}

/// The main choice (Save, Next, Delete): a 48px violet → cyan pill, pink → coral when [destructive].
/// Fades while disabled.
class GradientButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final bool destructive;
  const GradientButton({super.key, required this.onPressed, required this.child, this.destructive = false});

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: onPressed == null ? 0.55 : 1,
        duration: const Duration(milliseconds: 150),
        child: DecoratedBox(
          decoration: ShapeDecoration(
            shape: const StadiumBorder(),
            gradient: LinearGradient(colors: destructive ? const [pillPink, pillCoral] : const [pillViolet, pillCyan]),
          ),
          child: FilledButton(
            onPressed: onPressed,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.transparent,
              disabledBackgroundColor: Colors.transparent,
              foregroundColor: Colors.white,
              disabledForegroundColor: Colors.white,
              shadowColor: Colors.transparent,
              minimumSize: const Size.fromHeight(48),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: const StadiumBorder(),
              textStyle: const TextStyle(fontFamily: appFont, fontWeight: FontWeight.w700),
            ),
            child: child,
          ),
        ),
      );
}
