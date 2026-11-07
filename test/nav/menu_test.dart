import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/nav/menu.dart';

int _id = 1000;
MetaParam item(String name, {int? ref, List<MetaParam> children = const [], int order = 0, bool show = true}) =>
    MetaParam(
      id: _id++,
      paramName: name,
      labelName: name,
      refMetaId: ref,
      orderNumber: order,
      isShow: show,
      children: children,
    );

List<MetaParam> assetsTree() => [
      item('Overview', ref: 159, order: 1),
      item('Assets', order: 2, children: [
        item('Asset register', ref: 147, order: 1),
        item('Asset workspace', ref: 146, order: 2),
        item('Transfers', ref: 143, order: 3),
      ]),
      item('Maintenance', order: 3, children: [
        item('Work orders', ref: 131, order: 1),
        item('Maintenance calendar', ref: 133, order: 2),
        item('PM plans', ref: 135, order: 3),
        item('PM due now', ref: 137, order: 4),
        item('Meter readings', ref: 140, order: 5),
      ]),
      item('Finance', order: 4, children: [
        item('Asset transactions', ref: 174, order: 1),
        item('Depreciation preview', ref: 171, order: 2),
        item('Run depreciation', ref: 170, order: 3),
        item('Book values', ref: 148, order: 4),
        item('Journal', ref: 176, order: 5),
        item('Accounts & rules', ref: 168, order: 6),
      ]),
      item('Setup', ref: 125, order: 5),
    ];

const types = {
  159: 'dashboard', 147: 'datagrid', 146: 'workspace', 143: 'datagrid', 131: 'datagrid', 133: 'calendar',
  135: 'datagrid', 137: 'datagrid', 140: 'datagrid', 174: 'datagrid', 171: 'datagrid', 170: 'stage_query',
  148: 'statement', 176: 'statement', 168: 'tabs', 125: 'tabs',
};

bool _supported(int id) => const {'datagrid', 'form'}.contains(types[id]);

void main() {
  test('Assets app: three tabs plus More, More starts with PM plans', () {
    final m = flattenMenu(assetsTree(), canView: (_) => true, supported: _supported);
    expect(m.tabs.map((e) => e.item.label), ['Asset register', 'Transfers', 'Work orders']);
    expect(m.more.first.item.label, 'PM plans');
    expect(m.more.first.group, 'Maintenance');
    expect(m.tabs.first.group, 'Assets');
    expect(m.more.map((e) => e.item.label), [
      'PM plans', 'PM due now', 'Meter readings', 'Asset transactions', 'Depreciation preview',
    ]);
  });

  test('hidden and non-viewable items are missing', () {
    final tree = [
      item('A', ref: 1, order: 1),
      item('B', ref: 2, order: 2, show: false),
      item('C', ref: 3, order: 3),
      item('G', order: 4, children: [item('D', ref: 4, order: 1)]),
    ];
    final m = flattenMenu(tree, canView: (id) => id != 3, supported: (_) => true);
    expect(m.tabs.map((e) => e.item.label), ['A', 'D']);
    expect(m.more, isEmpty);
  });

  test('a hidden group hides its children', () {
    final tree = [item('G', order: 1, show: false, children: [item('D', ref: 4)])];
    final m = flattenMenu(tree, canView: (_) => true, supported: (_) => true);
    expect(m.tabs, isEmpty);
  });

  test('items are walked in order_number order', () {
    final tree = [item('Second', ref: 2, order: 2), item('First', ref: 1, order: 1)];
    final m = flattenMenu(tree, canView: (_) => true, supported: (_) => true);
    expect(m.tabs.map((e) => e.item.label), ['First', 'Second']);
  });

  test('three screens give three tabs and no More', () {
    final tree = [item('A', ref: 1, order: 1), item('B', ref: 2, order: 2), item('C', ref: 3, order: 3)];
    final m = flattenMenu(tree, canView: (_) => true, supported: (_) => true);
    expect(m.tabs, hasLength(3));
    expect(m.more, isEmpty);
  });

  test('four screens are all tabs', () {
    final tree = [for (var i = 1; i <= 4; i++) item('S$i', ref: i, order: i)];
    final m = flattenMenu(tree, canView: (_) => true, supported: (_) => true);
    expect(m.tabs, hasLength(4));
    expect(m.more, isEmpty);
  });
}
