import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../grid/cells.dart';
import '../l10n/app_localizations.dart';
import '../nav/pill_bar.dart' show pillViolet;
import '../widgets/confirm_dialog.dart';
import '../widgets/pill_buttons.dart';
import '../widgets/row_group.dart';
import '../widgets/tones.dart';
import '../widgets/bin_icon.dart';
import 'fields.dart';
import 'lines.dart';
import 'lookup.dart';
import 'lookup_page.dart';
import 'values.dart';

/// A value as a card shows it (numbers, dates, options); a lookup's label is fetched once.
class FieldValueText extends ConsumerWidget {
  final MetaParam p;
  final Object? value;
  final TextStyle? style;
  final String empty;
  const FieldValueText({super.key, required this.p, required this.value, this.style, this.empty = ''});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppLocalizations.of(context);
    Widget text(String s) => Text(s.isEmpty ? empty : s, maxLines: 1, overflow: TextOverflow.ellipsis, style: style);
    final spec = cellSpecOf(p);
    if (spec == null) return text(cellText(p, {p.paramName: value}, l10n: l));
    if (value == null || value == '') return text('');
    final svc = ref.read(lookupServiceProvider);
    final cached = svc.cachedText(spec, value);
    if (cached != null) return text(cached);
    return FutureBuilder<String?>(
      future: svc.lookupText(spec, value),
      builder: (_, s) => text(s.connectionState == ConnectionState.done ? (s.data ?? '#$value') : '…'),
    );
  }
}

String _money(double v) {
  final r = round2(v);
  final whole = r.truncate().abs().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
  final cents = ((r.abs() - r.abs().truncate()) * 100).round().toString().padLeft(2, '0');
  return '${r < 0 ? '-' : ''}$whole.$cents';
}

/// One detail as a section of compact line cards (the web `DetailLines`): tap a line to edit it on
/// its own page, where its own lines show the same way. Add line, and Choose for the first lookup
/// column (a line per record picked). [errors] are the save's messages by full key
/// ("lines.0.deliveries.1.quantity"); [prefix] is the part above this detail ("lines.0.").
class DetailSection extends StatelessWidget {
  final DetailNode node;
  final List<Line> lines;
  final ValueChanged<List<Line>> onChanged;
  final Map<String, String> errors;
  final String prefix;
  final bool readOnly;
  final StartValues start;

  const DetailSection({
    super.key,
    required this.node,
    required this.lines,
    required this.onChanged,
    required this.start,
    this.errors = const {},
    this.prefix = '',
    this.readOnly = false,
  });

  String _at(int i) => '$prefix${node.path}.$i.';

  bool _hasError(int i) => errors.keys.any((k) => k.startsWith(_at(i)));

  /// The first lookup column: Choose fills its basket.
  MetaParam? get _basketField => node.fields.where((p) => p.isSelect && p.refMetaId != null).firstOrNull;

  Future<void> _open(BuildContext context, int i) async {
    final isNew = i >= lines.length;
    final line = isNew ? blankLine(node, start) : lines[i];
    final result = await Navigator.of(context, rootNavigator: true).push<Object>(MaterialPageRoute(
      builder: (_) => LinePage(node: node, line: line, index: i, isNew: isNew, prefix: prefix, errors: errors, readOnly: readOnly, start: start),
    ));
    if (readOnly) return;
    if (result == false && !isNew) {
      onChanged([...lines]..removeAt(i));
    } else if (result is Line) {
      if (isNew) {
        // A new line left as it started is not kept.
        if (result.values.entries.every((e) => line.values[e.key] == e.value) && result.sub == line.sub) return;
        onChanged([...lines, result]);
      } else {
        onChanged([for (final (j, l) in lines.indexed) j == i ? result : l]);
      }
    }
  }

