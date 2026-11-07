import 'dart:convert';

import 'package:intl/intl.dart';

import '../api/models.dart';
import '../l10n/app_localizations.dart';

/// Resolves the display text of a looked-up value (Task 6 supplies it). Null means unknown.
typedef LookupText = String? Function(MetaParam p, Object? value);

/// Port of the web `lookupFields`: the looked-up record's label and value fields.
({String? label, String value}) lookupFields(MetaParam p) {
  final label = (p.displayAs?.isNotEmpty ?? false) ? p.displayAs : (p.displayField?.isNotEmpty ?? false) ? p.displayField : null;
  final value = (p.valueField?.isNotEmpty ?? false) ? p.valueField! : 'id';
  return (label: label, value: value);
}

/// Port of the web `rowLabel`: the labelField, else the first text value, else `#id`.
String rowLabel(Map<String, dynamic> row, String? labelField) {
  if (labelField != null && row[labelField] != null) return '${row[labelField]}';
  for (final e in row.entries) {
    if (e.key != 'id' && e.value is String) return e.value as String;
  }
  return '#${row['id']}';
}

bool isLookup(MetaParam p) => p.isSelect && p.refMetaId != null;

bool _truthy(Object? v) => v == true || v == 1 || v == '1' || v == 'true';

String _group(Object? value, {required int min, required int max}) {
  final n = value is num ? value : num.tryParse('$value');
  if (n == null || !n.isFinite) return '$value';
  final f = NumberFormat.decimalPatternDigits(locale: 'en_US', decimalDigits: max);
  f.minimumFractionDigits = min;
  return f.format(n);
}

/// Number of files in a singlefile/multifile/document value (a JSON string or a list).
int fileCount(Object? value) {
  var v = value;
  if (v is String) {
    try {
      v = jsonDecode(v);
    } catch (_) {
      return v == null || (v as String).isEmpty ? 0 : 1;
    }
  }
  if (v is List) return v.length;
  if (v is Map) return 1;
  return v == null ? 0 : 1;
}

String _date(String s) => s.length >= 10 ? s.substring(0, 10) : s;

String _dateTime(String s) {
  final t = s.replaceFirst('T', ' ');
  return t.length >= 16 ? t.substring(0, 16) : _date(t);
}

/// A cell's text the way the web `Cell` shows it. Null or '' gives ''.
String cellText(MetaParam p, Map<String, dynamic> row, {LookupText? lookupText, AppLocalizations? l10n}) {
  final value = row[p.paramName];
  if (value == null || value == '') return '';

  if (isLookup(p)) return lookupText?.call(p, value) ?? '#$value';

  if (p.renderType == 'active') {
    return _truthy(value) ? (l10n?.active ?? 'Active') : (l10n?.inactive ?? 'Inactive');
  }
  if (p.renderType == 'status') {
    final s = '$value';
    return s[0].toUpperCase() + s.substring(1);
  }
  if (p.renderType == 'money') return _group(value, min: 2, max: 2);

  switch (p.dataType) {
    case 'singlefile':
    case 'multifile':
    case 'document':
      return '\u{1F4CE} ${fileCount(value)}';
    case 'boolean':
      return _truthy(value) ? (l10n?.yes ?? 'Yes') : (l10n?.no ?? 'No');
    case 'date':
      return _date('$value');
    case 'datetime':
      return _dateTime('$value');
    case 'decimal':
      return _group(value, min: 0, max: 2);
    case 'integer':
      return _group(value, min: 0, max: 0);
    default:
      return '$value';
  }
}
