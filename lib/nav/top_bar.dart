import 'package:flutter/material.dart';

import '../widgets/tones.dart';
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
          shape: CircleBorder(side: BorderSide(color: scheme.hairline)),
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

const _menuSearchHero = 'menu-search';

/// The pill's track, shared by [MenuSearchPill] and [MenuSearchField] so the search keeps its look.
Widget _menuSearchTrack(BuildContext context, {required Widget child, VoidCallback? onTap}) {
  final scheme = Theme.of(context).colorScheme;
  return Hero(
    tag: _menuSearchHero,
    child: Material(
      color: scheme.surfaceContainerHigh,
      shape: StadiumBorder(side: BorderSide(color: scheme.hairline)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Row(children: [
            const SizedBox(width: 14),
            ShaderMask(
              shaderCallback: (r) => const LinearGradient(colors: [pillViolet, pillCyan]).createShader(r),
              child: const Icon(Icons.search, size: 22, color: Colors.white),
            ),
            const SizedBox(width: 10),
            Expanded(child: child),
          ]),
        ),
      ),
    ),
  );
}

TextStyle _menuSearchText(ColorScheme scheme, {bool hint = false}) =>
    TextStyle(color: hint ? scheme.onSurfaceVariant : scheme.onSurface, fontSize: 15, fontWeight: FontWeight.w500);

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
        child: _menuSearchTrack(
          context,
          onTap: onPressed,
          child: Text(hint, maxLines: 1, overflow: TextOverflow.ellipsis, style: _menuSearchText(scheme, hint: true)),
        ),
      ),
    );
  }
}

/// The same pill on the menu search page, now typed into; it flies there from [MenuSearchPill].
class MenuSearchField extends StatelessWidget {
  final String hint;
  final ValueChanged<String> onChanged;
  const MenuSearchField({super.key, required this.hint, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return _menuSearchTrack(
      context,
      child: Padding(
        padding: const EdgeInsets.only(right: 14),
        child: TextField(
          autofocus: true,
          onChanged: onChanged,
          textInputAction: TextInputAction.search,
          style: _menuSearchText(scheme),
          cursorColor: pillCyan,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: _menuSearchText(scheme, hint: true),
            isCollapsed: true,
            filled: false,
            border: InputBorder.none,
            enabledBorder: InputBorder.none,
            focusedBorder: InputBorder.none,
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
  final VoidCallback? onPressed;
  final double size;
  const AccountAvatar({super.key, required this.name, required this.tooltip, required this.onPressed, this.size = 44});

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
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [pillViolet, pillCyan]),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1.5),
              boxShadow: [BoxShadow(color: pillViolet.withValues(alpha: 0.35), blurRadius: 10)],
            ),
            child: initial == null
                ? Icon(Icons.person, color: Colors.white, size: size / 2)
                : Text(initial, style: TextStyle(color: Colors.white, fontSize: size * 0.41, fontWeight: FontWeight.w700)),
          ),
        ),
      ),
    );
  }
}
