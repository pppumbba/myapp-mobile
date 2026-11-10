import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../auth/session.dart';
import '../form/fields.dart';
import '../form/lookup.dart';
import '../form/values.dart';
import '../l10n/app_localizations.dart';
import 'cells.dart';
import 'grid_query.dart';
import '../widgets/pill_buttons.dart';
import '../widgets/snap_sheet.dart';

/// A filter's choices: options, Yes/No for booleans, else null (lookups use facet values).
List<({String id, String label})>? _choices(MetaParam fp, AppLocalizations l) {
  final o = optionsOf(fp);
  if (o != null) return o;
  if (fp.dataType == 'boolean') return [(id: '1', label: l.yes), (id: '0', label: l.no)];
  return null;
}

/// The text of a filter value on a chip: its option label, Yes/No, or the lookup label.
String filterValueText(MetaParam fp, String value, {required AppLocalizations l, LookupService? lookups}) {
  final c = _choices(fp, l);
  if (c != null) return c.where((o) => o.id == value).firstOrNull?.label ?? value;
  if (isLookup(fp)) {
    final spec = lookupSpecOf(fp);
    return (spec == null ? null : lookups?.cachedText(spec, value)) ?? '…';
  }
  return value;
}

/// Opens the filter sheet; resolves to the new filter values, or null when dismissed.
/// [query] is the grid's current query (search, filter, scope) for the facet counts.
Future<Map<String, String>?> showFilterSheet(
  BuildContext context, {
  required int gridMetaId,
  required List<MetaParam> filters,
  required Map<String, String> values,
  Map<String, dynamic> query = const {},
}) =>
    showSnapSheet<Map<String, String>>(
      context,
      initial: SnapHeight.half,
      builder: (_) => FilterSheet(gridMetaId: gridMetaId, filters: filters, values: values, query: query),
    );

class FilterSheet extends ConsumerStatefulWidget {
  final int gridMetaId;
  final List<MetaParam> filters;
  final Map<String, String> values;
  final Map<String, dynamic> query;

  const FilterSheet({super.key, required this.gridMetaId, required this.filters, required this.values, this.query = const {}});

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late final Map<String, String> _draft = {...widget.values};
  // field -> value -> count; null until loaded (or when the facets call failed).
  Map<String, Map<String, int>>? _facets;

  @override
  void initState() {
    super.initState();
    _loadFacets();
  }

  Future<void> _loadFacets() async {
    final fields = [for (final f in widget.filters) if (filterKind(f) == FilterKind.list) pathOf(f)];
    if (fields.isEmpty) return;
    final q = widget.query;
    try {
      final r = await ref.read(apiClientProvider).get<dynamic>('/metas/${widget.gridMetaId}/facets', query: {
        // Indexed keys: Laravel reads fields[0]=a&fields[1]=b as an array.
        'fields': {for (var i = 0; i < fields.length; i++) '$i': fields[i]},
        'search': q['search'],
        'filter': q['filter'],
        'scope': q['scope'],
      });
      final out = <String, Map<String, int>>{};
      if (r is Map) {
        r.forEach((k, v) {
          if (v is! List) return;
          out['$k'] = {
            for (final e in v)
              if (e is Map && e['value'] != null) '${e['value']}': e['count'] is num ? (e['count'] as num).toInt() : 0,
          };
        });
      }
      final lookups = ref.read(lookupServiceProvider);
      await Future.wait([
        for (final f in widget.filters)
          if (isLookup(f) && lookupSpecOf(f) != null && out[pathOf(f)] != null) lookups.prefetch(lookupSpecOf(f)!, out[pathOf(f)]!.keys),
      ]);
      if (mounted) setState(() => _facets = out);
    } catch (_) {
      // No counts; the sheet still works.
    }
  }

  void _set(String path, String v) => setState(() {
        if (v.isEmpty) {
          _draft.remove(path);
        } else {
          _draft[path] = v;
        }
      });

  Widget _title(MetaParam fp, ThemeData theme) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(fp.isRequired ? '${fp.label} *' : fp.label, style: theme.textTheme.labelLarge),
      );

  Widget _chips(MetaParam fp, List<({String id, String label})> choices, Map<String, int>? counts, ThemeData theme) {
    final path = pathOf(fp);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _title(fp, theme),
        Wrap(spacing: 8, runSpacing: 4, children: [
          for (final c in choices)
            ChoiceChip(
              label: Text(counts == null ? c.label : '${c.label} (${counts[c.id] ?? 0})'),
              selected: _draft[path] == c.id,
              onSelected: (on) => _set(path, on ? c.id : ''),
            ),
        ]),
      ],
    );
  }

  Widget _field(MetaParam fp, AppLocalizations l, ThemeData theme) {
    final path = pathOf(fp);
    final counts = _facets?[path];
    if (filterKind(fp) == FilterKind.list) {
      final choices = _choices(fp, l);
      if (choices != null) return _chips(fp, choices, counts, theme);
      if (counts != null && counts.isNotEmpty) {
        final lookups = ref.read(lookupServiceProvider);
        final spec = lookupSpecOf(fp);
        final ids = {...counts.keys, if (_draft[path] != null) _draft[path]!};
        return _chips(fp, [
          for (final id in ids) (id: id, label: (spec == null ? null : lookups.cachedText(spec, id)) ?? '#$id'),
        ], counts, theme);
      }
    }
    final v = _draft[path];
    return FieldInput(
      p: fp,
      value: fp.dataType == 'boolean' ? v == '1' : (v ?? ''),
      onChanged: (x) => _set(path, x is bool ? (x ? '1' : '') : '$x'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(l.filter, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final fp in widget.filters)
                    Padding(padding: const EdgeInsets.only(bottom: 16), child: _field(fp, l, theme)),
                ],
              ),
            ),
          ),
          Row(children: [
            Expanded(child: SoftButton(onPressed: () => Navigator.of(context).pop(<String, String>{}), child: Text(l.clear))),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                onPressed: () => Navigator.of(context).pop({
                  for (final e in _draft.entries)
                    if (e.value.isNotEmpty) e.key: e.value,
                }),
                child: Text(l.apply),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
