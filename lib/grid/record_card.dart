import 'package:flutter/material.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';
import 'card_slots.dart';
import 'cells.dart';

/// One record as a card: title, subtitle, status chip, "Label: value" rows and footer.
class RecordCard extends StatelessWidget {
  final CardSlots slots;
  final Map<String, dynamic> row;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final LookupText? lookupText;

  const RecordCard({super.key, required this.slots, required this.row, this.onTap, this.onMore, this.lookupText});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String text(MetaParam p) => cellText(p, row, lookupText: lookupText, l10n: l10n);

    Widget line(String s, TextStyle? style) => Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    Widget labelled(MetaParam p) => Padding(
          padding: const EdgeInsets.only(top: 2),
          child: line('${p.label}: ${text(p)}', theme.textTheme.bodySmall),
        );

    final title = slots.title == null ? '' : text(slots.title!);
    final subtitle = slots.subtitle == null ? '' : text(slots.subtitle!);
    final badge = slots.badge == null ? '' : text(slots.badge!);
    final options = slots.badge == null ? const <String>[] : _options(slots.badge!);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 4, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty) line(title, theme.textTheme.titleMedium),
                    if (subtitle.isNotEmpty) line(subtitle, theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                    if (badge.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Align(alignment: Alignment.centerLeft, child: _Chip(text: badge, color: statusColor(badge, options, scheme: theme.colorScheme))),
                      ),
                    for (final p in slots.body) labelled(p),
                    for (final p in slots.footer) labelled(p),
                  ],
                ),
              ),
              if (onMore != null) IconButton(icon: const Icon(Icons.more_horiz), tooltip: l10n.more, onPressed: onMore),
              if (onMore == null) const SizedBox(width: 12),
            ],
          ),
        ),
      ),
    );
  }

  static List<String> _options(MetaParam p) {
    final o = p.jsonConfig['options'];
    return o is List ? [for (final e in o) '$e'] : const [];
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        constraints: const BoxConstraints(maxWidth: 220),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
