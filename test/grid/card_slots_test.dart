import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/grid/card_slots.dart';

int _n = 0;
MetaParam p(String name, String label,
        {bool show = true, bool isLabel = false, String? dataType, String? renderType, String? pos, bool select = false, int? ref}) =>
    MetaParam(
      id: ++_n,
      orderNumber: _n,
      paramName: name,
      labelName: label,
      isShow: show,
      isLabel: isLabel,
      dataType: dataType,
      renderType: renderType,
      widgetPosition: pos,
      isSelect: select,
      refMetaId: ref,
    );

List<MetaParam> assetRegister() => [
      p('id', 'id', show: false, dataType: 'integer'),
      p('asset_tag', 'Tag'),
      p('name', 'Asset', isLabel: true),
      p('category_id', 'Category', select: true, ref: 124),
      p('location_id', 'Location', select: true, ref: 122),
      p('department', 'Department'),
      p('assigned_to', 'Assigned to'),
      p('criticality', 'Criticality'),
      p('purchase_cost', 'Cost', dataType: 'decimal', renderType: 'money'),
      p('carrying_amount', 'Book value', dataType: 'decimal', renderType: 'money'),
      p('warranty_until', 'Warranty', dataType: 'date'),
      p('status', 'Status', dataType: 'string', renderType: 'status'),
      p('w', 'Widget', dataType: 'widget'),
    ];

void main() {
  test('cardSlots picks is_label title, status badge, 3 body fields', () {
    final s = cardSlots(assetRegister());
    expect(s.title?.paramName, 'name');
    expect(s.subtitle?.paramName, 'asset_tag');
    expect(s.badge?.paramName, 'status');
    expect([for (final b in s.body) b.label], ['Category', 'Location', 'Department']);
    expect(s.footer, isEmpty);
    expect(s.image, isNull);
  });

  test('cardSlots honours widget_position', () {
    final ps = assetRegister();
    ps[7] = p('criticality', 'Criticality', pos: 'title');
    ps[8] = p('purchase_cost', 'Cost', dataType: 'decimal', renderType: 'money', pos: 'footer');
    ps[9] = p('carrying_amount', 'Book value', pos: 'subtitle');
    ps[10] = p('warranty_until', 'Warranty', pos: 'badge');
    final s = cardSlots(ps);
    expect(s.title?.paramName, 'criticality');
    expect(s.subtitle?.paramName, 'carrying_amount');
    expect(s.badge?.paramName, 'warranty_until');
    expect(s.footer.map((e) => e.paramName), ['purchase_cost']);
    expect(s.body.map((e) => e.paramName), ['asset_tag', 'name', 'category_id']);
  });

  test('cardSlots with no params gives empty slots', () {
    final s = cardSlots([]);
    expect(s.title, isNull);
    expect(s.body, isEmpty);
  });

  test('statusColor is stable per option index', () {
    final opts = ['in service', 'in repair', 'idle'];
    expect(statusColor('in repair', opts), statusColor('in repair', opts));
    expect(statusColor('in repair', opts), isNot(statusColor('idle', opts)));
    expect(statusColor('zzz', ['a']), statusColor('zzz', ['a']));
  });

  test('two params placed as title: first is title, second in body', () {
    final s = cardSlots([p('a', 'A', pos: 'title'), p('b', 'B', pos: 'title'), p('c', 'C'), p('d', 'D')]);
    expect(s.title?.paramName, 'a');
    expect(s.body.map((e) => e.paramName), contains('b'));
    expect(s.subtitle?.paramName, 'c');
  });

  test('placed body params beyond 3 are all kept', () {
    final s = cardSlots([for (final n in ['a', 'b', 'c', 'd', 'e']) p(n, n, pos: 'body')]);
    expect(s.body.map((e) => e.paramName), ['a', 'b', 'c', 'd', 'e']);
  });

  test('a second image claimant goes to body', () {
    final s = cardSlots([p('a', 'A', pos: 'image'), p('b', 'B', pos: 'image')]);
    expect(s.image?.paramName, 'a');
    expect(s.body.map((e) => e.paramName), ['b']);
  });

  test('statusColor follows the web word map first', () {
    final opts = ['completed', 'x'];
    expect(statusColor('completed', opts), Colors.green.shade700);
    expect(statusColor('Completed', opts), Colors.green.shade700);
    expect(statusColor('pending', opts), Colors.amber.shade800);
    expect(statusColor('rejected', opts), Colors.red.shade700);
    final scheme = ColorScheme.fromSeed(seedColor: Colors.teal);
    expect(statusColor('in progress', opts, scheme: scheme), scheme.primary);
  });
}
