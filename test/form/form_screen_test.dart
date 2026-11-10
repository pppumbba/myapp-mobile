import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/config.dart';
import 'package:wand_mobile/form/fields.dart';
import 'package:wand_mobile/form/form_screen.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';

/// A form row's text box, found by the row's label.
Finder fieldBox(String label) => find.descendant(of: find.widgetWithText(FieldInput, label), matching: find.byType(TextField));

typedef Handler = (int, Object?) Function(RequestOptions o);

class Adapter implements HttpClientAdapter {
  final Map<String, Handler> routes;
  final List<RequestOptions> seen = [];
  Adapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o);
    final (status, body) = routes['${o.method} ${o.uri.path}']?.call(o) ?? (404, {'message': 'nope'});
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> p(int id, String path, String label, String type,
        {String? render, bool required = false, bool show = true, bool primary = false, bool select = false, int? ref, String? def, Map<String, dynamic>? json, int? order}) =>
    {
      'id': id, 'param_name': path, 'field_path': path, 'label_name': label, 'data_type': type, 'render_type': render,
      'is_required': required, 'is_show': show, 'is_primary': primary, 'is_select': select, 'ref_meta_id': ref,
      'default_value': def, 'json_config': json, 'order_number': order ?? id,
    };

/// The work order form (meta 129).
final workOrderParams = [
  p(1, 'id', 'Id', 'integer', primary: true, show: false),
  p(2, 'wo_no', 'Work order', 'string', required: true, json: {'autonumber': {'format': 'WO-{yy}{MM}{seq:4}'}}),
  p(3, 'asset_id', 'Asset', 'integer', select: true, ref: 127, required: true),
  p(4, 'pm_plan_id', 'PM plan', 'integer', show: false),
  p(5, 'title', 'Title', 'string', required: true),
  p(6, 'type', 'Type', 'string', render: 'select', required: true, def: 'corrective', json: {'options': ['corrective', 'preventive', 'inspection', 'calibration']}),
  p(7, 'priority', 'Priority', 'string', render: 'select', required: true, def: 'medium', json: {'options': ['low', 'medium', 'high', 'critical']}),
  p(8, 'status', 'Status', 'string', render: 'status', required: true, def: 'open', json: {'options': ['open', 'assigned', 'in progress', 'on hold', 'completed', 'cancelled']}),
  p(9, 'reported_by', 'Reported by', 'string'),
  p(10, 'reported_on', 'Reported on', 'date', def: '{today}'),
  p(11, 'technician', 'Technician', 'string'),
  p(12, 'scheduled_start', 'Scheduled start', 'datetime'),
  p(13, 'scheduled_end', 'Scheduled end', 'datetime'),
  p(14, 'completed_on', 'Completed on', 'date'),
  p(15, 'labor_hours', 'Labor hours', 'decimal'),
  p(16, 'labor_cost', 'Labor cost', 'decimal', render: 'money'),
  p(17, 'description', 'Description', 'text', render: 'textarea'),
  p(18, 'resolution', 'Resolution', 'text', render: 'textarea'),
  p(19, 'parts', 'Parts', 'detail', ref: 130, json: {'total_field': 'parts_cost'}),
  p(20, 'parts_cost', 'Parts cost', 'decimal', render: 'money'),
];

String today() {
  final n = DateTime.now();
  String two(int x) => x.toString().padLeft(2, '0');
  return '${n.year}-${two(n.month)}-${two(n.day)}';
}

(ProviderContainer, Adapter) setup(Map<String, Handler> routes) {
  final adapter = Adapter(routes);
  final config = AppConfig(appMetaId: 5, apiBase: 'https://h/api');
  final client = ApiClient(config, dio: Dio()..httpClientAdapter = adapter);
  final c = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(config),
    apiClientProvider.overrideWithValue(client),
  ]);
  addTearDown(c.dispose);
  return (c, adapter);
}

