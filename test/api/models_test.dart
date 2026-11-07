import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';

void main() {
  test('params tree parses children and label falls back to param_name', () {
    final p = MetaParam.fromJson({
      'id': 1,
      'parent_id': null,
      'param_name': 'lines',
      'label_name': null,
      'is_show': 1,
      'is_required': true,
      'is_criteria': 0,
      'filter_as': {'meta': 5},
      'json_config': null,
      'children': [
        {'id': 2, 'parent_id': 1, 'param_name': 'qty', 'label_name': 'Quantity', 'is_show': false, 'children': []},
      ],
    });
    expect(p.label, 'lines');
    expect(p.isShow, true);
    expect(p.isRequired, true);
    expect(p.isCriteria, false);
    expect(p.filterAs, {'meta': 5});
    expect(p.jsonConfig, isEmpty);
    expect(p.children.single.label, 'Quantity');
    expect(p.children.single.isShow, false);
  });

  test('Meta, action and page parse', () {
    final m = Meta.fromJson({'id': 3, 'type': null, 'json_config': null, 'load_expression_string': 'x'});
    expect(m.type, isNull);
    expect(m.scripts['load_expression_string'], 'x');
    expect(m.scripts['event_expression_string'], isNull);
    final a = MetaAction.fromJson({
      'id': 1,
      'needs_row': 1,
      'show_in_toolbar': 0,
      'show_in_row': true,
      'json_config': {
        'params': {'asset': 'id'}
      },
    });
    expect(a.needsRow, true);
    expect(a.showInToolbar, false);
    expect(a.params, {'asset': 'id'});
    final d = DataPage.fromJson({
      'data': [
        {'id': 1}
      ],
      'current_page': 1,
      'last_page': 3,
      'total': 25,
      'footer': [],
      'missing_filters': ['status'],
    });
    expect(d.rows.single['id'], 1);
    expect(d.lastPage, 3);
    expect(d.footer, isEmpty);
    expect(d.missingFilters, ['status']);
  });

  test('Access.can: admin true, null id true, missing meta false', () {
    final u = Access.fromJson({
      'is_admin': false,
      'metas': {
        '5': {'view': true, 'create': 0, 'edit': false, 'delete': false}
      }
    });
    expect(u.can(5, 'view'), true);
    expect(u.can(5, 'create'), false);
    expect(u.can(9, 'view'), false);
    expect(u.can(null, 'delete'), true);
    expect(Access.fromJson({'is_admin': true, 'metas': []}).can(9, 'edit'), true);
    expect(Access.fromJson({'is_admin': false, 'metas': []}).can(9, 'edit'), false);
  });
}
