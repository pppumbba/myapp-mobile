import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/config.dart';

class FakeAdapter implements HttpClientAdapter {
  final List<RequestOptions> seen = [];
  final Future<ResponseBody> Function(RequestOptions) handler;
  FakeAdapter(this.handler);

  @override
  Future<ResponseBody> fetch(RequestOptions o, Stream<Uint8List>? s, Future<void>? c) {
    seen.add(o);
    return handler(o);
  }

  @override
  void close({bool force = false}) {}
}

ResponseBody jsonBody(int status, Object body) => ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );

ApiClient make(FakeAdapter a, {String? code}) {
  final dio = Dio()..httpClientAdapter = a;
  return ApiClient(AppConfig(appMetaId: 1, customerCode: code, apiBase: 'https://x.test/api'), dio: dio);
}

void main() {
  test('query encodes nested maps and skips empties', () {
    expect(encodeQuery({'filter': {'status': 'idle', 'x': ''}, 'search': 'pump', 'page': 2, 'n': null}),
        {'filter[status]': 'idle', 'search': 'pump', 'page': '2'});
  });

  test('sends bearer, accept and locale headers', () async {
    final a = FakeAdapter((_) async => jsonBody(200, {'ok': true}));
    final c = make(a)
      ..token = 'tok'
      ..locale = 'mn';
    await c.get<Map>('/metas/1', query: {
      'filter': {'a': 'b'}
    });
    final o = a.seen.single;
    expect(o.headers['Authorization'], 'Bearer tok');
    expect(o.headers['Accept-Language'], 'mn');
    expect(o.uri.path, '/api/metas/1');
    expect(o.uri.queryParameters, {'filter[a]': 'b'});
  });

  test('422 maps message and field errors', () async {
    final a = FakeAdapter((_) async => jsonBody(422, {
          'message': 'The title field is required.',
          'errors': {
            'title': ['The title field is required.']
          },
        }));
    final c = make(a);
    final err = await c.post<Map>('/metas/1/data', {}).then<ApiError>((_) => fail('no error'), onError: (e) => e as ApiError);
    expect(err.status, 422);
    expect(err.message, 'The title field is required.');
    expect(err.errors['title']!.first, 'The title field is required.');
  });

  test('apiClient on 401 calls onUnauthorized once', () async {
    final a = FakeAdapter((_) async => jsonBody(401, {'message': 'Unauthenticated.'}));
    var count = 0;
    final c = make(a)
      ..token = 't1'
      ..onUnauthorized = () => count++;
    await Future.wait([
      c.get<Map>('/a').catchError((_) => <dynamic, dynamic>{}),
      c.get<Map>('/b').catchError((_) => <dynamic, dynamic>{}),
    ]);
    expect(count, 1);
    c.token = 't2';
    await c.get<Map>('/a').catchError((_) => <dynamic, dynamic>{});
    expect(count, 2);
  });

  test('network error maps to ApiError status 0', () async {
    final a = FakeAdapter((o) async => throw DioException.connectionError(requestOptions: o, reason: 'down'));
    final c = make(a);
    final err = await c.get<Map>('/a').then<ApiError>((_) => fail('no error'), onError: (e) => e as ApiError);
    expect(err.status, 0);
    expect(err.message, startsWith('The server could not be reached'));
  });

  test('guest get adds /c/acme', () async {
    final a = FakeAdapter((_) async => jsonBody(200, {}));
    final c = make(a, code: 'acme');
    await c.get<Map>('/mobile/160', guest: true);
    await c.get<Map>('/metas/160');
    expect(a.seen[0].uri.path, '/api/c/acme/mobile/160');
    expect(a.seen[1].uri.path, '/api/metas/160');
  });
}