Map<String, Handler> workOrderRoutes({Map<String, dynamic>? posted}) => {
      'GET /api/metas/129': (_) => (200, {'id': 129, 'type': 'form', 'name': 'Work order', 'json_config': {}}),
      'GET /api/metas/129/params': (_) => (200, workOrderParams),
      'GET /api/metas/129/autonumber': (_) => (200, {'wo_no': 'WO-2611-0001'}),
      'POST /api/metas/129/data': (o) {
        posted?.addAll(Map<String, dynamic>.from(o.data as Map));
        return (201, {'id': 77, 'wo_no': 'WO-2611-0001'});
      },
      // The parts line form.
      'GET /api/metas/130': (_) => (200, {'id': 130, 'type': 'form', 'name': 'Part used'}),
      'GET /api/metas/130/params': (_) => (200, [
            p(1, 'id', 'Id', 'integer', primary: true, show: false),
            p(2, 'work_order_id', 'Work order', 'integer'),
            p(3, 'part', 'Part', 'string', required: true),
            p(4, 'quantity', 'Quantity', 'decimal', def: '1'),
            p(5, 'unit_cost', 'Unit cost', 'decimal'),
          ]),
      'GET /api/metas/127': (_) => (200, {'id': 127, 'type': 'datagrid', 'name': 'Assets'}),
      'GET /api/metas/127/params': (_) => (200, [
            {'id': 1, 'param_name': 'name', 'field_path': 'name', 'label_name': 'Name', 'is_label': true, 'order_number': 1},
          ]),
      'GET /api/metas/127/data': (_) => (200, {
            'data': [{'id': 5, 'name': 'Pump 1'}, {'id': 6, 'name': 'Boiler'}],
            'current_page': 1, 'last_page': 1, 'total': 2,
          }),
    };

Future<void> pumpOpener(WidgetTester tester, ProviderContainer c, int formId, void Function(bool) done) async {
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(builder: (ctx) => TextButton(onPressed: () async => done(await openForm(ctx, formMetaId: formId)), child: const Text('open'))),
      ),
    ),
  ));
  await tester.tap(find.text('open'));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pumpAndSettle();
}

