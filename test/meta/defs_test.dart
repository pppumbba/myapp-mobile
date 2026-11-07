import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/auth/session.dart';
import 'package:wand_mobile/config.dart';
import 'package:wand_mobile/meta/defs.dart';

class CountingAdapter implements HttpClientAdapter {
  final List<RequestOptions> seen = [];
  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) async {
    seen.add(o);
    final path = o.uri.path;
    Object body;
    if (path == '/api/metas/7') {
      body = {'id': 7, 'name': 'Orders', 'type': 'datagrid'};
    } else if (path == '/api/metas/7/params') {
      body = [
        {'id': 1, 'param_name': 'a', 'children': []},
      ];
    } else if (path == '/api/metas/7/actions') {
      body = [
        {'id': 2, 'action': 'add'},
      ];
    } else {
      body = {'message': 'nope'};
    }
    return ResponseBody.fromString(jsonEncode(body), path.startsWith('/api/metas/7') ? 200 : 404, headers: {
      Headers.contentTypeHeader: ['application/json'],
    });
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  late CountingAdapter adapter;
  late ProviderContainer c;
  setUp(() {
    adapter = CountingAdapter();
    final config = AppConfig(appMetaId: 5, apiBase: 'https://h/api');
    final client = ApiClient(config, dio: Dio()..httpClientAdapter = adapter);
    c = ProviderContainer(overrides: [
      appConfigProvider.overrideWithValue(config),
      apiClientProvider.overrideWithValue(client),
    ]);
    addTearDown(c.dispose);
  });

  test('metaDefProvider fetches meta and params once for two reads', () async {
    final a = await c.read(metaDefProvider(7).future);
    final b = await c.read(metaDefProvider(7).future);
    expect(a.meta.type, 'datagrid');
    expect(b.params.single.paramName, 'a');
    expect(adapter.seen.length, 2);
    expect(adapter.seen.map((o) => o.uri.path).toSet(), {'/api/metas/7', '/api/metas/7/params'});
    final first = adapter.seen.firstWhere((o) => o.uri.path == '/api/metas/7');
    expect(first.uri.queryParameters, {'translated': '1'});
    final params = adapter.seen.firstWhere((o) => o.uri.path == '/api/metas/7/params');
    expect(params.uri.queryParameters, {'effective': '1', 'translated': '1'});
  });

  test('metaTypeProvider reads the type through the cached definition', () async {
    expect(await c.read(metaTypeProvider(7).future), 'datagrid');
    await c.read(metaDefProvider(7).future);
    expect(adapter.seen.length, 2);
  });

  test('metaTypeProvider is null when the meta cannot be loaded', () async {
    expect(await c.read(metaTypeProvider(99).future), isNull);
  });

  test('actionsProvider loads effective translated actions', () async {
    final a = await c.read(actionsProvider(7).future);
    expect(a.single.action, 'add');
    expect(adapter.seen.single.uri.queryParameters, {'effective': '1', 'translated': '1'});
  });
}
