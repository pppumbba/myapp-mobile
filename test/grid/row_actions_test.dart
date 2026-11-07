import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/grid/row_actions.dart';

/// The work orders grid (meta 131) actions.
final workOrderActions = [
  for (final j in [
    {'id': 245, 'grid_meta_id': 131, 'action': 'add', 'label': 'Add', 'form_meta_id': 129, 'needs_row': 0, 'show_in_toolbar': 1, 'show_in_row': 0, 'order_number': 1},
    {'id': 246, 'grid_meta_id': 131, 'action': 'edit', 'label': 'Edit', 'form_meta_id': 129, 'needs_row': 1, 'show_in_toolbar': 1, 'show_in_row': 1, 'order_number': 2, 'json_config': {'params': {'id': 'id'}}},
    {'id': 247, 'grid_meta_id': 131, 'action': 'delete', 'label': 'Delete', 'form_meta_id': 129, 'needs_row': 1, 'show_in_toolbar': 1, 'show_in_row': 1, 'order_number': 3, 'json_config': {'params': {'id': 'id'}}},
    {'id': 248, 'grid_meta_id': 131, 'action': 'stage_query', 'label': 'Complete', 'form_meta_id': 130, 'needs_row': 1, 'show_in_toolbar': 1, 'show_in_row': 1, 'order_number': 4, 'json_config': {'params': {'work_order_id': 'id'}}},
  ])
    MetaAction.fromJson(j),
];

bool Function(int?, String) allow(Map<int, Set<String>> rights) => (id, ability) => id == null || (rights[id]?.contains(ability) ?? false);

void main() {
  test('rowActions hides delete without delete permission and keeps Complete', () {
    final can = allow({131: {'view', 'create', 'edit'}, 130: {'view'}});
    final r = rowActions(workOrderActions, can: can, gridMetaId: 131);
    expect(r.map((a) => a.label), ['Edit', 'Complete']);
    expect(addAction(workOrderActions, can: can, gridMetaId: 131)?.id, 245);
    expect(addAction(workOrderActions, can: allow({131: {'view'}}), gridMetaId: 131), isNull);
    expect(rowActions(workOrderActions, can: allow({131: {'edit', 'delete'}}), gridMetaId: 131).map((a) => a.label), ['Edit', 'Delete']);
  });

  test('rowActions treats needs_row toolbar buttons as row actions', () {
    final actions = [
      MetaAction(id: 1, action: 'form', label: 'Approve', formMetaId: 9, needsRow: true, showInToolbar: true, orderNumber: 5),
      MetaAction(id: 2, action: 'form', label: 'Import', formMetaId: 9, showInToolbar: true, orderNumber: 1),
      MetaAction(id: 3, action: 'form', label: 'Note', formMetaId: 9, showInRow: true, orderNumber: 2),
      MetaAction(id: 4, action: 'form', label: 'Hidden', formMetaId: 9, needsRow: true, orderNumber: 3),
    ];
    final can = allow({9: {'view'}});
    expect(rowActions(actions, can: can, gridMetaId: 1).map((a) => a.label), ['Note', 'Approve']);
    expect(toolbarActions(actions, can: can, gridMetaId: 1).map((a) => a.label), ['Import']);
    expect(rowActions(actions, can: allow({}), gridMetaId: 1), isEmpty);
  });

  test('actionRecordId uses the id param, else the primary key', () {
    expect(actionRecordId(workOrderActions[2], {'id': 7}, 'id'), '7');
    expect(actionRecordId(MetaAction(id: 1, action: 'delete'), {'code': 'X'}, 'code'), 'X');
  });
}
