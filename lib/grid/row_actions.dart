import '../api/models.dart';
import 'grid_query.dart';

typedef Can = bool Function(int? metaId, String ability);

List<MetaAction> _ordered(Iterable<MetaAction> a) => [...a]..sort((x, y) => x.orderNumber.compareTo(y.orderNumber));

/// Whether the user may press [a]: add/edit/delete need create/edit/delete on the grid,
/// every other action needs view on its form or target meta.
bool canRun(MetaAction a, {required Can can, required int gridMetaId}) => switch (a.action) {
      'add' => can(gridMetaId, 'create'),
      'edit' => can(gridMetaId, 'edit'),
      'delete' => can(gridMetaId, 'delete'),
      _ => can(a.formMetaId ?? a.getMetaId, 'view'),
    };

/// Buttons of one card: `show_in_row`, or a toolbar button that needs a row (the phone has no toolbar).
List<MetaAction> rowActions(List<MetaAction> all, {required Can can, required int gridMetaId}) => _ordered(all.where((a) =>
    a.action != 'add' && (a.showInRow || (a.needsRow && a.showInToolbar)) && canRun(a, can: can, gridMetaId: gridMetaId)));

/// Toolbar buttons that need no row, other than add: they go in the ⋮ menu.
List<MetaAction> toolbarActions(List<MetaAction> all, {required Can can, required int gridMetaId}) => _ordered(all.where(
    (a) => a.action != 'add' && a.showInToolbar && !a.needsRow && canRun(a, can: can, gridMetaId: gridMetaId)));

/// The `add` action (the FAB), when the user can create.
MetaAction? addAction(List<MetaAction> all, {required Can can, required int gridMetaId}) =>
    _ordered(all.where((a) => a.action == 'add')).where((a) => can(gridMetaId, 'create')).firstOrNull;

/// The record an action works on: its `id` param, else the row's primary key.
String? actionRecordId(MetaAction a, Map<String, dynamic> row, String primaryKey) {
  final id = actionParams(a, row)['id'];
  if (id != null) return id;
  final v = row[primaryKey];
  return v == null || '$v'.isEmpty ? null : '$v';
}
