import '../api/models.dart';
import '../meta/defs.dart';
import 'values.dart';

/// How deep details go: a form's lines, their lines, and theirs (as the web DETAIL_DEPTH).
const detailDepth = 3;

/// A detail with its line form, and the details of that form's own lines.
class DetailNode {
  final MetaParam detail;
  final MetaDef def;
  final List<DetailNode> children;
  DetailNode(this.detail, this.def, this.children);

  String get path => pathOf(detail);
  String get name => detail.labelName?.isNotEmpty == true ? detail.labelName! : (def.meta.name ?? detail.paramName);
  bool get isOne => isOneToOne(detail);

  /// The line form's fields, less the one pointing back at the record above (the server fills it).
  List<MetaParam> get fields {
    final fk = detail.jsonConfig['foreign_key'];
    return [for (final p in formFields(def.params)) if (pathOf(p) != fk) p];
  }

  /// json_config.amount: one column as it is, or two multiplied; null when it has none.
  List<String>? get amount {
    final a = detail.jsonConfig['amount'];
    return a is List && a.isNotEmpty && a.length <= 2 ? [for (final c in a) '$c'] : null;
  }

  /// The field above that these lines add up into, when they have an amount.
  String? get totalField {
    final t = detail.jsonConfig['total_field'];
    return t is String && t.isNotEmpty && amount != null && !isOne ? t : null;
  }

  String? get criteria {
    final c = detail.jsonConfig['criteria'];
    return c is String ? c : null;
  }
}

/// A one-to-one detail (json_config.one): one record, sent as an object, always saved.
bool isOneToOne(MetaParam p) => p.jsonConfig['one'] == true;

/// A form's shown detail params that have a line form.
List<MetaParam> detailParams(List<MetaParam> params) =>
    [for (final p in params) if (p.isShow && p.dataType == 'detail' && p.refMetaId != null) p]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

/// A form's details as a tree, down to [detailDepth]; a form above is never repeated.
Future<List<DetailNode>> loadDetailTree(Future<MetaDef> Function(int id) load, MetaDef def, [List<int>? parents]) async {
  final above = parents ?? [def.meta.id];
  if (above.length > detailDepth) return const [];
  final details = [for (final d in detailParams(def.params)) if (!above.contains(d.refMetaId)) d];
  return Future.wait([
    for (final d in details)
      load(d.refMetaId!).then((child) async => DetailNode(d, child, await loadDetailTree(load, child, [...above, child.meta.id]))),
  ]);
}

/// One line being edited. [key] keeps it apart from the others; [id] is a saved line's primary key.
class Line {
  final String key;
  final String? id;
  final Values values;
  /// Its own lines, by sub-detail field path.
  final Map<String, List<Line>> sub;
  const Line({required this.key, this.id, required this.values, this.sub = const {}});

  Line copyWith({Values? values, Map<String, List<Line>>? sub}) => Line(key: key, id: id, values: values ?? this.values, sub: sub ?? this.sub);
}

int _seq = 0;

/// Starts a line's values (defaults, tokens) the way the form starts its own.
typedef StartValues = Values Function(List<MetaParam> params, Map<String, dynamic>? record);

/// A new, empty line; its own details start with no lines, a one-to-one with its one blank record.
Line blankLine(DetailNode node, StartValues start) => Line(
      key: 'new-${++_seq}',
      values: start(node.def.params, null),
      sub: {for (final c in node.children) c.path: c.isOne ? [blankLine(c, start)] : <Line>[]},
    );

/// Saved lines as the API sends them (each with its own lines under their fields) as editable lines.
/// A one-to-one arrives as one object or null and is always one line: its record, or a blank one.
List<Line> startLines(DetailNode node, Object? rows, StartValues start) {
  if (node.isOne) return rows is Map ? _toLines(node, [rows], start) : [blankLine(node, start)];
  return rows is List ? _toLines(node, [for (final r in rows) if (r is Map) r], start) : [];
}

List<Line> _toLines(DetailNode node, List<Map> rows, StartValues start) {
  final key = primaryKey(node.def.params);
  return [
    for (final r in rows.map(Map<String, dynamic>.from))
      Line(
        key: '${node.path}-${r[key]}',
        id: r[key] == null ? null : '${r[key]}',
        values: start(node.def.params, r),
        sub: {for (final c in node.children) c.path: startLines(c, r[c.path], start)},
      ),
  ];
}

num _numOf(Object? v) {
  if (v is num) return v;
  final s = '${v ?? ''}'.replaceAll(',', '').trim();
  if (s.isEmpty) return 0;
  return num.tryParse(s) ?? double.nan;
}

/// A line's amount: its one amount column, or the two multiplied. Null when the detail has none.
double? lineAmount(DetailNode node, Line line) {
  final a = node.amount;
  if (a == null) return null;
  final n = a.fold<num>(1, (p, c) => p * _numOf(line.values[c])).toDouble();
  return n.isFinite ? n : 0;
}

/// The lines' amounts added up.
double linesTotal(DetailNode node, List<Line> lines) => lines.fold(0, (s, l) => s + (lineAmount(node, l) ?? 0));

double round2(double v) => (v * 100).roundToDouble() / 100;

/// A total as a form value: whole numbers without decimals.
String totalText(double v) {
  final r = round2(v);
  return r == r.roundToDouble() ? '${r.round()}' : '$r';
}

/// The fields of a line those lines' own details add up into: total_field -> the sub-detail.
Map<String, DetailNode> subTotals(DetailNode node) => {for (final c in node.children) if (c.totalField != null) c.totalField!: c};

/// What the API takes for a detail: its lines, or for a one-to-one its one record.
Object? detailPayload(DetailNode node, List<Line> lines) {
  final out = linesPayload(node, lines);
  return node.isOne ? (out.firstOrNull) : out;
}

/// Lines as the API expects them: kept lines with their id, each with its own lines under their
/// fields, and the fields those lines add up into (total_field) filled with the sum.
List<Map<String, dynamic>> linesPayload(DetailNode node, List<Line> lines) {
  final key = primaryKey(node.def.params);
  return [
    for (final l in lines)
      {
        if (l.id != null) key: int.tryParse(l.id!) ?? l.id,
        ...toPayload(node.def.params, l.values, appMetaId: null),
        for (final c in node.children) ...{
          c.path: detailPayload(c, l.sub[c.path] ?? const []),
          if (c.totalField != null) c.totalField!: round2(linesTotal(c, l.sub[c.path] ?? const [])),
        },
      },
  ];
}

/// Required line fields still empty (not booleans, autonumbers or worked-out totals).
List<String> missingInLine(DetailNode node, Line line) =>
    missingRequired(node.fields, line.values, subTotals(node).keys.toSet());