  /// A line for each record picked: into new lines still empty in that field, the rest added.
  Future<void> _choose(BuildContext context, MetaParam f) async {
    final spec = lookupSpecOf(f);
    if (spec == null) return;
    final rows = await pickLookupMany(context, spec);
    if (rows.isEmpty) return;
    final path = pathOf(f);
    final values = [for (final r in rows) '${r[spec.valueField] ?? ''}'];
    final free = [for (final (j, l) in lines.indexed) if (l.id == null && (l.values[path] ?? '') == '') j];
    final kept = [
      for (final (j, l) in lines.indexed)
        if (free.indexOf(j) case final k when k >= 0 && k < values.length) l.copyWith(values: {...l.values, path: values[k]}) else l,
    ];
    final added = [
      for (final v in values.skip(free.length))
        () {
          final b = blankLine(node, start);
          return b.copyWith(values: {...b.values, path: v});
        }(),
    ];
    onChanged([...kept, ...added]);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final basket = readOnly ? null : _basketField;
    final listError = errors['$prefix${node.path}'];
    final total = node.amount == null ? null : linesTotal(node, lines);
    final link = TextButton.styleFrom(
      visualDensity: VisualDensity.compact,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      foregroundColor: scheme.isDark ? const Color(0xFFB6A8FF) : pillViolet,
      textStyle: const TextStyle(fontFamily: appFont, fontWeight: FontWeight.w600),
    );

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Row(children: [
        // The heading's look from [RowGroupHeading], so lines read as one more block of the form.
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Text(node.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant, letterSpacing: 0.25)),
          ),
        ),
        if (lines.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Text('${lines.length}', style: theme.textTheme.labelMedium?.copyWith(color: scheme.onSurfaceVariant)),
          ),
        const Spacer(),
        if (basket != null)
          TextButton.icon(style: link, onPressed: () => _choose(context, basket), icon: const Icon(Icons.playlist_add_check, size: 18), label: Text(l.choose)),
        if (!readOnly)
          TextButton.icon(style: link, onPressed: () => _open(context, lines.length), icon: const Icon(Icons.add, size: 18), label: Text(l.addLine)),
      ]),
      const SizedBox(height: 4),
      Material(
        color: scheme.softFill,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: lines.isEmpty
            ? Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                child: Text(l.noLines, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              )
            : Column(children: [
                for (final (i, line) in lines.indexed) ...[
                  if (i > 0) Divider(height: 1, thickness: 1, indent: 14, color: scheme.hairline),
                  _LineCard(node: node, line: line, error: _hasError(i), onTap: () => _open(context, i)),
                ],
                // The total as the block's last row, its figure under the line amounts.
                if (total != null) ...[
                  Divider(height: 1, thickness: 1, color: scheme.hairline),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 28, 12),
                    child: Row(children: [
                      Text(l.total, style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant)),
                      const Spacer(),
                      Text(_money(total), style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700, fontFeatures: const [FontFeature.tabularFigures()])),
                    ]),
                  ),
                ],
              ]),
      ),
      if (listError != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, left: 4),
          child: Text(listError, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
        ),
    ]);
  }
}

/// One line as a row: its first value as the title, the next few under it, the amount at the right
/// and how many lines of its own it has.
class _LineCard extends StatelessWidget {
  final DetailNode node;
  final Line line;
  final bool error;
  final VoidCallback onTap;
  const _LineCard({required this.node, required this.line, required this.error, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final filled = [for (final p in node.fields) if (p.dataType != 'boolean' && (line.values[pathOf(p)] ?? '') != '') p];
    final title = filled.where((p) => p.isLabel).firstOrNull ?? filled.firstOrNull;
    final rest = [for (final p in filled) if (p != title) p].take(3).toList();
    final amount = node.amount?.length == 2 ? lineAmount(node, line) : null;
    final subs = [
      for (final c in node.children)
        if (!c.isOne && (line.sub[c.path]?.isNotEmpty ?? false)) '${c.name} ${line.sub[c.path]!.length}',
    ];
    final muted = theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant);
    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: error ? BoxDecoration(border: Border(left: BorderSide(color: scheme.error, width: 3))) : null,
        padding: const EdgeInsets.fromLTRB(14, 9, 8, 9),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (title == null)
                Text('—', style: theme.textTheme.bodyMedium)
              else
                FieldValueText(p: title, value: line.values[pathOf(title)], style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
              if (rest.isNotEmpty || subs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(spacing: 10, runSpacing: 2, children: [
                    for (final p in rest)
                      Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('${p.label} ', style: muted?.copyWith(fontWeight: FontWeight.w300)),
                        ConstrainedBox(constraints: const BoxConstraints(maxWidth: 140), child: FieldValueText(p: p, value: line.values[pathOf(p)], style: muted)),
                      ]),
                    for (final s in subs) Text(s, style: muted?.copyWith(color: scheme.isDark ? const Color(0xFFB6A8FF) : pillViolet)),
                  ]),
                ),
            ]),
          ),
          if (amount != null)
            Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text(_money(amount), style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600, fontFeatures: const [FontFeature.tabularFigures()])),
            ),
          Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// A line's fields, the ones its own lines add up into worked out, as plain form inputs.
/// [at] is the line's error key prefix ("lines.0.").
List<Widget> lineInputs({
  required DetailNode node,
  required Line line,
  required String at,
  required Map<String, String> errors,
  required bool readOnly,
  required void Function(String path, Object value) onChanged,
}) {
  final totals = subTotals(node);
  return [
    for (final p in node.fields)
      if (totals[pathOf(p)] case final c?)
        FieldInput(
          key: ValueKey('$at${pathOf(p)}'),
          p: p,
          value: totalText(linesTotal(c, line.sub[c.path] ?? const [])),
          onChanged: (_) {},
          readOnly: true,
          optional: true,
          error: errors['$at${pathOf(p)}'],
          row: true,
        )
      else
        FieldInput(
          key: ValueKey('$at${pathOf(p)}'),
          p: p,
          value: line.values[pathOf(p)],
          error: errors['$at${pathOf(p)}'],
          readOnly: readOnly || isAutoReadOnly(p),
          optional: autonumberOf(p) != null,
          onChanged: (v) => onChanged(pathOf(p), v),
          row: true,
        ),
  ];
}

