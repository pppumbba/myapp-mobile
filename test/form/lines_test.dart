import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/form/criteria.dart';
import 'package:wand_mobile/form/lines.dart';
import 'package:wand_mobile/form/values.dart';
import 'package:wand_mobile/meta/defs.dart';

import 'values_test.dart' show fp;

MetaParam detail(String path, int ref, Map<String, dynamic> json) =>
    MetaParam(id: path.hashCode, paramName: path, fieldPath: path, dataType: 'detail', refMetaId: ref, jsonConfig: json);

Values start(List<MetaParam> params, Map<String, dynamic>? record) => initialValues(params, record: record);

// An order: lines (quantity × price into total), each line with deliveries (quantity into delivered),
// and one-to-one terms.
final deliveries = DetailNode(
  detail('deliveries', 30, {'foreign_key': 'line_id', 'amount': ['quantity'], 'total_field': 'delivered'}),
  MetaDef(Meta(id: 30, name: 'Delivery'), [fp('id', type: 'integer', primary: true), fp('line_id', type: 'integer'), fp('quantity', type: 'decimal', required: true)]),
  const [],
);
final lines = DetailNode(
  detail('lines', 20, {'foreign_key': 'order_id', 'amount': ['quantity', 'price'], 'total_field': 'total'}),
  MetaDef(Meta(id: 20, name: 'Line'), [
    fp('id', type: 'integer', primary: true),
    fp('order_id', type: 'integer'),
    fp('item', required: true),
    fp('quantity', type: 'decimal'),
    fp('price', type: 'decimal'),
    fp('delivered', type: 'decimal'),
  ]),
  [deliveries],
);
final terms = DetailNode(
  detail('terms', 40, {'one': true, 'foreign_key': 'order_id'}),
  MetaDef(Meta(id: 40, name: 'Terms'), [fp('id', type: 'integer', primary: true), fp('order_id', type: 'integer'), fp('days', type: 'integer')]),
  const [],
);

void main() {
  test('saved lines start with their ids and sub-lines; a missing one-to-one starts blank', () {
    final got = startLines(lines, [
      {'id': 5, 'order_id': 1, 'item': 'Bolt', 'quantity': '2', 'price': '1.5', 'deliveries': [{'id': 9, 'quantity': 2}]},
    ], start);
    expect(got.single.id, '5');
    expect(got.single.values['item'], 'Bolt');
    expect(got.single.sub['deliveries']!.single.id, '9');
    final one = startLines(terms, null, start);
    expect(one, hasLength(1));
    expect(one.single.id, isNull);
  });

  test('a line is left out of the fields by its foreign key; amounts multiply and add up', () {
    expect(lines.fields.map(pathOf), ['item', 'quantity', 'price', 'delivered']);
    final ls = startLines(lines, [{'id': 1, 'quantity': '2', 'price': '1.25'}, {'quantity': '3', 'price': ''}, {'quantity': 'x', 'price': '2'}], start);
    expect(lineAmount(lines, ls[0]), 2.5);
    expect(lineAmount(lines, ls[1]), 0);
    expect(lineAmount(lines, ls[2]), 0);
    expect(linesTotal(lines, ls), 2.5);
    expect(totalText(2.5), '2.5');
    expect(totalText(3), '3');
  });

  test('linesPayload keeps ids, sends sub-lines, and fills their total_field', () {
    final ls = startLines(lines, [
      {'id': 5, 'item': 'Bolt', 'quantity': '2', 'price': '1.5', 'deliveries': [{'id': 9, 'quantity': 1.5}, {'quantity': '0.25'}]},
    ], start);
    final added = blankLine(lines, start);
    final out = linesPayload(lines, [...ls, added.copyWith(values: {...added.values, 'item': 'Nut'})]);
    expect(out[0]['id'], 5);
    expect(out[0]['quantity'], 2);
    expect(out[0]['delivered'], 1.75);
    expect((out[0]['deliveries'] as List).first, containsPair('id', 9));
    expect(out[1].containsKey('id'), isFalse);
    expect(out[1]['item'], 'Nut');
    expect(out[1]['deliveries'], isEmpty);
    expect(out[1]['delivered'], 0);
  });

  test('a one-to-one is sent as one object', () {
    final one = startLines(terms, {'id': 3, 'days': 30}, start);
    expect(detailPayload(terms, one), {'id': 3, 'order_id': null, 'days': 30});
  });

  test('missingInLine skips fields worked out from sub-lines', () {
    final blank = blankLine(lines, start);
    expect(missingInLine(lines, blank), ['item']);
    expect(missingInLine(deliveries, blankLine(deliveries, start)), ['quantity']);
  });

  group('criteria', () {
    test('compares, combines and reads names as the server does', () {
      final vars = {'supplier_type_id': '3', 'roleId': [1, 4], 'amount': 120, 'kind': 'local', 'note': null};
      expect(criteriaPasses(null, vars), isTrue);
      expect(criteriaPasses('  ', vars), isTrue);
      expect(criteriaPasses('supplierTypeId == 3', vars), isTrue);
      expect(criteriaPasses('roleId == 4 && amount > 100', vars), isTrue);
      expect(criteriaPasses('roleId = 2 or kind <> "local"', vars), isFalse);
      expect(criteriaPasses("not (kind == 'import')", vars), isTrue);
      expect(criteriaPasses('note == null && note == ""', vars), isTrue);
      expect(criteriaPasses('note == 0', vars), isFalse);
      expect(criteriaPasses('amount * 2 - 40 >= 200', vars), isTrue);
      expect(criteriaPasses('KIND == "local"', vars), isTrue);
    });

    test('mistakes throw', () {
      expect(() => criteriaPasses('missing == 1', {}), throwsA(isA<CriteriaError>()));
      expect(() => criteriaPasses('(1 == 1', {}), throwsA(isA<CriteriaError>()));
      expect(() => criteriaPasses('1 / 0', {}), throwsA(isA<CriteriaError>()));
      expect(() => criteriaPasses('roleId > 1', {'roleId': [1]}), throwsA(isA<CriteriaError>()));
      expect(() => criteriaPasses("a == 'x", {'a': 'x'}), throwsA(isA<CriteriaError>()));
    });
  });
}
