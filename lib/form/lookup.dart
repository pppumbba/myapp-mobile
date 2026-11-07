import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart';
import '../grid/cells.dart';

/// Which grid a lookup reads and which of its fields hold the value and the label.
/// A null [displayField] means the label is chosen by [rowLabel]'s fallback.
class LookupSpec {
  final int gridMetaId;
  final String valueField;
  final String? displayField;
  const LookupSpec({required this.gridMetaId, required this.valueField, this.displayField});

  @override
  bool operator ==(Object other) =>
      other is LookupSpec && other.gridMetaId == gridMetaId && other.valueField == valueField && other.displayField == displayField;

  @override
  int get hashCode => Object.hash(gridMetaId, valueField, displayField);
}

/// The lookup of a param, or null when it has no referenced grid. `filter_as` keys
/// (`ref_meta_id`, `display_field`, `display_as`, `value_field`) override the param's own.
LookupSpec? lookupSpecOf(MetaParam p) {
  final f = p.filterAs;
  String? str(String k) {
    final v = f?[k];
    return v == null || '$v'.isEmpty ? null : '$v';
  }

  final ref = int.tryParse(str('ref_meta_id') ?? '') ?? p.refMetaId;
  if (ref == null) return null;
  final own = lookupFields(p);
  return LookupSpec(
    gridMetaId: ref,
    valueField: str('value_field') ?? own.value,
    displayField: str('display_as') ?? str('display_field') ?? own.label,
  );
}

/// Resolves the display text of looked-up values and remembers it until [clear].
class LookupService {
  final ApiClient _client;
  LookupService(this._client);

  // First page of a lookup grid, value -> label (as the web lookupRows).
  final Map<LookupSpec, Future<Map<String, String>>> _pages = {};
  final Map<LookupSpec, Map<String, String>> _pageDone = {};
  // Per (spec, value) answers, including "not found" (null).
  final Map<(LookupSpec, String), Future<String?>> _values = {};
  final Map<(LookupSpec, String), String?> _valueDone = {};

  String _labelOf(LookupSpec s, Map<String, dynamic> row) => rowLabel(row, s.displayField);

  Future<Map<String, String>> _firstPage(LookupSpec s) => _pages.putIfAbsent(s, () async {
        try {
          final r = await _client.get<dynamic>('/metas/${s.gridMetaId}/data', query: {'per_page': 100});
          final out = <String, String>{};
          for (final row in DataPage.fromJson(Map<String, dynamic>.from(r as Map)).rows) {
            final v = row[s.valueField];
            if (v != null) out['$v'] = _labelOf(s, row);
          }
          _pageDone[s] = out;
          return out;
        } catch (_) {
          _pages.remove(s);
          rethrow;
        }
      });

  Future<String?> _byScope(LookupSpec s, String value) async {
    final r = await _client.get<dynamic>('/metas/${s.gridMetaId}/data', query: {
      'scope': {s.valueField: value},
      'per_page': 1,
    });
    final rows = DataPage.fromJson(Map<String, dynamic>.from(r as Map)).rows;
    return rows.isEmpty ? null : _labelOf(s, rows.first);
  }

  /// The label of [value]: from the grid's first page, else one request by `scope[valueField]`.
  /// Null when the record is not found. Failures are thrown and not cached.
  Future<String?> lookupText(LookupSpec s, Object? value) {
    if (value == null || value == '') return Future.value(null);
    final key = (s, '$value');
    return _values.putIfAbsent(key, () async {
      try {
        final hit = (await _firstPage(s))['$value'];
        final text = hit ?? await _byScope(s, '$value');
        _valueDone[key] = text;
        return text;
      } catch (_) {
        _values.remove(key);
        rethrow;
      }
    });
  }

  /// Sync answer for [value] if it was already resolved, else null.
  String? cachedText(LookupSpec s, Object? value) {
    if (value == null) return null;
    final key = (s, '$value');
    return _valueDone[key] ?? _pageDone[s]?['$value'];
  }

  /// Resolves all [values] so [cachedText] can answer. Failed lookups are skipped.
  Future<void> prefetch(LookupSpec s, Iterable<Object?> values) async {
    final seen = <String>{};
    await Future.wait([
      for (final v in values)
        if (v != null && v != '' && seen.add('$v')) lookupText(s, v).then<void>((_) {}, onError: (_) {}),
    ]);
  }

  /// Forget everything; call after any successful write.
  void clear() {
    _pages.clear();
    _pageDone.clear();
    _values.clear();
    _valueDone.clear();
  }
}

final lookupServiceProvider = Provider<LookupService>((ref) {
  ref.watch(sessionProvider.select((s) => s.user?['id']));
  final client = ref.read(apiClientProvider);
  final service = LookupService(client);
  client.addWriteListener(service.clear);
  ref.onDispose(() => client.removeWriteListener(service.clear));
  return service;
});
