import 'package:flutter/material.dart';

import 'tones.dart';

/// A chip in the tab menu's colours: a grey label on a soft pill, and once picked the dark label
/// on the top bar buttons' tile. [trailing] sits after the label (a count or a ×).
class TabChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Widget? trailing;
  const TabChip({super.key, required this.label, required this.selected, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = selected ? scheme.onSurface : scheme.onSurfaceVariant;
    final body = Material(
      // Picked: the bell button's tile and faint rim; not picked: a soft grey pill.
      color: selected ? scheme.surfaceContainerHigh : scheme.softFill,
      shape: StadiumBorder(side: BorderSide(color: selected ? scheme.hairline : Colors.transparent)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 7, trailing == null ? 14 : 8, 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 220),
              child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontFamily: appFont, color: ink, fontSize: 14, fontWeight: FontWeight.w600)),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 6),
              IconTheme.merge(
                data: IconThemeData(color: ink, size: 17),
                child: DefaultTextStyle.merge(
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13, fontWeight: FontWeight.w500),
                  child: trailing!,
                ),
              ),
            ],
          ]),
        ),
      ),
    );
    return Semantics(button: true, selected: selected, child: body);
  }
}
