import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/grid/grid_query.dart';

void main() {
  test('toQuery puts filters and scope under their keys and drops empty', () {
    final q = GridQuery(filter: {'status': 'open', 'type': ''}, scope: {'asset_id': '5'});
    expect(q.toQuery(), {
      'page': 1,
      'per_page': 20,
      'filter': {'status': 'open'},
      'scope': {'asset_id': '5'},
    });
    final s = GridQuery(search: 'pump', page: 2, sort: 'title', dir: 'desc');
    expect(s.toQuery(), {'search': 'pump', 'page': 2, 'per_page': 20, 'sort': 'title', 'dir': 'desc'});
  });

  test('actionParams maps id and =text', () {
    final a = MetaAction(id: 1, params: {'id': 'id', 'kind': '=repair', 'asset_id': 'asset_id', 'none': 'missing'});
    expect(actionParams(a, {'id': 7, 'asset_id': null}), {'id': '7', 'kind': 'repair'});
  });

  test('drilldownOf reads meta_id and params, else null', () {
    final d = drilldownOf({'drilldown': {'meta_id': 146, 'params': {'id': 'id'}}})!;
    expect(d.metaId, 146);
    expect(drillParams(d.params, {'id': 3}), {'id': '3'});
    expect(drilldownOf({'drilldown': {'meta_id': 0}}), isNull);
    expect(drilldownOf({}), isNull);
  });

  test('asFilter applies filter_as and options, and marks mandatory filters required', () {
    final p = MetaParam.fromJson({
      'id': 1, 'param_name': 'asset', 'field_path': 'asset', 'data_type': 'string', 'is_criteria': 1, 'is_mandatory_criteria': 1,
      'json_config': {'options': ['a']},
      'filter_as': {'is_select': 1, 'ref_meta_id': 127, 'display_field': 'name', 'options': ['x', 'y']},
    });
    final f = asFilter(p);
    expect(f.isSelect, true);
    expect(f.refMetaId, 127);
    expect(f.displayField, 'name');
    expect(f.jsonConfig['options'], ['x', 'y']);
    expect(f.isRequired, true);
    expect(filterKind(f), FilterKind.list);
    expect(filterKind(MetaParam(id: 2, paramName: 'd', dataType: 'date')), FilterKind.date);
    expect(filterKind(MetaParam(id: 3, paramName: 'n', dataType: 'decimal')), FilterKind.number);
    expect(filterKind(MetaParam(id: 4, paramName: 't')), FilterKind.text);
  });
}
