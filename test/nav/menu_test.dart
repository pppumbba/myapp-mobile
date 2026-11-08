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
  test('Assets app: one bottom slot per top-level item with screens; their screens are the tabs', () {
    final m = flattenMenu(assetsTree(), canView: (_) => true, supported: _supported);
    // Overview (dashboard) and Setup (tabs) open nothing the app shows, so they drop out.
    expect(m.tabs.map((e) => e.label), ['Assets', 'Maintenance', 'Finance']);
    expect(m.more, isEmpty);
    expect(m.tabs[0].screens.map((e) => e.label), ['Asset register', 'Transfers']);
    expect(m.tabs[1].screens.map((e) => e.label), ['Work orders', 'PM plans', 'PM due now', 'Meter readings']);
    expect(m.tabs[2].screens.map((e) => e.label), ['Asset transactions', 'Depreciation preview']);
    expect(m.tabs[1].screens.first.group, 'Maintenance');
    expect(m.all, hasLength(8));
  });

  test('hidden and non-viewable items are missing; a top-level screen is its own section', () {
    final tree = [
      item('A', ref: 1, order: 1),
      item('B', ref: 2, order: 2, show: false),
      item('C', ref: 3, order: 3),
      item('G', order: 4, children: [item('D', ref: 4, order: 1)]),
    ];
    final m = flattenMenu(tree, canView: (id) => id != 3, supported: (_) => true);
    expect(m.tabs.map((e) => e.label), ['A', 'G']);
    expect(m.tabs[0].children, isEmpty, reason: 'a lone screen gets no tab strip');
    expect(m.tabs[1].screens.map((e) => e.label), ['D']);
    expect(m.more, isEmpty);
  });

  test('deeper levels join their top-level section; a top-level screen with children comes first', () {
    final tree = [
      item('Sales', ref: 1, order: 1, children: [
        item('Orders', ref: 2, order: 1),
        item('Reports', order: 2, children: [item('By month', ref: 3)]),
      ]),
    ];
    final m = flattenMenu(tree, canView: (_) => true, supported: (_) => true);
    expect(m.tabs.single.screens.map((e) => e.label), ['Sales', 'Orders', 'By month']);
  });

  test('more than five sections: four in the bar, the rest under More', () {
    final tree = [for (var i = 1; i <= 7; i++) item('S$i', ref: i, order: i)];
    final m = flattenMenu(tree, canView: (_) => true, supported: (_) => true);
    expect(m.tabs.map((e) => e.label), ['S1', 'S2', 'S3', 'S4']);
    expect(m.more.map((e) => e.label), ['S5', 'S6', 'S7']);
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

  test('five sections are all in the bar', () {
    final tree = [for (var i = 1; i <= 5; i++) item('S$i', ref: i, order: i)];
    final m = flattenMenu(tree, canView: (_) => true, supported: (_) => true);
    expect(m.tabs, hasLength(5));
    expect(m.more, isEmpty);
  });
}