void main() {
  moreFormTests();
  testWidgets('work order form shows required marks and blocks save until filled', (tester) async {
    final posted = <String, dynamic>{};
    final (c, a) = setup(workOrderRoutes(posted: posted));
    // A tall screen, so every field of the form is built.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    bool? result;
    await pumpOpener(tester, c, 129, (r) => result = r);

    for (final l in ['Asset *', 'Title *', 'Type *', 'Priority *', 'Status *']) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    expect(find.text('Work order *'), findsNothing); // an autonumber is filled in by the server
    expect(find.text('Work order'), findsWidgets);
    expect(find.text('Reported by'), findsOneWidget);
    expect(find.text('PM plan'), findsNothing);
    expect(find.text('Parts'), findsOneWidget); // its lines, as a section
    expect(find.text('No lines yet'), findsOneWidget);
    expect(find.text('Corrective'), findsOneWidget);
    expect(find.text('Medium'), findsOneWidget);
    expect(find.text(today()), findsOneWidget);

    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(a.seen.where((o) => o.method == 'POST'), isEmpty);
    expect(find.text('This field is required'), findsNWidgets(2));

    await tester.tap(find.text('Asset *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pump 1'));
    await tester.pumpAndSettle();
    expect(find.text('Pump 1'), findsOneWidget);
    await tester.enterText(fieldBox('Title *'), 'Fix pump');
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsNothing);

    await tester.tap(find.text('Save'));
    // The Saved toast drops in: its words show once it has opened, and it is gone after ~5s.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.text('Saved'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(posted['asset_id'], 5);
    expect(posted['title'], 'Fix pump');
    expect(posted['type'], 'corrective');
    expect(posted['priority'], 'medium');
    expect(posted['status'], 'open');
    expect(posted['reported_on'], today());
    expect(posted['wo_no'], isNull);
    expect(posted['labor_hours'], isNull);
    expect(posted['parts_cost'], isNull);
    expect(posted['_context'], {'app_meta_id': 5});
    expect(posted['parts'], isEmpty);
    expect(posted.containsKey('pm_plan_id'), isFalse);
    expect(posted.containsKey('id'), isFalse);
    expect(result, isTrue);
    expect(find.text('open'), findsOneWidget);
  });

  testWidgets('autonumber preview shows for a new record', (tester) async {
    final (c, a) = setup({
      'GET /api/metas/40': (_) => (200, {'id': 40, 'type': 'form', 'name': 'Tickets'}),
      'GET /api/metas/40/params': (_) => (200, [
            p(1, 'no', 'Number', 'string', json: {'autonumber': {'format': 'T-{kind}-{seq:3}'}}),
            p(2, 'kind', 'Kind', 'string', def: 'hw'),
          ]),
      'GET /api/metas/40/autonumber': (o) => (200, {'no': 'T-${o.uri.queryParameters['values[kind]']}-001'}),
    });
    await pumpOpener(tester, c, 40, (_) {});
    expect(find.text('T-hw-001'), findsOneWidget);
    expect(find.text('Given when saved: this is the next number.'), findsOneWidget);
    await tester.enterText(fieldBox('Kind'), 'sw');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(find.text('T-sw-001'), findsOneWidget);
    expect(a.seen.where((o) => o.uri.path.endsWith('/autonumber')).length, 2);
  });

  testWidgets('a 422 shows field errors under fields and the rest in a banner', (tester) async {
    final (c, _) = setup({
      'GET /api/metas/41': (_) => (200, {'id': 41, 'type': 'form', 'name': 'Notes'}),
      'GET /api/metas/41/params': (_) => (200, [p(1, 'title', 'Title', 'string')]),
      'POST /api/metas/41/data': (_) => (422, {
            'message': 'Invalid.',
            'errors': {'title': ['Title is taken.'], 'lines.0.qty': ['Line 1 needs a qty.']},
          }),
    });
    bool? result;
    await pumpOpener(tester, c, 41, (r) => result = r);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Title is taken.'), findsOneWidget);
    expect(find.text('Line 1 needs a qty.'), findsOneWidget);
    expect(result, isNull);
  });

  testWidgets('editing loads the record, PUTs it; read-only has no Save', (tester) async {
    Map<String, dynamic>? put;
    final (c, _) = setup({
      'GET /api/metas/41': (_) => (200, {'id': 41, 'type': 'form', 'name': 'Notes', 'json_config': {'save_and_add': false}}),
      'GET /api/metas/41/params': (_) => (200, [p(1, 'title', 'Title', 'string'), p(2, 'done', 'Done', 'boolean')]),
      'GET /api/metas/41/data/3': (_) => (200, {'id': 3, 'title': 'Old', 'done': 1}),
      'PUT /api/metas/41/data/3': (o) {
        put = Map<String, dynamic>.from(o.data as Map);
        return (200, {'id': 3});
      },
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(builder: (ctx) => Column(children: [
                TextButton(onPressed: () => openForm(ctx, formMetaId: 41, recordId: 3), child: const Text('edit')),
                TextButton(onPressed: () => openForm(ctx, formMetaId: 41, recordId: 3, readOnly: true), child: const Text('view')),
              ])),
        ),
      ),
    ));
    await tester.tap(find.text('view'));
    await tester.pumpAndSettle();
    expect(find.text('Old'), findsOneWidget);
    expect(find.text('Save'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    expect(find.text('Save and add'), findsNothing);
    await tester.enterText(fieldBox('Title'), 'New');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(put, {'title': 'New', 'done': true, '_context': {'app_meta_id': 5}});
  });

  testWidgets('wizard Next checks the required fields of the step', (tester) async {
    final (c, _) = setup({
      'GET /api/metas/42': (_) => (200, {'id': 42, 'type': 'form', 'name': 'Wiz', 'json_config': {'layout': 'wizard'}}),
      'GET /api/metas/42/params': (_) => (200, [
            p(1, 'a', 'Alpha', 'string', required: true, json: {'group': 'One'}),
            p(2, 'b', 'Beta', 'string', json: {'group': 'Two'}),
          ]),
    });
    await pumpOpener(tester, c, 42, (_) {});
    expect(find.text('Save'), findsNothing);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Fill this in before going on.'), findsOneWidget);
    expect(find.text('Beta'), findsNothing);
    await tester.enterText(fieldBox('Alpha *'), 'x');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });
}

