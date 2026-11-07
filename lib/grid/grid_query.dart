import '../api/models.dart';
import '../form/values.dart';
import 'cells.dart';

/// One list request (GET /metas/{id}/data): `filter` reaches is_criteria params, `scope` always applies.
class GridQuery {
  String search;
  Map<String, String> filter;
  Map<String, String> scope;
  int page;
  int perPage;
  String? sort;
  String dir;

  GridQuery({
    this.search = '',
    Map<String, String>? filter,
    Map<String, String>? scope,
    this.page = 1,
    this.perPage = 20,
    this.sort,
    this.dir = 'asc',
  })  : filter = filter ?? {},
        scope = scope ?? {};

  /// Empty search, filters and scope values are left out.
  Map<String, dynamic> toQuery() {
    Map<String, String> clean(Map<String, String> m) => {
          for (final e in m.entries)
            if (e.value.isNotEmpty) e.key: e.value,
        };
    final f = clean(filter);
    final s = clean(scope);
    return {
      if (search.trim().isNotEmpty) 'search': search.trim(),
      'page': page,
      'per_page': perPage,
      if (sort != null && sort!.isNotEmpty) ...{'sort': sort, 'dir': dir},
      if (f.isNotEmpty) 'filter': f,
      if (s.isNotEmpty) 'scope': s,
    };
  }
}

/// A grid's drilldown (json_config.drilldown), as the web drilldown.ts reads it.
class Drilldown {
  final int metaId;
  final Map<String, String> params;
  final String? label;
  final String? openIn;
  const Drilldown({required this.metaId, this.params = const {}, this.label, this.openIn});
}

Drilldown? drilldownOf(Map<String, dynamic> jsonConfig) {
  final d = jsonConfig['drilldown'];
  if (d is! Map) return null;
  final id = d['meta_id'] is num ? (d['meta_id'] as num).toInt() : int.tryParse('${d['meta_id']}');
  if (id == null || id <= 0) return null;
  final p = d['params'];
  return Drilldown(
    metaId: id,
    params: {if (p is Map) for (final e in p.entries) '${e.key}': '${e.value}'},
    label: d['label'] is String ? d['label'] as String : null,
    openIn: d['open_in'] is String ? d['open_in'] as String : null,
  );
}

/// Port of the web `drillParams`: `{target: source}` from [row]; a source starting with '='
/// is fixed text. Null and empty values are skipped.
Map<String, String> drillParams(Map<String, String> params, Map<String, dynamic> row) {
  final out = <String, String>{};
  params.forEach((target, source) {
    final v = source.startsWith('=') ? source.substring(1) : row[source];
    if (v == null || '$v'.isEmpty) return;
    out[target] = '$v';
  });
  return out;
}

/// An action's `json_config.params` filled from [row] (the same mapping as a drilldown).
Map<String, String> actionParams(MetaAction a, Map<String, dynamic> row) => drillParams(a.params, row);

/// Port of the web `asFilter`: `filter_as` keys override the param's own, `filter_as.options`
/// replaces the options, and a mandatory filter is marked required.
MetaParam asFilter(MetaParam p) {
  final f = p.filterAs ?? const <String, dynamic>{};
  String? str(String k, String? own) => f.containsKey(k) ? (f[k] == null || '${f[k]}'.isEmpty ? null : '${f[k]}') : own;
  final isSelect = f.containsKey('is_select') ? (f['is_select'] == true || f['is_select'] == 1 || f['is_select'] == '1') : p.isSelect;
  final ref = f.containsKey('ref_meta_id') ? int.tryParse('${f['ref_meta_id']}') : p.refMetaId;
  final json = {...p.jsonConfig, if (f['options'] is List) 'options': f['options']};
  return MetaParam(
    id: p.id,
    parentId: p.parentId,
    refMetaId: ref,
    orderNumber: p.orderNumber,
    fieldPath: p.fieldPath,
    paramName: p.paramName,
    labelName: p.labelName,
    dataType: p.dataType,
    renderType: p.renderType,
    iconCls: p.iconCls,
    isShow: true,
    isRequired: p.isMandatoryCriteria,
    isCriteria: true,
    isMandatoryCriteria: p.isMandatoryCriteria,
    isSelect: isSelect,
    displayAs: str('display_as', p.displayAs),
    displayField: str('display_field', p.displayField),
    valueField: str('value_field', p.valueField),
    defaultValue: p.defaultValue,
    jsonConfig: json,
  );
}

enum FilterKind { list, date, number, text }

/// Port of GridSidebar `kindOf`: options, lookups and booleans are lists (they get facet counts).
FilterKind filterKind(MetaParam p) {
  if (optionsOf(p) != null || isLookup(p) || p.dataType == 'boolean') return FilterKind.list;
  if (p.dataType == 'date' || p.dataType == 'datetime') return FilterKind.date;
  if (p.dataType == 'integer' || p.dataType == 'decimal') return FilterKind.number;
  return FilterKind.text;
}

/// Every param of the tree, depth first.
Iterable<MetaParam> allParams(List<MetaParam> params) sync* {
  for (final p in params) {
    yield p;
    yield* allParams(p.children);
  }
}

/// The grid's filter params (is_criteria, through [asFilter]) in order.
List<MetaParam> filterParams(List<MetaParam> gridParams) =>
    [for (final p in gridParams) if (p.isCriteria) asFilter(p)]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
