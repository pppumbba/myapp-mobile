import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/models.dart';
import '../dashboard/dashboard_screen.dart';
import '../form/form_screen.dart';
import '../grid/grid_screen.dart';
import '../meta/defs.dart';
import '../widgets/skeleton.dart';
import '../widgets/error_state.dart';
import 'open_on_web.dart';
import 'tabs_screen.dart';
import 'workspace_screen.dart';

/// Meta types the app shows natively. The menu leaves everything else out.
const supportedTypes = {'datagrid', 'form', 'dashboard', 'tabs', 'workspace'};

/// One screen of the app, chosen by the meta type.
class ScreenView extends ConsumerWidget {
  final int metaId;
  final Map<String, String> fixed;
  final Map<String, String> filters;

  const ScreenView({super.key, required this.metaId, this.fixed = const {}, this.filters = const {}});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final def = ref.watch(metaDefProvider(metaId));
    return def.when(
      loading: () => const CardListSkeleton(),
      error: (e, _) => ErrorState.of(context, e, onRetry: () => ref.invalidate(metaDefProvider(metaId))),
      data: (d) => screenFor(d.meta, params: d.params, fixed: fixed, filters: filters),
    );
  }
}

/// The single switch on `meta.type`: a grid as cards; a form opens as a new record; a dashboard as
/// chart cards; tabs as a strip of their screens; a workspace as one record (a drilldown's `id`) and its sections.
Widget screenFor(Meta meta, {List<MetaParam> params = const [], Map<String, String> fixed = const {}, Map<String, String> filters = const {}}) {
  switch (meta.type) {
    case 'datagrid':
      return GridScreen(key: ValueKey(meta.id), metaId: meta.id, fixed: fixed, filters: filters);
    case 'form':
      return FormScreen(key: ValueKey(meta.id), formMetaId: meta.id, fixed: fixed);
    case 'dashboard':
      return DashboardScreen(key: ValueKey(meta.id), meta: meta, params: params);
    case 'tabs':
      return TabsScreen(key: ValueKey(meta.id), meta: meta, params: params);
    case 'workspace':
      return WorkspaceScreen(key: ValueKey('${meta.id}-${fixed['id']}'), meta: meta, params: params, recordId: fixed['id']);
    default:
      return OpenOnWeb(meta);
  }
}

