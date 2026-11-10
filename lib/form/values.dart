import 'dart:convert';

import '../api/models.dart';

/// A form's values as its inputs hold them: a String, or a bool for boolean fields (as on the web).
/// A file field holds its files as a JSON list (see [filesOf]).
typedef Values = Map<String, Object>;

/// Data types this plan leaves out of forms (lines, widgets come later; files are [isFileField]).
const _notInForm = {'detail', 'subgrid', 'singlefile', 'multifile', 'document', 'widget'};

const fileTypes = {'singlefile', 'multifile'};

/// The key a param's value lives under.
String pathOf(MetaParam p) => p.fieldPath ?? p.paramName;

/// Port of the web `visibleParams`, minus the types this plan leaves out.
bool isFormField(MetaParam p) => p.isShow && !p.isPrimary && !_notInForm.contains(p.dataType) && p.renderType != 'widget';

/// A field that takes uploads. Forms have them; detail lines don't (the server doesn't keep files
/// on lines yet), so [files] is set only for a form's own fields.
bool isFileField(MetaParam p) => p.isShow && !p.isPrimary && fileTypes.contains(p.dataType);

bool _field(MetaParam p, bool files) => isFormField(p) || (files && isFileField(p));

List<MetaParam> formFields(List<MetaParam> params, {bool files = false}) =>
    [...params.where((p) => _field(p, files))]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));

/// The files a file field's value holds: {id, file_name, file_extension, file_size, description, …}.
List<Map<String, dynamic>> filesOf(Object? value) {
  if (value is! String || value.isEmpty) return const [];
  try {
    final v = jsonDecode(value);
    if (v is List) return [for (final f in v) if (f is Map && f['id'] != null) Map<String, dynamic>.from(f)];
  } catch (_) {}
  return const [];
}

/// A record's files (a list for multifile, one file or null for singlefile) as a field value.
String _filesValue(Object? raw) {
  final list = raw is List ? raw : (raw is Map ? [raw] : const []);
  return list.isEmpty ? '' : jsonEncode(list);
}

/// The is_primary param's field path, else `id`.
String primaryKey(List<MetaParam> params) {
  for (final p in params) {
    if (p.isPrimary) return pathOf(p);
  }
  return 'id';
}

bool _isTrue(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

String _two(int n) => n.toString().padLeft(2, '0');
String ymd(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Port of the web `fillTokens`: `{today}`, `{user_id}`, `{user_name}`, `{user_email}`, else the
/// session value. [session] returns null for a path that is not set (the token stays as is) and
/// '' for one that is set to null.
String fillTokens(String text, {String? Function(String path)? session, Map<String, dynamic>? user, DateTime? now}) =>
    text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
      final token = m.group(1)!;
      switch (token) {
        case 'today':
          return ymd(now ?? DateTime.now());
        case 'user_id':
          return '${user?['id'] ?? ''}';
        case 'user_name':
          return '${user?['name'] ?? ''}';
        case 'user_email':
          return '${user?['email'] ?? ''}';
      }
      return session?.call(token) ?? m.group(0)!;
    });

String _inputValue(MetaParam p, Object raw) {
  final s = '$raw';
  if (p.dataType == 'date') return s.length > 10 ? s.substring(0, 10) : s;
  if (p.dataType == 'datetime') {
    final t = s.replaceFirst(' ', 'T');
    return t.length > 16 ? t.substring(0, 16) : t;
  }
  return s;
}

/// Port of the web `startValues`: the record's values, else [defaults], else each param's
/// default_value with its tokens filled. [fixed] wins over all of them.
Values initialValues(
  List<MetaParam> params, {
  Map<String, dynamic>? record,
  Map<String, String> fixed = const {},
  Map<String, String> defaults = const {},
  String? Function(String path)? session,
  Map<String, dynamic>? user,
  DateTime? now,
  bool files = false,
}) {
  final out = <String, Object>{};
  for (final p in params.where((p) => _field(p, files))) {
    if (isFileField(p)) {
      out[pathOf(p)] = _filesValue(record?[pathOf(p)]);
      continue;
    }
    final path = pathOf(p);
    Object? raw;
    if (fixed.containsKey(path)) {
      raw = fixed[path];
    } else if (record != null) {
      raw = record[path];
    } else {
      raw = defaults[path] ?? (p.defaultValue == null ? null : fillTokens(p.defaultValue!, session: session, user: user, now: now));
    }
    if (p.dataType == 'boolean') {
      out[path] = _isTrue(raw);
    } else {
      out[path] = raw == null ? '' : _inputValue(p, raw);
    }
  }
  return out;
}

num? _number(String v, {required bool integer}) {
  final s = v.replaceAll(',', '').trim();
  return integer ? (int.tryParse(s) ?? num.tryParse(s)) : num.tryParse(s);
}

