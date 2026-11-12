import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/widgets/pill_buttons.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/config.dart';
import 'package:wand_mobile/grid/filter_sheet.dart';
import 'package:wand_mobile/grid/grid_screen.dart';
import 'package:wand_mobile/grid/record_card.dart';
import 'package:wand_mobile/widgets/speed_dial.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';

/// Returns (status, body); a null result means the network is down.
typedef Handler = (int, Object?)? Function(RequestOptions o);

class Adapter implements HttpClientAdapter {
  final Map<String, Handler> routes;
  final List<RequestOptions> seen = [];
  Adapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o);
    final h = routes['${o.method} ${o.uri.path}'];
    final r = h == null ? (404, {'message': 'nope'}) : h(o);
    if (r == null) throw const NetworkDown();
    return ResponseBody.fromString(jsonEncode(r.$2), r.$1, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

class NetworkDown implements Exception {
  const NetworkDown();
}

class SignedIn extends SessionController {
  @override
  SessionState build() => SessionState(
        info: MobileInfo(id: 5, name: 'EAM'),
        user: const {'id': 1, 'name': 'Bat'},
        access: Access(metas: {
          '131': {'view': true, 'create': true, 'edit': true, 'delete': true},
          '130': {'view': true},
          '129': {'view': true},
        }),
      );
}

Map<String, dynamic> gp(int id, String path, String label,
        {String type = 'string',
        String? render,
        bool show = true,
        bool primary = false,
        bool criteria = false,
        bool mandatory = false,
        bool isLabel = false,
        bool select = false,
        int? ref,
        Map<String, dynamic>? json}) =>
    {
      'id': id, 'param_name': path, 'field_path': path, 'label_name': label, 'data_type': type, 'render_type': render,
      'is_show': show, 'is_primary': primary, 'is_criteria': criteria, 'is_mandatory_criteria': mandatory, 'is_label': isLabel,
      'is_select': select, 'ref_meta_id': ref, 'json_config': json, 'order_number': id,
    };

List<Map<String, dynamic>> gridParams({bool mandatory = false}) => [
      gp(1, 'id', 'Id', type: 'integer', primary: true, show: false),
      gp(2, 'wo_no', 'Work order', isLabel: true),
      gp(3, 'title', 'Title'),
      gp(4, 'status', 'Status', render: 'status', criteria: true, mandatory: mandatory, json: {'options': ['open', 'completed']}),
      gp(5, 'asset_id', 'Asset', type: 'integer', select: true, ref: 127),
    ];

const actions = [
  {'id': 245, 'grid_meta_id': 131, 'action': 'add', 'label': 'Add', 'form_meta_id': 129, 'needs_row': 0, 'show_in_toolbar': 1, 'show_in_row': 0, 'order_number': 1},
  {'id': 246, 'grid_meta_id': 131, 'action': 'edit', 'label': 'Edit', 'form_meta_id': 129, 'needs_row': 1, 'show_in_toolbar': 1, 'show_in_row': 1, 'order_number': 2, 'json_config': {'params': {'id': 'id'}}},
  {'id': 247, 'grid_meta_id': 131, 'action': 'delete', 'label': 'Delete', 'form_meta_id': 129, 'needs_row': 1, 'show_in_toolbar': 1, 'show_in_row': 1, 'order_number': 3, 'json_config': {'params': {'id': 'id'}}},
  {'id': 248, 'grid_meta_id': 131, 'action': 'stage_query', 'label': 'Complete', 'form_meta_id': 130, 'needs_row': 1, 'show_in_toolbar': 1, 'show_in_row': 1, 'order_number': 4, 'json_config': {'params': {'work_order_id': 'id'}}},
];

Map<String, dynamic> row(int i) => {'id': i, 'wo_no': 'WO-$i', 'title': 'Fix $i', 'status': 'open', 'asset_id': 5};

Map<String, Handler> routes({bool mandatory = false, Map<String, dynamic> Function(RequestOptions o)? data}) => {
      'GET /api/metas/131': (_) => (200, {'id': 131, 'type': 'datagrid', 'name': 'Work orders', 'json_config': {}}),
      'GET /api/metas/131/params': (_) => (200, gridParams(mandatory: mandatory)),
      'GET /api/metas/131/actions': (_) => (200, actions),
      'GET /api/metas/131/data': (o) => (200, data?.call(o) ?? {'data': [row(7)], 'current_page': 1, 'last_page': 1, 'total': 1}),
      'GET /api/metas/131/facets': (_) => (200, {
            'status': [
              {'value': 'open', 'count': 3},
            ],
          }),
      'GET /api/metas/127/data': (_) => (200, {
            'data': [
              {'id': 5, 'name': 'Pump 1'},
            ],
            'current_page': 1,
            'last_page': 1,
          }),
    };

Iterable<RequestOptions> dataCalls(Adapter a) => a.seen.where((o) => o.method == 'GET' && o.uri.path == '/api/metas/131/data');

/// The client of the last [pumpGrid], to fire writes from a test.
late ApiClient lastClient;

Future<Adapter> pumpGrid(WidgetTester tester, Map<String, Handler> r, {Map<String, String> filters = const {}}) async {
  final adapter = Adapter(r);
  final config = AppConfig(appMetaId: 5, apiBase: 'https://h/api');
  final client = lastClient = ApiClient(config, dio: Dio()..httpClientAdapter = adapter);
  final c = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(config),
    apiClientProvider.overrideWithValue(client),
    sessionProvider.overrideWith(SignedIn.new),
  ]);
  addTearDown(c.dispose);
  await tester.pumpWidget(UncontrolledProviderScope(
    container: c,
    child: MaterialApp(
      localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: GridScreen(metaId: 131, filters: filters)),
    ),
  ));
  await tester.pumpAndSettle();
  return adapter;
}

