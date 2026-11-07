import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/api/models.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/config.dart';
import 'package:wand_mobile/meta/defs.dart';
import 'package:wand_mobile/nav/shell.dart';

class RouteAdapter implements HttpClientAdapter {
  final Map<String, (int, Object)> routes;
  final List<String> seen = [];
  RouteAdapter(this.routes);
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o.uri.path);
    final (status, body) = routes[o.uri.path] ?? (404, {'message': 'nope'});
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

class FakeSession extends SessionController {
  @override
  SessionState build() => SessionState(
        info: MobileInfo(id: 5, name: 'Shop'),
        user: const {'id': 1},
        access: Access(metas: {
          '1': {'view': true},
          '2': {'view': true},
          '4': {'view': true},
        }),
      );
  void set(SessionState s) => state = s;
}

Map<String, (int, Object)> baseRoutes() => {
      '/api/metas/5': (200, {'id': 5, 'type': 'app'}),
      '/api/metas/5/params': (200, [
        {'id': 10, 'param_name': 'One', 'ref_meta_id': 1, 'order_number': 1},
        {'id': 11, 'param_name': 'Two', 'ref_meta_id': 2, 'order_number': 2},
        {'id': 12, 'param_name': 'Three', 'ref_meta_id': 3, 'order_number': 3},
        {'id': 13, 'param_name': 'Four', 'ref_meta_id': 4, 'order_number': 4},
      ]),
      '/api/metas/1': (200, {'id': 1, 'type': 'datagrid'}),
      '/api/metas/1/params': (200, []),
      '/api/metas/2': (200, {'id': 2, 'type': 'datagrid'}),
      '/api/metas/2/params': (200, []),
      '/api/metas/3': (200, {'id': 3, 'type': 'datagrid'}),
      '/api/metas/3/params': (200, []),
      '/api/metas/4': (200, {'id': 4, 'type': 'form'}),
      '/api/metas/4/params': (200, []),
    };

(ProviderContainer, RouteAdapter) setup(Map<String, (int, Object)> routes) {
  final adapter = RouteAdapter(routes);
  final config = AppConfig(appMetaId: 5, apiBase: 'https://h/api');
  final client = ApiClient(config, dio: Dio()..httpClientAdapter = adapter);
  final c = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(config),
    apiClientProvider.overrideWithValue(client),
    sessionProvider.overrideWith(FakeSession.new),
  ]);
  addTearDown(c.dispose);
  return (c, adapter);
}

void main() {
  test('a ref meta answering 404 drops only that screen', () async {
    final routes = baseRoutes()..['/api/metas/2'] = (404, {'message': 'gone'});
    final (c, _) = setup(routes);
    final m = await c.read(mobileMenuProvider.future);
    expect(m.all.map((e) => e.label), ['One', 'Four']);
  });

  test('ids denied by canView are not fetched', () async {
    final (c, a) = setup(baseRoutes());
    final m = await c.read(mobileMenuProvider.future);
    expect(m.all.map((e) => e.label), ['One', 'Two', 'Four']);
    expect(a.seen.any((p) => p.startsWith('/api/metas/3')), isFalse);
  });

  test('a failing app meta puts the menu in the error state', () async {
    final routes = baseRoutes()..['/api/metas/5'] = (500, {'message': 'boom'});
    final (c, _) = setup(routes);
    await expectLater(c.read(mobileMenuProvider.future), throwsA(isA<ApiError>()));
  });

  test('a transient failure on one ref meta is an error, not a cached null, and retry recovers', () async {
    final routes = baseRoutes()..['/api/metas/2'] = (500, {'message': 'boom'});
    final (c, _) = setup(routes);
    await expectLater(c.read(mobileMenuProvider.future), throwsA(isA<ApiError>()));

    routes['/api/metas/2'] = (200, {'id': 2, 'type': 'datagrid'});
    c.invalidate(metaDefProvider);
    c.invalidate(metaTypeProvider);
    c.invalidate(mobileMenuProvider);
    final m = await c.read(mobileMenuProvider.future);
    expect(m.all.map((e) => e.label), ['One', 'Two', 'Four']);
  });

  test('definitions are fetched again after the signed-in user changes', () async {
    final (c, a) = setup(baseRoutes());
    await c.read(metaDefProvider(1).future);
    await c.read(metaDefProvider(1).future);
    expect(a.seen.where((p) => p == '/api/metas/1').length, 1);

    (c.read(sessionProvider.notifier) as FakeSession).set(SessionState(info: MobileInfo(id: 5, name: 'Shop')));
    await c.read(metaDefProvider(1).future);
    expect(a.seen.where((p) => p == '/api/metas/1').length, 2);
  });
}
