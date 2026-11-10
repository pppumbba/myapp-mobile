import 'package:flutter/material.dart';

import '../nav/pill_bar.dart' show pillViolet;
import 'tones.dart';

/// Rows in one rounded block, split by hairlines (account page, menu search).
class RowGroup extends StatelessWidget {
  final List<Widget> children;

  /// Where the hairlines start: past the row icons, or near the edge for rows without one.
  final double indent;
  const RowGroup({super.key, required this.children, this.indent = 60});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.softFill,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) Divider(height: 1, thickness: 1, indent: indent, color: scheme.hairline),
          children[i],
        ],
      ]),
    );
  }
}

/// A small muted heading over a [RowGroup].
class RowGroupHeading extends StatelessWidget {
  final String text;
  const RowGroupHeading(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 18, 14, 8),
      child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, letterSpacing: 0.25)),
    );
  }
}

/// An icon in a tinted square, a title, then a value and chevron on the right.
class IconRow extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? value;
  /// In place of the value and chevron: a control of its own (the row is then not tappable).
  final Widget? trailing;
  final VoidCallback? onTap;
  /// The icon and title in this colour instead (Sign out in red).
  final Color? color;
  /// Drawn in place of [icon] (the bin on a Delete row).
  final Widget? iconChild;
  const IconRow({super.key, required this.icon, required this.title, this.value, this.trailing, this.onTap, this.color, this.iconChild});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final titleText = Text(title, maxLines: 1, overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600, color: color));
    // With nothing on the right (menu search hits) a long title fills the row and shortens.
    final bare = value == null && trailing == null;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 50),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: (color ?? pillViolet).withValues(alpha: 0.16), borderRadius: BorderRadius.circular(9)),
              child: iconChild ?? Icon(icon, size: 18, color: color ?? (scheme.isDark ? const Color(0xFFB6A8FF) : pillViolet)),
            ),
            const SizedBox(width: 14),
            if (bare)
              Expanded(child: titleText)
            else ...[
              titleText,
              const SizedBox(width: 12),
              Expanded(
                child: trailing != null
                    ? Align(alignment: Alignment.centerRight, child: trailing)
                    : Text(value ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.end,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 14.5)),
              ),
            ],
            if (trailing == null) ...[
              const SizedBox(width: 4),
              Icon(Icons.chevron_right, color: scheme.onSurfaceVariant),
            ],
          ]),
        ),
      ),
    );
  }
}
