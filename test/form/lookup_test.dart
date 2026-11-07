import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/config.dart';
import 'package:wand_mobile/form/lookup.dart';
import 'package:wand_mobile/form/lookup_page.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';

typedef Handler = (int, Object) Function(Uri uri);
Duration Function(Uri uri)? delayFor;

class RouteAdapter implements HttpClientAdapter {
  final Map<String, Handler> routes;
  final List<Uri> seen = [];
  RouteAdapter(this.routes);
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o.uri);
    final d = delayFor?.call(o.uri);
    if (d != null) await Future<void>.delayed(d);
    final (status, body) = routes[o.uri.path]?.call(o.uri) ?? (404, {'message': 'nope'});
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

Map<String, dynamic> page(List<Map<String, dynamic>> rows, {int cur = 1, int last = 1}) =>
    {'data': rows, 'current_page': cur, 'last_page': last, 'total': rows.length};

(ProviderContainer, RouteAdapter) setup(Map<String, Handler> routes) {
  final adapter = RouteAdapter(routes);
  final config = AppConfig(appMetaId: 5, apiBase: 'https://h/api');
  final client = ApiClient(config, dio: Dio()..httpClientAdapter = adapter);
  final c = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(config),
    apiClientProvider.overrideWithValue(client),
  ]);
  addTearDown(c.dispose);
  return (c, adapter);
}

MetaParam lp({String? valueField, String? displayField, String? displayAs, Map<String, dynamic>? filterAs, int? ref = 7}) => MetaParam(
      id: 1, paramName: 'cust', isSelect: true, refMetaId: ref,
      valueField: valueField, displayField: displayField, displayAs: displayAs, filterAs: filterAs,
    );

const spec = LookupSpec(gridMetaId: 7, valueField: 'id', displayField: 'name');

