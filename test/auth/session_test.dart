import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/config.dart';

class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> seen = [];
  final Map<String, (int, Object)> routes;
  FakeAdapter(this.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o);
    final r = routes['${o.method} ${o.uri.path}'];
    final (status, body) = r ?? (404, {'message': 'nope'});
    return ResponseBody.fromString(jsonEncode(body), status, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

class MemoryStorage implements TokenStorage {
  String? value;
  MemoryStorage([this.value]);
  @override
  Future<String?> read() async => value;
  @override
  Future<void> write(String token) async => value = token;
  @override
  Future<void> clear() async => value = null;
}

const mobile = (200, {
  'id': 5,
  'name': 'Shop',
  'description': null,
  'package_id': 'mn.shop',
  'color': '#112233',
  'customer': {'code': 'acme', 'name': 'Acme'},
});
const userRoutes = <String, (int, Object)>{
  'GET /api/user': (200, {'id': 1, 'name': 'Bat', 'email': 'b@x.mn', 'locale': 'mn'}),
  'GET /api/user/access': (200, {
    'is_admin': false,
    'metas': {'9': {'view': true}},
  }),
  'GET /api/user/session': (200, {'branch': 'B1'}),
};

({ProviderContainer c, FakeAdapter a, MemoryStorage s, ApiClient client}) setup(
  Map<String, (int, Object)> routes, {
  String? token,
  String? code,
}) {
  final adapter = FakeAdapter({'GET /api/mobile/5': mobile, 'GET /api/c/acme/mobile/5': mobile, ...routes});
  final config = AppConfig(appMetaId: 5, customerCode: code, apiBase: 'https://h/api');
  final client = ApiClient(config, dio: Dio()..httpClientAdapter = adapter);
  final storage = MemoryStorage(token);
  final c = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(config),
    apiClientProvider.overrideWithValue(client),
    tokenStorageProvider.overrideWithValue(storage),
  ]);
  addTearDown(c.dispose);
  return (c: c, a: adapter, s: storage, client: client);
}

void main() {
  test('signIn uses bound token when one customer', () async {
    final t = setup({
      'POST /api/login': (200, {
        'user': {'id': 1},
        'token': 'T1',
        'customers': [
          {'id': 7, 'code': 'acme', 'name': 'Acme', 'is_admin': false},
        ],
      }),
      ...userRoutes,
    });
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.signIn('b@x.mn', 'pw');
    expect(t.s.value, 'T1');
    expect(t.client.token, 'T1');
    expect(t.a.seen.any((r) => r.uri.path.contains('/customers/')), false);
    expect(t.c.read(sessionProvider).user?['name'], 'Bat');
    expect(t.client.locale, 'mn');
  });

  test('signIn switches to CUSTOMER_CODE customer when several', () async {
    final t = setup({
      'POST /api/login': (200, {
        'user': {'id': 1},
        'token': 'unbound',
        'customers': [
          {'id': 3, 'code': 'other', 'name': 'O', 'is_admin': false},
          {'id': 7, 'code': 'acme', 'name': 'Acme', 'is_admin': false},
        ],
      }),
      'POST /api/customers/7/use': (200, {
        'customer': {'id': 7, 'code': 'acme', 'name': 'Acme'},
        'token': 'BOUND',
      }),
      ...userRoutes,
    });
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.signIn('b@x.mn', 'pw');
    expect(t.a.seen.any((r) => r.method == 'POST' && r.uri.path == '/api/customers/7/use'), true);
    expect(t.s.value, 'BOUND');
    expect(t.client.token, 'BOUND');
    expect(t.c.read(sessionProvider).access, isNotNull);
  });

  test('signIn errors when user is not in the customer', () async {
    final t = setup({
      'POST /api/login': (200, {
        'user': {'id': 1},
        'token': 'unbound',
        'customers': [
          {'id': 3, 'code': 'other', 'name': 'O', 'is_admin': false},
          {'id': 4, 'code': 'third', 'name': 'T', 'is_admin': false},
        ],
      }),
    });
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.signIn('b@x.mn', 'pw');
    final s = t.c.read(sessionProvider);
    expect(s.error, isNotNull);
    expect(s.user, isNull);
    expect(t.s.value, isNull);
    expect(t.client.token, isNull);
  });

  test('bad credentials show the error and stay signed out', () async {
    final t = setup({
      'POST /api/login': (401, {'message': 'Invalid credentials.'}),
    });
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.signIn('b@x.mn', 'bad');
    final s = t.c.read(sessionProvider);
    expect(s.error, 'Invalid credentials.');
    expect(s.loading, false);
  });

  test('start restores token and loads user/access/session', () async {
    final t = setup(userRoutes, token: 'SAVED');
    await t.c.read(sessionProvider.notifier).start();
    final s = t.c.read(sessionProvider);
    expect(t.client.token, 'SAVED');
    expect(s.info?.name, 'Shop');
    expect(s.info?.customerCode, 'acme');
    expect(s.user?['email'], 'b@x.mn');
    expect(s.access?.can(9, 'view'), true);
    expect(s.access?.can(9, 'edit'), false);
    final ctl = t.c.read(sessionProvider.notifier);
    expect(ctl.sessionValue('branch'), 'B1');
    expect(ctl.sessionValue('missing'), isNull);
    expect(ctl.can(9, 'view'), true);
  });

  test('401 during loadUser returns to signed-out state', () async {
    final t = setup({
      'GET /api/user': (401, {'message': 'Unauthenticated.'}),
      'GET /api/user/access': (401, {'message': 'Unauthenticated.'}),
      'GET /api/user/session': (401, {'message': 'Unauthenticated.'}),
    }, token: 'OLD');
    await t.c.read(sessionProvider.notifier).start();
    final s = t.c.read(sessionProvider);
    expect(s.user, isNull);
    expect(s.access, isNull);
    expect(s.loading, false);
    expect(t.s.value, isNull);
    expect(t.client.token, isNull);
    expect(t.a.seen.where((r) => r.uri.path.endsWith('/logout')), isEmpty);
  });

  test('signOut posts logout then clears', () async {
    final t = setup({'POST /api/logout': (200, {'message': 'ok'}), ...userRoutes}, token: 'SAVED');
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.signOut();
    expect(t.a.seen.any((r) => r.uri.path == '/api/logout'), true);
    expect(t.s.value, isNull);
    expect(t.c.read(sessionProvider).user, isNull);
  });
}