void main() {
  lookupChipTests();
  stageQueryGuardTests();
  testWidgets('grid shows cards with lookup text, never the raw id', (tester) async {
    await pumpGrid(tester, routes());
    expect(find.text('WO-7'), findsOneWidget);
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Asset: Pump 1'), findsOneWidget);
    expect(find.textContaining('#5'), findsNothing);
    expect(find.byType(SpeedDialFab), findsOneWidget);
  });

  testWidgets('grid shows missing filters message and opens the sheet', (tester) async {
    await pumpGrid(
      tester,
      routes(mandatory: true, data: (o) => {'data': [], 'current_page': 1, 'last_page': 1, 'total': 0, 'missing_filters': ['status']}),
    );
    expect(find.text('Choose a filter first: Status'), findsOneWidget);
    expect(find.byType(FilterSheet), findsOneWidget);
    expect(find.text('Status *'), findsOneWidget);
    // Facet counts show next to the options.
    expect(find.descendant(of: find.byType(FilterSheet), matching: find.text('Open')), findsOneWidget);
    expect(find.descendant(of: find.byType(FilterSheet), matching: find.text('3')), findsOneWidget);
  });

  testWidgets('an empty grid says nothing is here yet and points to the + button', (tester) async {
    await pumpGrid(tester, routes(data: (o) => {'data': [], 'current_page': 1, 'last_page': 1, 'total': 0}));
    expect(find.text('Nothing here yet'), findsOneWidget);
    expect(find.text('Tap + to add the first one.'), findsOneWidget);
    expect(find.text('Clear search and filters'), findsNothing);
  });

  testWidgets('a filter that matches nothing offers to clear it', (tester) async {
    final a = await pumpGrid(
      tester,
      routes(data: (o) => {'data': [], 'current_page': 1, 'last_page': 1, 'total': 0}),
      filters: {'status': 'closed'},
    );
    expect(find.text('No results'), findsOneWidget);
    expect(dataCalls(a).last.uri.queryParameters['filter[status]'], 'closed');
    await tester.tap(find.text('Clear search and filters'));
    await tester.pumpAndSettle();
    expect(dataCalls(a).last.uri.queryParameters.containsKey('filter[status]'), false);
  });

  testWidgets('filter sheet applies a filter and shows a removable chip', (tester) async {
    final a = await pumpGrid(tester, routes());
    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FilterSheet), matching: find.text('Open')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(dataCalls(a).last.uri.queryParameters['filter[status]'], 'open');
    expect(find.text('Status: Open'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(dataCalls(a).last.uri.queryParameters.containsKey('filter[status]'), false);
    expect(find.text('Status: Open'), findsNothing);
  });

  testWidgets('filter sheet sorts by a column, descending, and the sort pill drops it', (tester) async {
    final a = await pumpGrid(tester, routes());
    await tester.tap(find.byTooltip('Filter'));
    await tester.pumpAndSettle();
    final sheet = find.byType(FilterSheet);
    expect(find.descendant(of: sheet, matching: find.text('Ascending')), findsNothing);
    await tester.scrollUntilVisible(find.descendant(of: sheet, matching: find.text('Title')), 100,
        scrollable: find.descendant(of: sheet, matching: find.byType(Scrollable)).first);
    await tester.tap(find.descendant(of: sheet, matching: find.text('Title')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.descendant(of: sheet, matching: find.text('Descending')), 100,
        scrollable: find.descendant(of: sheet, matching: find.byType(Scrollable)).first);
    await tester.tap(find.descendant(of: sheet, matching: find.text('Descending')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apply'));
    await tester.pumpAndSettle();
    expect(dataCalls(a).last.uri.queryParameters['sort'], 'title');
    expect(dataCalls(a).last.uri.queryParameters['dir'], 'desc');
    expect(find.text('Sort by: Title ↓'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(dataCalls(a).last.uri.queryParameters.containsKey('sort'), false);
    expect(find.text('Sort by: Title ↓'), findsNothing);
  });

  testWidgets('search is debounced and sent as search', (tester) async {
    final a = await pumpGrid(tester, routes());
    await tester.enterText(find.byType(TextField).first, 'pump');
    await tester.pump(const Duration(milliseconds: 100));
    expect(dataCalls(a).where((o) => o.uri.queryParameters['search'] == 'pump'), isEmpty);
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    expect(dataCalls(a).where((o) => o.uri.queryParameters['search'] == 'pump'), hasLength(1));
  });

  testWidgets('grid loads page 2 on scroll end', (tester) async {
    final a = await pumpGrid(tester, routes(data: (o) {
      final page = int.parse(o.uri.queryParameters['page'] ?? '1');
      return {
        'data': [for (var i = 0; i < 20; i++) row(page * 100 + i)],
        'current_page': page,
        'last_page': 2,
        'total': 40,
      };
    }));
    expect(dataCalls(a).where((o) => o.uri.queryParameters['page'] == '2'), isEmpty);
    await tester.fling(find.byType(ListView).last, const Offset(0, -6000), 3000);
    await tester.pumpAndSettle();
    expect(dataCalls(a).where((o) => o.uri.queryParameters['page'] == '2'), hasLength(1));
    await tester.fling(find.byType(ListView).last, const Offset(0, -6000), 3000);
    await tester.pumpAndSettle();
    expect(find.text('WO-219'), findsOneWidget);
    expect(dataCalls(a), hasLength(2));
  });

  testWidgets("delete calls DELETE on the action's form meta", (tester) async {
    final r = routes()..['DELETE /api/metas/129/data/7'] = (_) => (200, {'ok': true});
    final a = await pumpGrid(tester, r);
    await tester.drag(find.byType(RecordCard).first, const Offset(-260, 0)); // the row's actions are on swipe
    await tester.pumpAndSettle();
    expect(find.text('Complete'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete this record?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();
    expect(a.seen.where((o) => o.method == 'DELETE').single.uri.path, '/api/metas/129/data/7');
    expect(dataCalls(a), hasLength(2));
  });

  testWidgets('stage query sheet: check then run', (tester) async {
    final bodies = <Map<String, dynamic>>[];
    final r = routes()
      ..['GET /api/metas/130'] = ((_) => (200, {'id': 130, 'type': 'stage_query', 'name': 'Complete work order', 'json_config': {}}))
      ..['GET /api/metas/130/params'] = ((_) => (200, [gp(1, 'work_order_id', 'Work order id', type: 'integer')]))
      ..['POST /api/metas/130/run'] = (o) {
        final b = Map<String, dynamic>.from(o.data as Map);
        bodies.add(b);
        return (200, {'affected': 1, 'statements': [1], 'dry_run': b['dry_run']});
      };
    final a = await pumpGrid(tester, r);
    await tester.drag(find.byType(RecordCard).first, const Offset(-260, 0)); // the row's actions are on swipe
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    expect(find.widgetWithText(TextField, '7'), findsOneWidget);
    final run = find.widgetWithText(FilledButton, 'Run');
    expect(tester.widget<FilledButton>(run).onPressed, isNull);
    await tester.tap(find.widgetWithText(SoftButton, 'Check'));
    await tester.pumpAndSettle();
    expect(bodies.single, {
      'params': {'work_order_id': '7'},
      'dry_run': true,
    });
    expect(find.text('This will change 1 rows. Run it?'), findsOneWidget);
    await tester.tap(run);
    // Like a form save: the sheet closes and a toast says what ran.
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(bodies.last['dry_run'], false);
    expect(find.text('Done: 1 rows changed.'), findsOneWidget);
    expect(find.text('Check'), findsNothing);
    await tester.pumpAndSettle();
    expect(dataCalls(a), hasLength(2));
  });

  testWidgets('stage query: changing an input clears the check', (tester) async {
    final r = routes()
      ..['GET /api/metas/130'] = ((_) => (200, {'id': 130, 'type': 'stage_query', 'name': 'Complete', 'json_config': {}}))
      ..['GET /api/metas/130/params'] = ((_) => (200, [gp(1, 'work_order_id', 'Work order id', type: 'integer')]))
      ..['POST /api/metas/130/run'] = (o) => (200, {'affected': 0, 'statements': [0], 'dry_run': true});
    await pumpGrid(tester, r);
    await tester.drag(find.byType(RecordCard).first, const Offset(-260, 0)); // the row's actions are on swipe
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SoftButton, 'Check'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing to change: no rows match.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Run')).onPressed, isNull);
    await tester.enterText(find.widgetWithText(TextField, '7'), '8');
    await tester.pumpAndSettle();
    expect(find.text('Nothing to change: no rows match.'), findsNothing);
    // The dry run was a write: the lookup cache was cleared, yet the card never shows the raw id.
    Navigator.of(tester.element(find.text('Check'))).pop();
    await tester.pumpAndSettle();
    expect(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == 'Asset: Pump 1'), findsOneWidget);
    expect(find.textContaining('#5'), findsNothing);
  });

  testWidgets('network error shows Retry and reloads', (tester) async {
    var down = true;
    final r = routes();
    final ok = r['GET /api/metas/131/data']!;
    r['GET /api/metas/131/data'] = (o) => down ? null : ok(o);
    await pumpGrid(tester, r);
    expect(find.text(defaultUnreachableMessage), findsOneWidget);
    down = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('WO-7'), findsOneWidget);
    expect(find.text(defaultUnreachableMessage), findsNothing);
  });

  testWidgets('failed reload then Retry reloads page 1 and drops old rows', (tester) async {
    var down = false;
    final r = routes(data: (o) {
      final page = int.parse(o.uri.queryParameters['page'] ?? '1');
      final tag = o.uri.queryParameters['search'] == null ? 1 : 5;
      return {
        'data': [for (var i = 0; i < 20; i++) row(tag * 1000 + page * 100 + i)],
        'current_page': page,
        'last_page': 3,
        'total': 60,
      };
    });
    final ok = r['GET /api/metas/131/data']!;
    r['GET /api/metas/131/data'] = (o) => down ? null : ok(o);
    final a = await pumpGrid(tester, r);
    expect(find.text('WO-1100'), findsOneWidget);
    down = true;
    await tester.enterText(find.byType(TextField).first, 'pump');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(find.text(defaultUnreachableMessage), findsOneWidget);
    expect(find.text('WO-1100'), findsNothing);
    down = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    final last = dataCalls(a).last.uri.queryParameters;
    expect(last['page'], '1');
    expect(last['search'], 'pump');
    expect(find.text('WO-5100'), findsOneWidget);
    expect(find.text('WO-1100'), findsNothing);
  });

  testWidgets('a short page 2 still loads page 3', (tester) async {
    final a = await pumpGrid(tester, routes(data: (o) {
      final page = int.parse(o.uri.queryParameters['page'] ?? '1');
      return {
        'data': [for (var i = 0; i < (page == 1 ? 20 : 1); i++) row(page * 100 + i)],
        'current_page': page,
        'last_page': 3,
        'total': 22,
      };
    }));
    final pos = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
    pos.jumpTo(pos.maxScrollExtent);
    await tester.pumpAndSettle();
    expect(dataCalls(a).map((o) => o.uri.queryParameters['page']), ['1', '2', '3']);
  });

  testWidgets('footer aggregates show as one line', (tester) async {
    await pumpGrid(tester, routes(data: (o) => {
          'data': [row(7)],
          'current_page': 1,
          'last_page': 1,
          'total': 1,
          'footer': {'title': 'x', 'status': null},
        }));
    expect(find.text('Title: x'), findsOneWidget);
  });

  test('MetaParam has the mandatory flag', () {
    expect(MetaParam.fromJson(gridParams(mandatory: true)[3]).isMandatoryCriteria, true);
  });
}

void stageQueryGuardTests() {
  testWidgets('stage query: two taps on Check in the same frame send one POST', (tester) async {
    var posts = 0;
    final r = routes()
      ..['GET /api/metas/130'] = ((_) => (200, {'id': 130, 'type': 'stage_query', 'name': 'Complete', 'json_config': {}}))
      ..['GET /api/metas/130/params'] = ((_) => (200, [gp(1, 'work_order_id', 'Work order id', type: 'integer')]))
      ..['POST /api/metas/130/run'] = (o) {
        posts++;
        return (200, {'affected': 1, 'statements': [1], 'dry_run': true});
      };
    await pumpGrid(tester, r);
    await tester.drag(find.byType(RecordCard).first, const Offset(-260, 0)); // the row's actions are on swipe
    await tester.pumpAndSettle();
    await tester.tap(find.text('Complete'));
    await tester.pumpAndSettle();
    final check = find.widgetWithText(SoftButton, 'Check');
    await tester.tap(check);
    await tester.tap(check);
    await tester.pumpAndSettle();
    expect(posts, 1);
  });
}

void lookupChipTests() {
  testWidgets('a lookup filter chip shows the label at start and after a write, never "…"', (tester) async {
    final r = routes()
      ..['GET /api/metas/131/params'] = ((_) => (200, [
            ...gridParams().take(4),
            // Not a card column: only the filter needs its label.
            gp(5, 'asset_id', 'Asset', type: 'integer', select: true, ref: 127, criteria: true, show: false),
          ]))
      ..['GET /api/metas/127/data'] = ((_) => (200, {
            'data': [
              {'id': 5, 'name': 'Pump 1'},
              {'id': 6, 'name': 'Boiler'},
            ],
            'current_page': 1,
            'last_page': 1,
          }))
      ..['POST /api/metas/1/touch'] = ((_) => (200, {'ok': true}));
    await pumpGrid(tester, r, filters: {'asset_id': '6'});
    expect(find.text('Asset: Boiler'), findsOneWidget);

    // Any write clears the lookup cache. Not awaited first: the fake clock only moves on pumps.
    final write = lastClient.post<dynamic>('/metas/1/touch', {});
    await tester.pumpAndSettle();
    await write;
    await tester.pumpAndSettle();
    expect(find.text('Asset: Boiler'), findsOneWidget);
    expect(find.textContaining('…'), findsNothing);
  });

  testWidgets('long-press on a row offers only Share to chat', (tester) async {
    await pumpGrid(tester, routes());
    await tester.longPress(find.byType(RecordCard).first);
    await tester.pumpAndSettle();
    expect(find.text('Share to chat'), findsOneWidget);
    expect(find.text('Complete'), findsNothing);
    expect(find.text('Delete'), findsNothing);
  });
}
