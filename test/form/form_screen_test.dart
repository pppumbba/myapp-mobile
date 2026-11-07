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
import 'package:wand_mobile/form/form_screen.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';

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
    expect(find.text('Parts'), findsNothing);
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
    await tester.enterText(find.widgetWithText(TextField, 'Title *'), 'Fix pump');
    await tester.pumpAndSettle();
    expect(find.text('This field is required'), findsNothing);

    await tester.tap(find.text('Save'));
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
    expect(posted.containsKey('parts'), isFalse);
    expect(posted.containsKey('pm_plan_id'), isFalse);
    expect(posted.containsKey('id'), isFalse);
    expect(result, isTrue);
    expect(find.text('open'), findsOneWidget);
    expect(find.text('Saved'), findsOneWidget);
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
    await tester.enterText(find.widgetWithText(TextField, 'Kind'), 'sw');
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
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'New');
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
    await tester.enterText(find.widgetWithText(TextField, 'Alpha *'), 'x');
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Beta'), findsOneWidget);
    expect(find.text('Save'), findsOneWidget);
    expect(find.text('Back'), findsOneWidget);
  });
}
