import 'package:flutter/material.dart';

import 'pill_bar.dart' show pillCyan, pillViolet;

/// The top bar's round button: a dark tile with a faint rim, the icon in the middle.
class TopBarButton extends StatelessWidget {
  final String tooltip;
  final Widget child;
  final VoidCallback onPressed;
  const TopBarButton({super.key, required this.tooltip, required this.child, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: Material(
          color: scheme.surfaceContainerHigh,
          shape: const CircleBorder(side: BorderSide(color: Color(0x14FFFFFF))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(dimension: 44, child: Center(child: child)),
          ),
        ),
      ),
    );
  }
}

/// Fills the left of the top bar: looks like a search field, opens the menu search.
class MenuSearchPill extends StatelessWidget {
  final String hint;
  final VoidCallback onPressed;
  const MenuSearchPill({super.key, required this.hint, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: hint,
      child: Semantics(
        button: true,
        label: hint,
        excludeSemantics: true,
        child: Material(
          color: scheme.surfaceContainerHigh,
          shape: const StadiumBorder(side: BorderSide(color: Color(0x14FFFFFF))),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox(
              height: 44,
              child: Row(children: [
                const SizedBox(width: 14),
                ShaderMask(
                  shaderCallback: (r) => const LinearGradient(colors: [pillViolet, pillCyan]).createShader(r),
                  child: const Icon(Icons.search, size: 22, color: Colors.white),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 15, fontWeight: FontWeight.w500)),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}

/// The signed-in user's initial on the brand gradient; opens the account sheet.
class AccountAvatar extends StatelessWidget {
  final String name;
  final String tooltip;
  final VoidCallback onPressed;
  const AccountAvatar({super.key, required this.name, required this.tooltip, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final initial = name.trim().characters.firstOrNull?.toUpperCase();
    return Tooltip(
      message: tooltip,
      child: Semantics(
        button: true,
        label: tooltip,
        excludeSemantics: true,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pillViolet, pillCyan]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
              boxShadow: [BoxShadow(color: pillViolet.withValues(alpha: 0.35), blurRadius: 10)],
            ),
            child: initial == null
                ? const Icon(Icons.person, color: Colors.white, size: 22)
                : Text(initial, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
