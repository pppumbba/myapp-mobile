import 'dart:convert';

import 'package:dio/dio.dart';

import '../config.dart';

const defaultUnreachableMessage = 'The server could not be reached. Check your connection and try again.';

class ApiError implements Exception {
  final int status;
  final String message;
  final Map<String, List<String>> errors;
  ApiError(this.status, this.message, [this.errors = const {}]);

  @override
  String toString() => 'ApiError($status): $message';
}

/// Port of dataApi.ts queryString: nested maps become `k[name]`, null and '' are skipped.
Map<String, String> encodeQuery(Map<String, dynamic>? q) {
  final out = <String, String>{};
  if (q == null) return out;
  q.forEach((k, v) {
    if (v == null) return;
    if (v is Map) {
      v.forEach((name, value) {
        if (value != null && value != '') out['$k[$name]'] = '$value';
      });
    } else if (v != '' || k == 'parent') {
      out[k] = '$v';
    }
  });
  return out;
}

class ApiClient {
  final AppConfig config;
  final Dio dio;
  final String unreachableMessage;
  String? _token;
  String? locale;
  void Function()? onUnauthorized;
  bool _firedForToken = false;

  ApiClient(this.config, {Dio? dio, this.unreachableMessage = defaultUnreachableMessage})
      : dio = dio ?? Dio() {
    this.dio.options
      ..baseUrl = config.apiBase
      ..connectTimeout = const Duration(seconds: 15)
      ..receiveTimeout = const Duration(seconds: 30)
      ..validateStatus = (s) => s != null && s >= 200 && s < 300;
  }

  String? get token => _token;
  set token(String? value) {
    if (value != _token) _firedForToken = false;
    _token = value;
  }

  Options _options() => Options(headers: {
        'Accept': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
        if (locale != null) 'Accept-Language': locale,
      });

  Future<T> _send<T>(String method, String path, {Object? body, Map<String, dynamic>? query}) async {
    try {
      final res = await dio.request<dynamic>(
        path,
        data: body,
        queryParameters: query == null ? null : encodeQuery(query),
        options: _options()..method = method,
      );
      return res.data as T;
    } on DioException catch (e) {
      throw _toError(e);
    }
  }

  ApiError _toError(DioException e) {
    final res = e.response;
    if (res == null) return ApiError(0, unreachableMessage);
    final status = res.statusCode ?? 0;
    if (status == 401 && !_firedForToken) {
      _firedForToken = true;
      onUnauthorized?.call();
    }
    var data = res.data;
    if (data is String && data.isNotEmpty) {
      try {
        data = jsonDecode(data);
      } catch (_) {}
    }
    var message = 'Request failed ($status)';
    final errors = <String, List<String>>{};
    if (data is Map) {
      if (data['message'] is String && (data['message'] as String).isNotEmpty) {
        message = data['message'] as String;
      }
      final errs = data['errors'];
      if (errs is Map) {
        errs.forEach((k, v) {
          errors['$k'] = v is List ? v.map((x) => '$x').toList() : ['$v'];
        });
      }
    }
    return ApiError(status, message, errors);
  }

  Future<T> get<T>(String path, {Map<String, dynamic>? query, bool guest = false}) {
    final prefix = guest && config.customerCode != null ? '/c/${config.customerCode}' : '';
    return _send<T>('GET', '$prefix$path', query: query);
  }

  Future<T> post<T>(String path, Object? body) => _send<T>('POST', path, body: body);
  Future<T> put<T>(String path, Object? body) => _send<T>('PUT', path, body: body);
  Future<void> delete(String path) => _send<dynamic>('DELETE', path);
}
