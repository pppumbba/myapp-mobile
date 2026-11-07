import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/grid/cells.dart';

MetaParam p(String name,
        {String? dataType, String? renderType, bool isSelect = false, int? ref, String? displayField, String? displayAs, String? valueField}) =>
    MetaParam(
      id: 1,
      paramName: name,
      dataType: dataType,
      renderType: renderType,
      isSelect: isSelect,
      refMetaId: ref,
      displayField: displayField,
      displayAs: displayAs,
      valueField: valueField,
    );

void main() {
  test('cellText money groups thousands and 2 decimals', () {
    expect(cellText(p('c', dataType: 'decimal', renderType: 'money'), {'c': 1234567.5}), '1,234,567.50');
  });

  test('cellText decimal groups with at most 2 decimals like the web', () {
    expect(cellText(p('c', dataType: 'decimal'), {'c': '1234567.5'}), '1,234,567.5');
    expect(cellText(p('c', dataType: 'decimal'), {'c': 1.2345}), '1.23');
  });

  test('cellText integer groups with no decimals', () {
    expect(cellText(p('c', dataType: 'integer'), {'c': 1234567}), '1,234,567');
  });

  test('cellText for lookup uses the resolver and falls back to #value', () {
    final lp = p('category_id', isSelect: true, ref: 124, dataType: 'integer');
    expect(cellText(lp, {'category_id': 5}, lookupText: (_, v) => v == 5 ? 'Pumps' : null), 'Pumps');
    expect(cellText(lp, {'category_id': 6}, lookupText: (_, v) => null), '#6');
    expect(cellText(lp, {'category_id': 6}), '#6');
    expect(cellText(lp, {'category_id': null}), '');
  });

  test('cellText formats dates, booleans, active, status, files and empties', () {
    expect(cellText(p('d', dataType: 'date'), {'d': '2026-11-03T00:00:00.000000Z'}), '2026-11-03');
    expect(cellText(p('d', dataType: 'datetime'), {'d': '2026-11-03 09:30:00'}), '2026-11-03 09:30');
    expect(cellText(p('b', dataType: 'boolean'), {'b': 1}), 'Yes');
    expect(cellText(p('b', dataType: 'boolean'), {'b': false}), 'No');
    expect(cellText(p('a', renderType: 'active'), {'a': '1'}), 'Active');
    expect(cellText(p('a', renderType: 'active'), {'a': 0}), 'Inactive');
    expect(cellText(p('s', renderType: 'status'), {'s': 'in repair'}), 'In repair');
    expect(cellText(p('f', dataType: 'multifile'), {'f': '[{"id":1},{"id":2}]'}), '\u{1F4CE} 2');
    expect(cellText(p('f', dataType: 'singlefile'), {'f': [{'id': 1}]}), '\u{1F4CE} 1');
    expect(cellText(p('x'), {'x': null}), '');
    expect(cellText(p('x'), {'x': ''}), '');
    expect(cellText(p('x'), {}), '');
    expect(cellText(p('x'), {'x': 'hello'}), 'hello');
  });

  test('lookupFields and rowLabel port the web helpers', () {
    expect(lookupFields(p('c', displayField: 'name')), (label: 'name', value: 'id'));
    expect(lookupFields(p('c', displayField: 'name', displayAs: 'title', valueField: 'code')), (label: 'title', value: 'code'));
    expect(lookupFields(p('c')).label, isNull);
    expect(rowLabel({'id': 1, 'name': 'A'}, 'name'), 'A');
    expect(rowLabel({'id': 1, 'qty': 3, 'code': 'X'}, null), 'X');
    expect(rowLabel({'id': 1, 'name': null}, 'name'), '#1');
    expect(rowLabel({'id': 1, 'qty': 3}, 'missing'), '#1');
  });
}
