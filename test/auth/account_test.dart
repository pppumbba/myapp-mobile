import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/auth/session.dart';

import 'session_test.dart' show setup, userRoutes;

Map<String, dynamic> _body(Object? data) => data is String ? jsonDecode(data) as Map<String, dynamic> : Map<String, dynamic>.from(data as Map);

/// The user as /user answers it: with the customer it works in and the theme it picked there.
const _user = (200, {
  'id': 1,
  'name': 'Bat',
  'email': 'b@x.mn',
  'locale': 'mn',
  'theme_mode': null,
  'theme_meta_id': 44,
  'customer': {'id': 7, 'code': 'acme', 'name': 'Acme'},
  'customers': [
    {'id': 7, 'code': 'acme', 'name': 'Acme', 'is_admin': true},
    {'id': 8, 'code': 'beta', 'name': 'Beta', 'is_admin': false},
  ],
});

void main() {
  test('setThemeMode shows the mode at once and sends the theme meta along unchanged', () async {
    final t = setup({...userRoutes, 'GET /api/user': _user, 'PUT /api/user/theme': (200, {'theme_mode': 'dark'})}, token: 'T');
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.setThemeMode('dark');
    expect(t.c.read(sessionProvider).user?['theme_mode'], 'dark');
    final put = t.a.seen.lastWhere((r) => r.uri.path == '/api/user/theme');
    expect(_body(put.data), {'mode': 'dark', 'theme_meta_id': 44});
  });

  test('setThemeMode puts the old mode back when the save fails', () async {
    final t = setup({...userRoutes, 'GET /api/user': _user, 'PUT /api/user/theme': (500, {'message': 'down'})}, token: 'T');
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await expectLater(ctl.setThemeMode('light'), throwsA(isA<ApiError>()));
    expect(t.c.read(sessionProvider).user?['theme_mode'], isNull);
  });

  test('setLocale switches the API language and the session scope; the customer stays', () async {
    final t = setup({
      ...userRoutes,
      'GET /api/user': _user,
      'PUT /api/user/locale': (200, {'id': 1, 'name': 'Bat', 'email': 'b@x.mn', 'locale': 'en'}),
    }, token: 'T');
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    final before = t.c.read(sessionScopeProvider);
    await ctl.setLocale('en');
    expect(t.client.locale, 'en');
    expect(t.c.read(sessionProvider).user?['locale'], 'en');
    expect((t.c.read(sessionProvider).user?['customer'] as Map)['id'], 7);
    expect(t.c.read(sessionScopeProvider), isNot(before));
  });

  test('updateProfile keeps the customer list the answer leaves out', () async {
    final t = setup({
      ...userRoutes,
      'GET /api/user': _user,
      'PUT /api/user': (200, {'id': 1, 'name': 'Dorj', 'email': 'd@x.mn'}),
    }, token: 'T');
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    await ctl.updateProfile('Dorj', 'd@x.mn');
    final user = t.c.read(sessionProvider).user!;
    expect(user['name'], 'Dorj');
    expect((user['customers'] as List).length, 2);
  });

  test('switchCustomer keeps the new bound token and loads the user again', () async {
    final t = setup({
      ...userRoutes,
      'GET /api/user': _user,
      'POST /api/customers/8/use': (200, {'customer': {'id': 8, 'code': 'beta', 'name': 'Beta'}, 'token': 'T8'}),
    }, token: 'T');
    final ctl = t.c.read(sessionProvider.notifier);
    await ctl.start();
    final loads = t.a.seen.where((r) => r.uri.path == '/api/user').length;
    await ctl.switchCustomer(8);
    expect(t.client.token, 'T8');
    expect(t.s.value, 'T8');
    expect(t.a.seen.where((r) => r.uri.path == '/api/user').length, loads + 1);
    expect(t.a.seen.last.headers['Authorization'], 'Bearer T8');
  });
}
