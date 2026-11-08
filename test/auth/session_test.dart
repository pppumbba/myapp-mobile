import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/app.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/auth/sign_in_page.dart';
import 'package:wand_mobile/config.dart';
import 'package:wand_mobile/l10n/app_localizations.dart';

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

class ThrowingStorage implements TokenStorage {
  @override
  Future<String?> read() async => throw Exception("keystore");
  @override
  Future<void> write(String token) async {}
  @override
  Future<void> clear() async {}
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
  WebAuth? webAuth,
}) {
  final adapter = FakeAdapter({'GET /api/mobile/5': mobile, 'GET /api/c/acme/mobile/5': mobile, ...routes});
  final config = AppConfig(appMetaId: 5, customerCode: code, apiBase: 'https://h/api', appId: 'mn.shop_app');
  final client = ApiClient(config, dio: Dio()..httpClientAdapter = adapter);
  final storage = MemoryStorage(token);
  final c = ProviderContainer(overrides: [
    appConfigProvider.overrideWithValue(config),
    apiClientProvider.overrideWithValue(client),
    tokenStorageProvider.overrideWithValue(storage),
    if (webAuth != null) webAuthProvider.overrideWithValue(webAuth),
  ]);
  addTearDown(c.dispose);
  return (c: c, a: adapter, s: storage, client: client);
}

void main() {
  restoreTests();
  googleTests();
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

  test('signIn with a non-ApiError failure clears loading and shows the generic error', () async {
    final t = setup({
      'POST /api/login': (200, {'user': {}, 'token': 5, 'customers': []}),
    });
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.signIn('b@x.mn', 'pw');
    final s = t.c.read(sessionProvider);
    expect(s.loading, false);
    expect(s.error, isNotNull);
    expect(t.client.token, isNull);
    expect(t.s.value, isNull);
  });

  test("signIn rejects a single customer whose code differs from the app's", () async {
    final t = setup({
      'POST /api/login': (200, {
        'user': {'id': 1},
        'token': 'WRONG',
        'customers': [
          {'id': 3, 'code': 'other', 'name': 'O', 'is_admin': false},
        ],
      }),
      'POST /api/logout': (200, {'message': 'ok'}),
      ...userRoutes,
    });
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.signIn('b@x.mn', 'pw');
    final s = t.c.read(sessionProvider);
    expect(s.error, isNotNull);
    expect(s.user, isNull);
    expect(t.s.value, isNull);
    expect(t.client.token, isNull);
    final out = t.a.seen.where((r) => r.uri.path == '/api/logout');
    expect(out.length, 1);
    expect(out.first.headers['Authorization'], 'Bearer WRONG');
  });

  test('loadUser while signed in keeps the user during loading', () async {
    final t = setup(userRoutes, token: 'SAVED');
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    final seen = <bool>[];
    t.c.listen(sessionProvider, (_, n) {
      if (n.loading) seen.add(n.signedIn);
    });
    await ctl.loadUser();
    expect(seen, isNotEmpty);
    expect(seen.every((x) => x), true);
    expect(t.c.read(sessionProvider).signedIn, true);
  });
}

/// Fails every /user call as if offline while [down].
class FlakyAdapter extends FakeAdapter {
  bool down = true;
  FlakyAdapter(super.routes);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) {
    if (down && o.uri.path.startsWith('/api/user')) {
      seen.add(o);
      throw Exception('offline');
    }
    return super.fetch(o, s, c);
  }
}

