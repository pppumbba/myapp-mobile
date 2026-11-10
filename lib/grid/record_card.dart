import 'package:flutter/material.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';
import '../nav/icons.dart';
import 'card_slots.dart';
import 'cells.dart';

/// One record as a compact card: title with the status chip at its right, subtitle, then the values side
/// by side, each with the column's icon in front (the column name is the icon's tooltip). Empty values
/// are left out. Long-press: [onMore] (sharing the row).
class RecordCard extends StatelessWidget {
  final CardSlots slots;
  final Map<String, dynamic> row;
  final VoidCallback? onTap;
  final VoidCallback? onMore;
  final LookupText? lookupText;
  final EdgeInsetsGeometry margin;

  const RecordCard({
    super.key,
    required this.slots,
    required this.row,
    this.onTap,
    this.onMore,
    this.lookupText,
    this.margin = const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    String text(MetaParam p) => cellText(p, row, lookupText: lookupText, l10n: l10n);

    Widget line(String s, TextStyle? style) => Text(s, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    Widget labelled(MetaParam p, String value, double maxWidth) => Semantics(
          label: '${p.label}: $value',
          excludeSemantics: true,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Tooltip(message: p.label, child: Icon(paramIcon(p), size: 14, color: theme.colorScheme.onSurfaceVariant)),
              const SizedBox(width: 5),
              Flexible(child: line(value, theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
            ]),
          ),
        );

    final title = slots.title == null ? '' : text(slots.title!);
    final subtitle = slots.subtitle == null ? '' : text(slots.subtitle!);
    final badge = slots.badge == null ? '' : text(slots.badge!);
    final imageValue = slots.image == null ? null : row[slots.image!.paramName];
    // Uploaded-file images (JSON file values, /contents/{id}, need auth) are deferred to plan 5 (files); only URLs show now.
    final imageUrl = imageValue is String && RegExp(r"^https?://", caseSensitive: false).hasMatch(imageValue) ? imageValue : null;
    final options = slots.badge == null ? const <String>[] : _options(slots.badge!);
    final values = [
      for (final p in [...slots.body, ...slots.footer])
        if (text(p) case final v when v.isNotEmpty) (p, v),
    ];

    return Card(
      margin: margin,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onMore,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 12, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (imageUrl != null)
                Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(imageUrl, width: 40, height: 40, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox(width: 40, height: 40)),
                  ),
                ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title.isNotEmpty || badge.isNotEmpty)
                      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Expanded(child: line(title, theme.textTheme.titleSmall?.copyWith(fontSize: 15, fontWeight: FontWeight.w600))),
                        if (badge.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 8, top: 1),
                            child: _Chip(text: badge, color: statusColor(badge, options, scheme: theme.colorScheme)),
                          ),
                      ]),
                    if (subtitle.isNotEmpty) line(subtitle, theme.textTheme.bodySmall?.copyWith(fontSize: 13, color: theme.colorScheme.onSurfaceVariant)),
                    if (values.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: LayoutBuilder(
                          builder: (_, box) => Wrap(spacing: 12, runSpacing: 3, children: [
                            for (final (p, v) in values) labelled(p, v, box.maxWidth),
                          ]),
                        ),
                      ),
                  ],
                ),
              ),
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
        constraints: const BoxConstraints(maxWidth: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
        decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
      );
}

/// The icon shown in front of a value: the column's own icon_cls, else one guessed from its name and type.
IconData paramIcon(MetaParam p) {
  if (p.iconCls != null && menuIcons.containsKey(p.iconCls)) return menuIcons[p.iconCls]!;
  final n = '${p.paramName} ${p.labelName ?? ''}'.toLowerCase();
  final type = '${p.dataType ?? ''} ${p.renderType ?? ''}'.toLowerCase();
  bool has(List<String> words) => words.any(n.contains);
  if (has(['location', 'address', 'site', 'place', 'room'])) return Icons.place_outlined;
  if (has(['department', 'branch', 'company', 'organization', 'supplier', 'vendor'])) return Icons.apartment_outlined;
  if (has(['category', 'group', 'class'])) return Icons.category_outlined;
  if (has(['priority'])) return Icons.flag_outlined;
  if (has(['technician', 'user', 'person', 'employee', 'reported_by', 'owner', 'assignee', 'customer', 'contact'])) return Icons.person_outline;
  if (has(['phone', 'mobile'])) return Icons.call_outlined;
  if (has(['email', 'mail'])) return Icons.mail_outline;
  if (has(['cost', 'price', 'amount', 'total', 'value', 'salary', 'paid'])) return Icons.payments_outlined;
  if (has(['hour', 'time', 'duration'])) return Icons.schedule;
  if (has(['qty', 'quantity', 'count', 'stock'])) return Icons.numbers;
  if (has(['asset', 'equipment', 'machine', 'item', 'product'])) return Icons.inventory_2_outlined;
  if (has(['serial', 'code', 'number']) || RegExp(r'(^|_)no($|_| )').hasMatch(n)) return Icons.tag;
  if (has(['type', 'kind'])) return Icons.label_outline;
  if (has(['title', 'description', 'note', 'comment', 'resolution'])) return Icons.notes;
  if (has(['date', '_on', '_at', 'start', 'end', 'due']) || type.contains('date')) return Icons.event_outlined;
  if (type.contains('bool') || type.contains('check')) return Icons.check_box_outlined;
  return Icons.circle_outlined;
}
