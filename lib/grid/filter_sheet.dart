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
import '../widgets/row_group.dart';
import '../widgets/tab_chip.dart';
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

/// What the filter sheet hands back: the filter values, and the column to sort by (null: the
/// grid's own order) with its direction, asc or desc.
typedef FilterPick = ({Map<String, String> filter, String? sort, String dir});

/// Opens the filter sheet; resolves to the new filters and order, or null when dismissed.
/// [query] is the grid's current query (search, filter, scope) for the facet counts. [sortable]
/// are the columns it can be sorted by; none hides the order part.
Future<FilterPick?> showFilterSheet(
  BuildContext context, {
  required int gridMetaId,
  required List<MetaParam> filters,
  required Map<String, String> values,
  Map<String, dynamic> query = const {},
  List<MetaParam> sortable = const [],
  String? sort,
  String dir = 'asc',
}) =>
    showSnapSheet<FilterPick>(
      context,
      initial: SnapHeight.half,
      builder: (_) => FilterSheet(
          gridMetaId: gridMetaId, filters: filters, values: values, query: query, sortable: sortable, sort: sort, dir: dir),
    );

class FilterSheet extends ConsumerStatefulWidget {
  final int gridMetaId;
  final List<MetaParam> filters;
  final Map<String, String> values;
  final Map<String, dynamic> query;
  final List<MetaParam> sortable;
  final String? sort;
  final String dir;

  const FilterSheet({
    super.key,
    required this.gridMetaId,
    required this.filters,
    required this.values,
    this.query = const {},
    this.sortable = const [],
    this.sort,
    this.dir = 'asc',
  });

  @override
  ConsumerState<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<FilterSheet> {
  late final Map<String, String> _draft = {...widget.values};
  late String? _sort = widget.sort;
  late String _dir = widget.dir;
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

  /// A filter's choices to tick: its options or Yes/No, else the values the facets found for a
  /// lookup (with the picked one kept). Null: it is typed or picked in a field row instead.
  List<({String id, String label})>? _listOf(MetaParam fp, AppLocalizations l) {
    if (filterKind(fp) != FilterKind.list) return null;
    final choices = _choices(fp, l);
    if (choices != null) return choices;
    final path = pathOf(fp);
    final counts = _facets?[path];
    if (counts == null || counts.isEmpty) return null;
    final lookups = ref.read(lookupServiceProvider);
    final spec = lookupSpecOf(fp);
    return [
      for (final id in {...counts.keys, if (_draft[path] != null) _draft[path]!})
        (id: id, label: (spec == null ? null : lookups.cachedText(spec, id)) ?? '#$id'),
    ];
  }

  /// A list filter: a heading, then its choices as chips with their counts.
  Widget _choiceGroup(MetaParam fp, List<({String id, String label})> choices) {
    final path = pathOf(fp);
    final counts = _facets?[path];
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      RowGroupHeading(fp.isRequired ? '${fp.label} *' : fp.label),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Wrap(spacing: 8, runSpacing: 4, children: [
          for (final c in choices)
            TabChip(
              label: c.label,
              selected: _draft[path] == c.id,
              trailing: counts == null ? null : Text('${counts[c.id] ?? 0}'),
              onTap: () => _set(path, _draft[path] == c.id ? '' : c.id),
            ),
        ]),
      ),
    ]);
  }

  /// The order part: a chip per column (tap the picked one again for the grid's own order), then
  /// the direction once a column is picked.
  List<Widget> _orderGroups(AppLocalizations l) => [
        RowGroupHeading(l.sortBy),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Wrap(spacing: 8, runSpacing: 4, children: [
            for (final p in widget.sortable)
              TabChip(
                label: p.label,
                selected: _sort == p.paramName,
                onTap: () => setState(() => _sort = _sort == p.paramName ? null : p.paramName),
              ),
          ]),
        ),
        if (_sort != null) ...[
          RowGroupHeading(l.sortOrder),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Wrap(spacing: 8, runSpacing: 4, children: [
              for (final (d, label, icon) in [('asc', l.ascending, Icons.arrow_upward_rounded), ('desc', l.descending, Icons.arrow_downward_rounded)])
                TabChip(label: label, selected: _dir == d, trailing: Icon(icon), onTap: () => setState(() => _dir = d)),
            ]),
          ),
        ],
      ];

  Widget _fieldRow(MetaParam fp) {
    final path = pathOf(fp);
    final v = _draft[path];
    return FieldInput(
      p: fp,
      value: fp.dataType == 'boolean' ? v == '1' : (v ?? ''),
      row: true,
      onChanged: (x) => _set(path, x is bool ? (x ? '1' : '') : '$x'),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    // Typed and picked filters first, as one block of rows; then each list of choices.
    final lists = {for (final fp in widget.filters) fp: _listOf(fp, l)};
    final typed = [for (final e in lists.entries) if (e.value == null) e.key];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 0, 4, 12),
            child: Text(l.filter, style: theme.textTheme.titleLarge),
          ),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (typed.isNotEmpty) RowGroup(indent: 14, children: [for (final fp in typed) _fieldRow(fp)]),
                  for (final e in lists.entries)
                    if (e.value != null) _choiceGroup(e.key, e.value!),
                  if (widget.sortable.isNotEmpty) ..._orderGroups(l),
                ],
              ),
            ),
          ),
          Row(children: [
            Expanded(
              child: SoftButton(
                onPressed: () => Navigator.of(context).pop<FilterPick>((filter: <String, String>{}, sort: null, dir: 'asc')),
                child: Text(l.clear),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: GradientButton(
                onPressed: () => Navigator.of(context).pop<FilterPick>((
                  filter: {
                    for (final e in _draft.entries)
                      if (e.value.isNotEmpty) e.key: e.value,
                  },
                  sort: _sort,
                  dir: _dir,
                )),
                child: Text(l.apply),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}