void restoreTests() {
  test('while a saved token is restored the redirect stays on /splash', () async {
    final t = setup(userRoutes, token: 'SAVED');
    final targets = <String?>[];
    t.c.listen(sessionProvider, (_, n) {
      if (!n.signedIn) targets.add(sessionRedirect(n, '/splash'));
    });
    await t.c.read(sessionProvider.notifier).start();
    expect(targets, isNotEmpty);
    expect(targets.every((x) => x == null), true, reason: '$targets');
    expect(sessionRedirect(t.c.read(sessionProvider), '/splash'), '/t/0');
    // Not restoring and no token: sign-in.
    expect(sessionRedirect(SessionState(info: MobileInfo(id: 5, name: 'Shop')), '/splash'), '/sign-in');
  });

  testWidgets('an offline restore keeps the token and shows Retry, which signs in once back online', (tester) async {
    final adapter = FlakyAdapter({'GET /api/mobile/5': mobile, ...userRoutes});
    final config = AppConfig(appMetaId: 5, apiBase: 'https://h/api');
    final client = ApiClient(config, dio: Dio()..httpClientAdapter = adapter);
    final storage = MemoryStorage('SAVED');
    final c = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(config),
      apiClientProvider.overrideWithValue(client),
      tokenStorageProvider.overrideWithValue(storage),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SplashPage(),
      ),
    ));
    await tester.runAsync(() => c.read(sessionProvider.notifier).start());
    await tester.pumpAndSettle();
    final s = c.read(sessionProvider);
    expect(s.signedIn, false);
    expect(sessionRedirect(s, '/splash'), isNull);
    expect(storage.value, 'SAVED');
    expect(client.token, 'SAVED');
    expect(find.text(defaultUnreachableMessage), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    adapter.down = false;
    await tester.tap(find.text('Retry'));
    // Signed in, the splash spins until the router leaves it: pump instead of settling.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(c.read(sessionProvider).signedIn, true);
    expect(sessionRedirect(c.read(sessionProvider), '/splash'), '/t/0');
  });
  testWidgets("a restore that keeps failing offers Sign out, which leads to sign-in", (tester) async {
    final adapter = FlakyAdapter({"GET /api/mobile/5": mobile, "POST /api/logout": (200, <String, dynamic>{}), ...userRoutes});
    final config = AppConfig(appMetaId: 5, apiBase: "https://h/api");
    final client = ApiClient(config, dio: Dio()..httpClientAdapter = adapter);
    final storage = MemoryStorage("SAVED");
    final c = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(config),
      apiClientProvider.overrideWithValue(client),
      tokenStorageProvider.overrideWithValue(storage),
    ]);
    addTearDown(c.dispose);
    await tester.pumpWidget(UncontrolledProviderScope(
      container: c,
      child: const MaterialApp(
        localizationsDelegates: [AppLocalizations.delegate, GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SplashPage(),
      ),
    ));
    await tester.runAsync(() => c.read(sessionProvider.notifier).start());
    await tester.pumpAndSettle();
    expect(find.text("Sign out"), findsOneWidget);
    await tester.runAsync(() async {
      await tester.tap(find.text("Sign out"));
      await Future<void>.delayed(const Duration(milliseconds: 50));
    });
    // Signed out, the splash spins until the router moves on: pump instead of settling.
    await tester.pump(const Duration(milliseconds: 20));
    final s = c.read(sessionProvider);
    expect(storage.value, isNull);
    expect(client.token, isNull);
    expect(s.info, isNotNull);
    expect(sessionRedirect(s, "/splash"), "/sign-in");
  });

  test("start survives a token storage that throws", () async {
    final t = setup(userRoutes);
    final c = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(t.c.read(appConfigProvider)),
      apiClientProvider.overrideWithValue(t.c.read(apiClientProvider)),
      tokenStorageProvider.overrideWithValue(ThrowingStorage()),
    ]);
    addTearDown(c.dispose);
    await c.read(sessionProvider.notifier).start();
    final s = c.read(sessionProvider);
    expect(s.loading, false);
    expect(s.info, isNotNull);
    expect(sessionRedirect(s, "/splash"), "/sign-in");
  });
}

void googleTests() {
  const loginOk = (200, {
    'user': {'id': 1},
    'token': 'G1',
    'customers': [
      {'id': 7, 'code': 'acme', 'name': 'Acme', 'is_admin': false},
    ],
  });

  test('Google: opens the backend with the app link and a challenge, swaps the code with the secret', () async {
    late Uri opened;
    late String scheme;
    final t = setup({'POST /api/auth/google/exchange': loginOk, ...userRoutes}, webAuth: (url, s) async {
      opened = Uri.parse(url);
      scheme = s;
      return '$s://google-auth?google_code=abc';
    });
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.signInWithGoogle();

    expect(opened.toString(), startsWith('https://h/auth/google/redirect?'));
    expect(scheme, 'mn.shop-app', reason: 'a link scheme may not hold _');
    expect(opened.queryParameters['app'], 'mn.shop-app');
    final exchange = t.a.seen.firstWhere((r) => r.uri.path == '/api/auth/google/exchange');
    final body = (exchange.data is String ? jsonDecode(exchange.data as String) : exchange.data) as Map;
    expect(body['code'], 'abc');
    final challenge = base64UrlEncode(sha256.convert(utf8.encode(body['verifier'] as String)).bytes).replaceAll('=', '');
    expect(opened.queryParameters['challenge'], challenge);
    expect(t.s.value, 'G1');
    expect(t.c.read(sessionProvider).user?['name'], 'Bat');
  });

  test('Google: the backend\'s error is shown; closing the browser is not an error', () async {
    final t = setup({}, webAuth: (url, s) async => '$s://google-auth?google_error=Only+company.mn');
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.signInWithGoogle();
    expect(t.c.read(sessionProvider).error, 'Only company.mn');
    expect(t.s.value, isNull);

    final closed = setup({}, webAuth: (url, s) async => throw PlatformException(code: 'CANCELED'));
    final ctl2 = closed.c.read(sessionProvider.notifier);
    await ctl2.start();
    await ctl2.signInWithGoogle();
    expect(closed.c.read(sessionProvider).error, isNull);
    expect(closed.c.read(sessionProvider).loading, isFalse);
  });
}