void moreFormTests() {
  testWidgets('a line is added on its own page; the total follows it and the lines are sent', (tester) async {
    final posted = <String, dynamic>{};
    final routes = workOrderRoutes(posted: posted);
    workOrderParams[18] = p(19, 'parts', 'Parts', 'detail', ref: 130, json: {'foreign_key': 'work_order_id', 'amount': ['quantity', 'unit_cost'], 'total_field': 'parts_cost'});
    addTearDown(() => workOrderParams[18] = p(19, 'parts', 'Parts', 'detail', ref: 130, json: {'total_field': 'parts_cost'}));
    final (c, _) = setup(routes);
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpOpener(tester, c, 129, (_) {});

    await tester.tap(find.text('Add line'));
    await tester.pumpAndSettle();
    expect(find.text('New: Parts'), findsOneWidget);
    expect(find.text('Work order'), findsNothing); // the foreign key is the server's
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsOneWidget); // Part
    await tester.enterText(fieldBox('Part *'), 'Seal');
    await tester.enterText(fieldBox('Quantity'), '2');
    await tester.enterText(fieldBox('Unit cost'), '12.5');
    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();

    expect(find.text('Seal'), findsOneWidget);
    expect(find.text('25.00'), findsWidgets); // the line's amount and the section total
    expect(find.text('Total'), findsOneWidget);

    await tester.tap(find.text('Asset *'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pump 1'));
    await tester.pumpAndSettle();
    await tester.enterText(fieldBox('Title *'), 'Fix pump');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(posted['parts_cost'], 25);
    expect(posted['parts'], [
      {'work_order_id': null, 'part': 'Seal', 'quantity': 2, 'unit_cost': 12.5},
    ]);
  });

  testWidgets('two taps on Save in the same frame send one POST', (tester) async {
    var posts = 0;
    final (c, _) = setup({
      'GET /api/metas/43': (_) => (200, {'id': 43, 'type': 'form', 'name': 'Notes', 'json_config': {'save_and_add': false}}),
      'GET /api/metas/43/params': (_) => (200, [p(1, 'title', 'Title', 'string')]),
      'POST /api/metas/43/data': (_) {
        posts++;
        return (201, {'id': 1});
      },
    });
    await pumpOpener(tester, c, 43, (_) {});
    await tester.tap(find.text('Save'));
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(posts, 1);
  });

  testWidgets('a 422 on a field low in a long form shows the banner and scrolls to the field', (tester) async {
    final (c, _) = setup({
      'GET /api/metas/44': (_) => (200, {'id': 44, 'type': 'form', 'name': 'Long'}),
      'GET /api/metas/44/params': (_) => (200, [for (var i = 1; i <= 30; i++) p(i, 'f$i', 'Field $i', 'string')]),
      'POST /api/metas/44/data': (_) => (422, {
            'message': 'Field 30 is wrong.',
            'errors': {'f30': ['Field 30 is wrong.']},
          }),
    });
    await pumpOpener(tester, c, 44, (_) {});
    expect(find.text('Field 30').hitTestable(), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Check the marked fields.'), findsOneWidget);
    expect(find.text('Field 30 is wrong.').hitTestable(), findsOneWidget);
  });

  testWidgets("a form's files show, one can be taken off, and saving sends the rest by id", (tester) async {
    Map<String, dynamic>? put;
    final (c, _) = setup({
      'GET /api/metas/42': (_) => (200, {'id': 42, 'type': 'form', 'name': 'PO', 'json_config': {'save_and_add': false}}),
      'GET /api/metas/42/params': (_) => (200, [
            p(1, 'title', 'Title', 'string'),
            p(2, 'attachments', 'Attachments', 'multifile', json: {'accept': ['pdf', 'jpg'], 'max_files': 5}),
          ]),
      'GET /api/metas/42/data/3': (_) => (200, {
            'id': 3,
            'title': 'PO-1',
            'attachments': [
              {'id': 7, 'file_name': 'quote.pdf', 'file_extension': 'pdf', 'file_size': 245760, 'description': null},
              {'id': 8, 'file_name': 'box.jpg', 'file_extension': 'jpg', 'file_size': 1048576, 'description': 'Front'},
            ],
          }),
      'PUT /api/metas/42/data/3': (o) {
        put = Map<String, dynamic>.from(o.data as Map);
        return (200, {'id': 3});
      },
    });
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(builder: (ctx) => Column(children: [
                TextButton(onPressed: () => openForm(ctx, formMetaId: 42, recordId: 3), child: const Text('edit')),
                TextButton(onPressed: () => openForm(ctx, formMetaId: 42, recordId: 3, readOnly: true), child: const Text('view')),
              ])),
        ),
      ),
    ));
    await tester.tap(find.text('view'));
    await tester.pumpAndSettle();
    expect(find.text('quote.pdf'), findsOneWidget);
    expect(find.text('Add'), findsNothing, reason: 'read-only: nothing to add or remove');
    expect(find.byTooltip('Remove file'), findsNothing);
    await tester.pageBack();
    await tester.pumpAndSettle();

    await tester.tap(find.text('edit'));
    await tester.pumpAndSettle();
    expect(find.text('quote.pdf'), findsOneWidget);
    expect(find.text('240 KB'), findsOneWidget);
    expect(find.text('1.0 MB · Front'), findsOneWidget);
    expect(find.text('Add'), findsOneWidget);
    await tester.tap(find.byTooltip('Remove file').first);
    await tester.pumpAndSettle();
    expect(find.text('quote.pdf'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(put!['attachments'], [{'id': 8, 'description': 'Front'}]);
  });
}