void main() {
  setUp(() => delayFor = null);
  test('lookupSpecOf uses value_field/display_field and defaults', () {
    final a = lookupSpecOf(lp(valueField: 'code', displayField: 'name'))!;
    expect((a.gridMetaId, a.valueField, a.displayField), (7, 'code', 'name'));
    final b = lookupSpecOf(lp())!;
    expect((b.valueField, b.displayField), ('id', null));
    expect(lookupSpecOf(lp(displayAs: 'title', displayField: 'name'))!.displayField, 'title');
    expect(lookupSpecOf(lp(ref: null)), isNull);
    final f = lookupSpecOf(lp(valueField: 'id', displayField: 'name', filterAs: {
      'ref_meta_id': 9, 'value_field': 'code', 'display_field': 'label',
    }))!;
    expect((f.gridMetaId, f.valueField, f.displayField), (9, 'code', 'label'));
  });

  test('lookupText caches per value', () async {
    final (c, a) = setup({
      '/api/metas/7/data': (_) => (200, page([{'id': 1, 'name': 'Acme'}, {'id': 2, 'name': 'Bolt'}])),
    });
    final s = c.read(lookupServiceProvider);
    expect(await s.lookupText(spec, 1), 'Acme');
    expect(await s.lookupText(spec, 1), 'Acme');
    expect(a.seen.length, 1);
    expect(a.seen.first.queryParameters['per_page'], '100');
    expect(s.cachedText(spec, 1), 'Acme');
    expect(s.cachedText(spec, 99), isNull);
  });

  test('lookupText finds a value beyond the first page via scope', () async {
    final (c, a) = setup({
      '/api/metas/7/data': (u) => u.queryParameters.containsKey('scope[id]')
          ? (200, page([{'id': 500, 'name': 'Far'}]))
          : (200, page([{'id': 1, 'name': 'Acme'}], last: 3)),
    });
    final s = c.read(lookupServiceProvider);
    expect(await s.lookupText(spec, 500), 'Far');
    expect(a.seen.length, 2);
    expect(a.seen.last.queryParameters['scope[id]'], '500');
    expect(a.seen.last.queryParameters['per_page'], '1');
    expect(await s.lookupText(spec, 500), 'Far');
    expect(a.seen.length, 2);
  });

  test('lookupText returns null when not found', () async {
    final (c, _) = setup({'/api/metas/7/data': (_) => (200, page([]))});
    final s = c.read(lookupServiceProvider);
    expect(await s.lookupText(spec, 404), isNull);
    expect(s.cachedText(spec, 404), isNull);
  });

  test('clear forgets cached text', () async {
    final (c, a) = setup({'/api/metas/7/data': (_) => (200, page([{'id': 1, 'name': 'Acme'}]))});
    final s = c.read(lookupServiceProvider);
    await s.lookupText(spec, 1);
    s.clear();
    await s.lookupText(spec, 1);
    expect(a.seen.length, 2);
  });

  testWidgets('pickLookup searches and returns the tapped row', (tester) async {
    final (c, a) = setup({
      '/api/metas/7': (_) => (200, {'id': 7, 'type': 'datagrid'}),
      '/api/metas/7/params': (_) => (200, [
            {'id': 1, 'param_name': 'name', 'label_name': 'Name', 'is_label': true, 'order_number': 1},
          ]),
      '/api/metas/7/data': (u) => u.queryParameters['search'] == 'bo'
          ? (200, page([{'id': 2, 'name': 'Bolt'}]))
          : (200, page([{'id': 1, 'name': 'Acme'}, {'id': 2, 'name': 'Bolt'}])),
    });
    Map<String, dynamic>? picked;
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (ctx) => TextButton(onPressed: () async => picked = await pickLookup(ctx, spec), child: const Text('open'))),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Acme'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'bo');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.text('Acme'), findsNothing);
    expect(a.seen.last.queryParameters['search'], 'bo');
    expect(a.seen.last.queryParameters['per_page'], '50');
    await tester.tap(find.text('Bolt'));
    await tester.pumpAndSettle();
    expect(picked, {'id': 2, 'name': 'Bolt'});
  });

  test('a write clears the lookup cache', () async {
    var found = false;
    final (c, a) = setup({
      '/api/metas/7/data': (_) => (200, page(found ? [{'id': 3, 'name': 'New'}] : [])),
      '/api/x': (_) => (200, {}),
    });
    final s = c.read(lookupServiceProvider);
    expect(await s.lookupText(spec, 3), isNull);
    found = true;
    await c.read(apiClientProvider).post<dynamic>('/x', {});
    expect(await s.lookupText(spec, 3), 'New');
    expect(a.seen.where((u) => u.path == '/api/metas/7/data').length, 3);
  });

  Map<String, Handler> gridRoutes(Handler data) => {
        '/api/metas/7': (_) => (200, {'id': 7, 'type': 'datagrid'}),
        '/api/metas/7/params': (_) => (200, [
              {'id': 1, 'param_name': 'name', 'label_name': 'Name', 'is_label': true, 'order_number': 1},
            ]),
        '/api/metas/7/data': data,
      };

  Future<void> open(WidgetTester tester, ProviderContainer c, {Map<String, String> filters = const {}}) async {
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: MaterialApp(
        localizationsDelegates: const [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: (ctx) => TextButton(onPressed: () => pickLookup(ctx, spec, filters: filters), child: const Text('open'))),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('pickLookup sends filter[k]=v', (tester) async {
    final (c, a) = setup(gridRoutes((_) => (200, page([{'id': 1, 'name': 'Acme'}]))));
    await open(tester, c, filters: {'status': 'open'});
    final q = a.seen.lastWhere((u) => u.path == '/api/metas/7/data').queryParameters;
    expect(q['filter[status]'], 'open');
    expect(q['page'], '1');
  });

  testWidgets('pickLookup first load sends no filter or search keys', (tester) async {
    final (c, a) = setup(gridRoutes((_) => (200, page([{'id': 1, 'name': 'Acme'}]))));
    await open(tester, c);
    final q = a.seen.lastWhere((u) => u.path == '/api/metas/7/data').queryParameters;
    expect(q.keys.any((k) => k.startsWith('filter')), isFalse);
    expect(q.containsKey('search'), isFalse);
  });

  testWidgets('pickLookup pages until last_page', (tester) async {
    final (c, a) = setup(gridRoutes((u) {
      final pg = int.parse(u.queryParameters['page'] ?? '1');
      return (200, page([for (var i = 0; i < 20; i++) {'id': pg * 100 + i, 'name': 'R$pg-$i'}], cur: pg, last: 2));
    }));
    await open(tester, c);
    List<String?> pages() => a.seen.where((u) => u.path == '/api/metas/7/data').map((u) => u.queryParameters['page']).toList();
    expect(pages(), ['1']);
    await tester.drag(find.byType(ListView), const Offset(0, -3000));
    await tester.pumpAndSettle();
    expect(pages(), ['1', '2']);
    await tester.drag(find.byType(ListView), const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(pages(), ['1', '2']);
  });

  testWidgets('pickLookup ignores a stale search response', (tester) async {
    delayFor = (u) => u.queryParameters['search'] == 'a' ? const Duration(seconds: 2) : Duration.zero;
    final (c, _) = setup(gridRoutes((u) {
      final s = u.queryParameters['search'];
      return (200, page([{'id': 1, 'name': s == 'a' ? 'StaleRow' : s == 'ab' ? 'FreshRow' : 'Initial'}]));
    }));
    await open(tester, c);
    await tester.enterText(find.byType(TextField), 'a');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(find.byType(TextField), 'ab');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('FreshRow'), findsOneWidget);
    expect(find.text('StaleRow'), findsNothing);
  });

  testWidgets('pickLookup shows error with Retry and recovers', (tester) async {
    var ok = false;
    final (c, _) = setup(gridRoutes((_) => ok ? (200, page([{'id': 1, 'name': 'Acme'}])) : (500, {'message': 'boom'})));
    await open(tester, c);
    expect(find.text('boom'), findsOneWidget);
    ok = true;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('Acme'), findsOneWidget);
    expect(find.text('boom'), findsNothing);
  });
}
