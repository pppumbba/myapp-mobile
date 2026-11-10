import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../auth/session.dart';

/// A meta with its params (a tree with `children`), loaded the way the web `loadDef` does.
class MetaDef {
  final Meta meta;
  final List<MetaParam> params;
  MetaDef(this.meta, this.params);
}

/// Cached until the session scope changes (sign-out, customer, language) or a manual `ref.invalidate(metaDefProvider(id))`.
final metaDefProvider = FutureProvider.family<MetaDef, int>(retry: noRetry, (ref, id) async {
  ref.watch(sessionScopeProvider);
  final client = ref.read(apiClientProvider);
  final r = await Future.wait<dynamic>([
    client.get<dynamic>('/metas/$id', query: {'translated': '1'}),
    client.get<dynamic>('/metas/$id/params', query: {'effective': '1', 'translated': '1'}),
  ]);
  return MetaDef(
    Meta.fromJson(Map<String, dynamic>.from(r[0] as Map)),
    [for (final p in (r[1] as List)) MetaParam.fromJson(Map<String, dynamic>.from(p as Map))],
  );
});

final actionsProvider = FutureProvider.family<List<MetaAction>, int>(retry: noRetry, (ref, id) async {
  ref.watch(sessionScopeProvider);
  final r = await ref.read(apiClientProvider).get<dynamic>(
    '/metas/$id/actions',
    query: {'effective': '1', 'translated': '1'},
  );
  return [for (final a in (r as List)) MetaAction.fromJson(Map<String, dynamic>.from(a as Map))];
});

/// The type code of a meta (`datagrid`, `form`, ...), or null when it cannot be loaded.
/// Only 403/404 (gone or not allowed) count as "no type"; other failures are rethrown so they are not cached as null.
final metaTypeProvider = FutureProvider.family<String?, int>(retry: noRetry, (ref, id) async {
  try {
    return (await ref.watch(metaDefProvider(id).future)).meta.type;
  } on ApiError catch (e) {
    if (e.status == 403 || e.status == 404) return null;
    rethrow;
  }
});

/// Riverpod retries failed providers by default; the UI shows the error with a Retry button instead.
Duration? noRetry(int retryCount, Object error) => null;