/// Port of the web `toPayload` plus what FormView adds: [fixed] values and `_context`.
Map<String, dynamic> toPayload(List<MetaParam> params, Values v, {required int? appMetaId, Map<String, String> fixed = const {}, bool files = false}) {
  final out = <String, dynamic>{};
  for (final p in params.where((p) => _field(p, files))) {
    final path = pathOf(p);
    final value = v[path];
    if (isFileField(p)) {
      // The files by id, with their descriptions; one or null for a singlefile field.
      final items = [for (final f in filesOf(value)) {'id': f['id'], 'description': f['description']}];
      out[path] = p.dataType == 'singlefile' ? items.firstOrNull : items;
      continue;
    }
    if (value is bool) {
      out[path] = value;
    } else if (value == null || value == '') {
      out[path] = null;
    } else if (p.dataType == 'integer' || p.dataType == 'decimal') {
      out[path] = _number('$value', integer: p.dataType == 'integer') ?? '$value';
    } else if (p.dataType == 'datetime') {
      final s = '${'$value'.replaceFirst('T', ' ')}:00';
      out[path] = s.length > 19 ? s.substring(0, 19) : s;
    } else {
      out[path] = '$value';
    }
  }
  out.addAll(fixed);
  if (appMetaId != null) out['_context'] = {'app_meta_id': appMetaId};
  return out;
}

/// How a field numbers itself (json_config.autonumber with a String `format`), or null.
Map<String, dynamic>? autonumberOf(MetaParam p) {
  final a = p.jsonConfig['autonumber'];
  return a is Map && a['format'] is String ? Map<String, dynamic>.from(a) : null;
}

/// An autonumber the server fills in, shown read-only.
bool isAutoReadOnly(MetaParam p) => autonumberOf(p) != null && autonumberOf(p)!['editable'] != true;

/// The fields an autonumber depends on: its rules' fields and the `{field}` tokens of its formats.
List<String> autonumberFields(Map<String, dynamic> config) {
  final rules = [for (final r in (config['rules'] as List? ?? const [])) if (r is Map) r];
  final formats = ['${config['format']}', for (final r in rules) if (r['format'] is String) r['format'] as String];
  const builtIn = {'seq', 'yyyy', 'yy', 'MM', 'dd'};
  final tokens = [
    for (final f in formats)
      for (final m in RegExp(r'\{(\w+)(?::\d+)?\}').allMatches(f))
        if (!builtIn.contains(m.group(1))) m.group(1)!,
  ];
  return {for (final r in rules) if (r['field'] != null) '${r['field']}', ...tokens}.toList();
}

/// A param's fixed list of values (json_config.options) as (id, label), or null.
List<({String id, String label})>? optionsOf(MetaParam p) {
  final o = p.jsonConfig['options'];
  if (o is! List) return null;
  return [
    for (final x in o.map((e) => '$e')) (id: x, label: x.isEmpty ? x : x[0].toUpperCase() + x.substring(1)),
  ];
}

/// Fields of [params] that block a save: required, empty, and not boolean, autonumber or [hidden].
List<String> missingRequired(List<MetaParam> params, Values v, Set<String> hidden, {bool files = false}) => [
      for (final p in params.where((p) => _field(p, files)))
        if (p.isRequired &&
            p.dataType != 'boolean' &&
            autonumberOf(p) == null &&
            !hidden.contains(pathOf(p)) &&
            (isFileField(p) ? filesOf(v[pathOf(p)]).isEmpty : (v[pathOf(p)] == null || v[pathOf(p)] == '')))
          pathOf(p),
    ];

const formLayouts = {'sections', 'tabs', 'wizard'};

/// A param's group (json_config.group), '' when it has none.
String groupOf(MetaParam p) {
  final g = p.jsonConfig['group'];
  return g is String ? g.trim() : '';
}

class FormGroup {
  final String name;
  final List<MetaParam> fields;
  FormGroup(this.name, this.fields);
}

/// Port of the web `formGroups`: by group name in first-seen order (order_number), the ungrouped
/// first; a group named "General" takes the ungrouped in, in the first place.
List<FormGroup> formGroups(List<MetaParam> fields, {String generalName = 'General'}) {
  final items = [...fields]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber));
  final byName = <String, FormGroup>{};
  if (items.any((p) => groupOf(p) == '')) byName[''] = FormGroup('', []);
  for (final p in items) {
    byName.putIfAbsent(groupOf(p), () => FormGroup(groupOf(p), [])).fields.add(p);
  }
  final ungrouped = byName[''];
  final names = {generalName.toLowerCase(), 'general'};
  final general = byName.values.where((g) => g.name != '' && names.contains(g.name.toLowerCase())).firstOrNull;
  if (ungrouped != null && general != null) {
    // The merged group takes the ungrouped one's place, which is always first.
    byName.remove(general.name);
    byName[''] = FormGroup(general.name, [...ungrouped.fields, ...general.fields]..sort((a, b) => a.orderNumber.compareTo(b.orderNumber)));
  }
  return byName.values.toList();
}