/// A one-to-one detail (json_config.one) inline in the form: a titled group of its fields.
/// Its errors arrive keyed "terms.payment_days" (no line number).
class OneSection extends StatelessWidget {
  final DetailNode node;
  final Line line;
  final ValueChanged<Line> onChanged;
  final Map<String, String> errors;
  final String prefix;
  final bool readOnly;
  const OneSection({super.key, required this.node, required this.line, required this.onChanged, this.errors = const {}, this.prefix = '', this.readOnly = false});

  @override
  Widget build(BuildContext context) {
    // A heading and a rounded block of rows, like the form's own fields.
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RowGroupHeading(node.name),
      RowGroup(
        indent: 14,
        children: lineInputs(
          node: node,
          line: line,
          at: '$prefix${node.path}.',
          errors: errors,
          readOnly: readOnly,
          onChanged: (path, v) => onChanged(line.copyWith(values: {...line.values, path: v})),
        ),
      ),
    ]);
  }
}

/// One line on its own page: its fields, then its own details. Going back keeps what was typed;
/// Remove takes the line out. Pops the [Line] as it now is, or false when removed.
class LinePage extends StatefulWidget {
  final DetailNode node;
  final Line line;
  final int index;
  final bool isNew;
  final String prefix;
  final Map<String, String> errors;
  final bool readOnly;
  final StartValues start;

  const LinePage({
    super.key,
    required this.node,
    required this.line,
    required this.index,
    required this.isNew,
    required this.prefix,
    required this.errors,
    required this.readOnly,
    required this.start,
  });

  @override
  State<LinePage> createState() => _LinePageState();
}

class _LinePageState extends State<LinePage> {
  late Line _line = widget.line;
  late Map<String, String> _errors = widget.errors;

  String get _at => '${widget.prefix}${widget.node.path}.${widget.index}.';

  void _set(String path, Object v) => setState(() {
        _line = _line.copyWith(values: {..._line.values, path: v});
        _errors = {..._errors}..remove('$_at$path');
      });

  void _setSub(String path, List<Line> lines) => setState(() => _line = _line.copyWith(sub: {..._line.sub, path: lines}));

  void _done() {
    final l = AppLocalizations.of(context);
    final missing = missingInLine(widget.node, _line);
    if (missing.isNotEmpty) {
      setState(() => _errors = {..._errors, for (final m in missing) '$_at$m': l.fieldRequired});
      return;
    }
    Navigator.of(context).pop(_line);
  }

  Future<void> _remove() async {
    final l = AppLocalizations.of(context);
    final navigator = Navigator.of(context);
    final ok = await showConfirmDialog(context, title: l.removeLine, confirmLabel: l.delete, cancelLabel: l.cancel, destructive: true);
    if (ok) navigator.pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final node = widget.node;
    final title = widget.isNew ? l.newLine(node.name) : '${node.name} · ${widget.index + 1}';
    return PopScope<Object>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_line);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (!widget.readOnly && !widget.isNew)
              Padding(padding: const EdgeInsets.only(right: 4), child: DeleteButton(tooltip: l.removeLine, onPressed: _remove, size: 38)),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (node.fields.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: RowGroup(
                  indent: 14,
                  children: lineInputs(node: node, line: _line, at: _at, errors: _errors, readOnly: widget.readOnly, onChanged: _set),
                ),
              ),
            for (final c in node.children)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: c.isOne
                    ? OneSection(
                        node: c,
                        line: (_line.sub[c.path] ?? const []).firstOrNull ?? blankLine(c, widget.start),
                        onChanged: (one) => _setSub(c.path, [one]),
                        errors: _errors,
                        prefix: _at,
                        readOnly: widget.readOnly,
                      )
                    : DetailSection(
                        node: c,
                        lines: _line.sub[c.path] ?? const [],
                        onChanged: (lines) => _setSub(c.path, lines),
                        errors: _errors,
                        prefix: _at,
                        readOnly: widget.readOnly,
                        start: widget.start,
                      ),
              ),
          ]),
        ),
        bottomNavigationBar: widget.readOnly
            ? null
            : Material(
                elevation: 3,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
                    child: GradientButton(onPressed: _done, child: Text(l.done)),
                  ),
                ),
              ),
      ),
    );
  }
}
