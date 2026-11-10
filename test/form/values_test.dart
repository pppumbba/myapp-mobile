import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/form/values.dart';

MetaParam fp(String path, {String type = 'string', String? render, String? def, bool required = false, bool show = true, bool primary = false, Map<String, dynamic> json = const {}, int order = 0}) =>
    MetaParam(
      id: path.hashCode, paramName: path, fieldPath: path, dataType: type, renderType: render,
      defaultValue: def, isRequired: required, isShow: show, isPrimary: primary, jsonConfig: json, orderNumber: order,
    );

void main() {
  test('initialValues fills {today} and session tokens', () {
    final params = [
      fp('reported_on', type: 'date', def: '{today}'),
      fp('employee', def: '{sessionemployeeid}'),
      fp('dept', def: '{sessiondept}'),
      fp('unknown', def: 'x{nope}'),
      fp('who', def: '{user_name}'),
      fp('flag', type: 'boolean', def: '1'),
      fp('when', type: 'datetime'),
    ];
    final v = initialValues(
      params,
      session: (p) => switch (p) { 'sessionemployeeid' => '42', 'sessiondept' => '', _ => null },
      user: {'id': 3, 'name': 'Bat'},
      now: DateTime(2026, 11, 7, 9, 30),
    );
    expect(v['reported_on'], '2026-11-07');
    expect(v['employee'], '42');
    expect(v['dept'], '');
    expect(v['unknown'], 'x{nope}');
    expect(v['who'], 'Bat');
    expect(v['flag'], true);
    expect(v['when'], '');
  });

  test('fixed beats record beats default_value', () {
    final params = [
      fp('a', def: 'da'),
      fp('b', def: 'db'),
      fp('c', def: 'dc'),
      fp('d', type: 'datetime'),
      fp('e', type: 'date'),
    ];
    final rec = initialValues(params,
        record: {'a': 'ra', 'b': 'rb', 'd': '2026-11-07 10:15:00', 'e': '2026-11-07T00:00:00Z'},
        fixed: {'a': 'fa'},
        defaults: {'b': 'xb', 'c': 'xc'});
    expect(rec['a'], 'fa');
    expect(rec['b'], 'rb');
    expect(rec['c'], ''); // a record: its own (missing) value, not the default
    expect(rec['d'], '2026-11-07T10:15');
    expect(rec['e'], '2026-11-07');
    final fresh = initialValues(params, fixed: {'a': 'fa'}, defaults: {'b': 'xb'});
    expect(fresh, containsPair('a', 'fa'));
    expect(fresh, containsPair('b', 'xb'));
    expect(fresh, containsPair('c', 'dc'));
  });

  test('initialValues skips detail, file and widget params', () {
    final v = initialValues([
      fp('title'),
      fp('parts', type: 'detail'),
      fp('photo', type: 'singlefile'),
      fp('docs', type: 'multifile'),
      fp('w', type: 'widget'),
    ]);
    expect(v.keys, ['title']);
  });

  test('toPayload strips commas, empties to null, adds _context', () {
    final params = [
      fp('qty', type: 'integer'),
      fp('cost', type: 'decimal', render: 'money'),
      fp('note'),
      fp('done', type: 'boolean'),
      fp('at', type: 'datetime'),
      fp('on', type: 'date'),
      fp('parts', type: 'detail'),
      fp('hidden', show: false),
    ];
    final out = toPayload(params, {
      'qty': '1,200',
      'cost': '12,345.50',
      'note': '',
      'done': false,
      'at': '2026-11-07T10:15',
      'on': '2026-11-07',
      'hidden': 'h',
    }, appMetaId: 5, fixed: {'asset_id': '9'});
    expect(out, {
      'qty': 1200,
      'cost': 12345.5,
      'note': null,
      'done': false,
      'at': '2026-11-07 10:15:00',
      'on': '2026-11-07',
      'asset_id': '9',
      '_context': {'app_meta_id': 5},
    });
    expect(toPayload(params, {}, appMetaId: null).containsKey('_context'), isFalse);
  });

  test('missingRequired skips hidden fields', () {
    final params = [
      fp('title', required: true),
      fp('asset', required: true),
      fp('flag', type: 'boolean', required: true),
      fp('no', required: true, json: {'autonumber': {'format': 'WO-{seq:4}'}}),
      fp('opt'),
      fp('filled', required: true),
      fp('gone', required: true, show: false),
    ];
    expect(missingRequired(params, {'title': '', 'asset': '', 'flag': false, 'no': '', 'filled': 'x'}, {'asset'}), ['title']);
  });

  test('formGroups merges ungrouped into a General group', () {
    final params = [
      fp('b', order: 2, json: {'group': 'Details'}),
      fp('a', order: 1),
      fp('c', order: 3, json: {'group': ' general '}),
      fp('d', order: 4, json: {'group': 'Details'}),
    ];
    final g = formGroups(params);
    expect(g.map((x) => x.name), ['general', 'Details']);
    expect(g[0].fields.map((p) => p.fieldPath), ['a', 'c']);
    expect(g[1].fields.map((p) => p.fieldPath), ['b', 'd']);
    final plain = formGroups([fp('x', order: 2, json: {'group': 'Two'}), fp('y', order: 1)]);
    expect(plain.map((x) => x.name), ['', 'Two']);
  });

  test('autonumberFields lists rule fields and tokens', () {
    final cfg = autonumberOf(fp('no', json: {
      'autonumber': {
        'format': 'WO-{yy}{MM}-{type}-{seq:4}',
        'rules': [{'field': 'site', 'value': 'a', 'format': '{site}-{seq:3}'}],
      },
    }))!;
    expect(autonumberFields(cfg), ['site', 'type']);
    expect(autonumberOf(fp('x')), isNull);
  });

  group('file fields', () {
    final params = [
      fp('title'),
      fp('attachments', type: 'multifile', required: true),
      fp('photo', type: 'singlefile'),
    ];
    const pdf = {'id': 9, 'file_name': 'quote.pdf', 'file_extension': 'pdf', 'file_size': 1200, 'description': 'Signed'};

    test('only a form takes them; detail lines leave them out', () {
      expect(formFields(params).map(pathOf), ['title']);
      expect(formFields(params, files: true).map(pathOf), containsAll(['title', 'attachments', 'photo']));
    });

    test("a record's files become the value; a single file too", () {
      final v = initialValues(params, files: true, record: {
        'title': 'PO',
        'attachments': [pdf],
        'photo': {'id': 4, 'file_name': 'a.jpg'},
      });
      expect(filesOf(v['attachments']).single['file_name'], 'quote.pdf');
      expect(filesOf(v['photo']).single['id'], 4);
      expect(initialValues(params, files: true)['attachments'], '');
    });

    test('saving sends ids with descriptions: a list, or one file or null', () {
      final v = initialValues(params, files: true, record: {'attachments': [pdf], 'photo': null});
      final body = toPayload(params, v, appMetaId: null, files: true);
      expect(body['attachments'], [{'id': 9, 'description': 'Signed'}]);
      expect(body['photo'], isNull);
      expect(toPayload(params, v, appMetaId: null).containsKey('attachments'), isFalse, reason: 'lines never send them');
    });

    test('a required file field with no files is missing', () {
      expect(missingRequired(params, {'title': '', 'attachments': '', 'photo': ''}, const {}, files: true), ['attachments']);
      expect(missingRequired(params, {'title': '', 'attachments': '[]', 'photo': ''}, const {}, files: true), ['attachments']);
      expect(missingRequired(params, {'title': '', 'attachments': '[{"id":1}]', 'photo': ''}, const {}, files: true), isEmpty);
    });
  });
}
