import 'dart:ui' as ui;

import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/client.dart';
import '../api/models.dart';
import '../config.dart';
import '../l10n/app_localizations.dart';

const defaultAppColor = Color(0xFF4F46E5);

/// Where the sign-in token is kept between launches.
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String token);
  Future<void> clear();
}

class SecureTokenStorage implements TokenStorage {
  static const key = 'auth_token';
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  @override
  Future<String?> read() async {
    try {
      return await _s.read(key: key);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(String token) async {
    try {
      await _s.write(key: key, value: token);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _s.delete(key: key);
    } catch (_) {}
  }
}

/// UI strings for places without a BuildContext, in the device language (English fallback).
AppLocalizations deviceStrings([String? userLocale]) {
  final code = userLocale ?? ui.PlatformDispatcher.instance.locale.languageCode;
  try {
    return lookupAppLocalizations(ui.Locale(code));
  } catch (_) {
    return lookupAppLocalizations(const ui.Locale('en'));
  }
}

final appConfigProvider = Provider<AppConfig>((ref) => AppConfig.fromEnvironment());
final tokenStorageProvider = Provider<TokenStorage>((ref) => SecureTokenStorage());
final apiClientProvider = Provider<ApiClient>(
  (ref) => ApiClient(
    ref.watch(appConfigProvider),
    unreachableMessage: deviceStrings().serverUnreachable,
  ),
);

class MobileInfo {
  final int id;
  final String name;
  final String? color;
  final String? customerCode;
  MobileInfo({required this.id, required this.name, this.color, this.customerCode});

  factory MobileInfo.fromJson(Map<String, dynamic> j) => MobileInfo(
        id: (j['id'] as num).toInt(),
        name: '${j['name'] ?? ''}',
        color: j['color'] as String?,
        customerCode: j['customer'] is Map ? (j['customer'] as Map)['code'] as String? : null,
      );

  /// The app colour as a seed, falling back to the default indigo.
  Color get seed {
    final m = RegExp(r'^#?([0-9a-fA-F]{6})$').firstMatch(color ?? '');
    return m == null ? defaultAppColor : Color(0xFF000000 | int.parse(m.group(1)!, radix: 16));
  }
}

class SessionState {
  final MobileInfo? info;
  final Map<String, dynamic>? user;
  final Access? access;
  final Map<String, dynamic> sessionValues;
  final bool loading;
  final String? error;

  /// A saved token is being restored (or its restore failed without a 401): the app stays on
  /// the splash, with Retry on an error, instead of showing sign-in.
  final bool restoring;

  const SessionState({
    this.info,
    this.user,
    this.access,
    this.sessionValues = const {},
    this.loading = false,
    this.error,
    this.restoring = false,
  });

  bool get signedIn => user != null;

  SessionState copyWith({bool? loading, String? error, bool clearError = false}) => SessionState(
        info: info,
        user: user,
        access: access,
        sessionValues: sessionValues,
        loading: loading ?? this.loading,
        error: clearError ? null : (error ?? this.error),
        restoring: restoring,
      );
}

class SessionController extends Notifier<SessionState> {
  late final ApiClient _client = ref.read(apiClientProvider);

  @override
  SessionState build() {
    _client.onUnauthorized = _expired;
    ref.onDispose(() => _client.onUnauthorized = null);
    return const SessionState();
  }

  TokenStorage get _storage => ref.read(tokenStorageProvider);

  SessionState _signedOut({String? error}) => SessionState(info: state.info, error: error);

  /// A 401 on a signed-in call: drop the token and go back to sign-in, no POST /logout.
  void _expired() {
    if (_client.token == null) return; // e.g. bad credentials on /login
    _client.token = null;
    _storage.clear();
    state = _signedOut();
  }

  /// Loads the app info and restores a saved token. Only a 401 (or no token) leads to sign-in;
  /// a restore that fails otherwise (offline, 5xx) keeps the token and stays on the splash with
  /// Retry, which calls [start] again.
  Future<void> start() async {
    final saved = await _storage.read();
    final hasToken = saved != null && saved.isNotEmpty;
    state = SessionState(loading: true, info: state.info, restoring: hasToken);
    try {
      final j = await _client.get<Map<String, dynamic>>('/mobile/${ref.read(appConfigProvider).appMetaId}', guest: true);
      final info = MobileInfo.fromJson(j);
      if (hasToken) {
        state = SessionState(loading: true, info: info, restoring: true);
        _client.token = saved;
        await loadUser();
      } else {
        state = SessionState(info: info);
      }
    } on ApiError catch (e) {
      state = SessionState(error: e.message, restoring: hasToken);
    } catch (_) {
      _client.token = null;
      state = SessionState(info: state.info, error: deviceStrings().somethingWrong, restoring: hasToken);
    }
  }

  Future<void> signIn(String email, String password) async {
    final info = state.info;
    state = SessionState(loading: true, info: info);
    try {
      final j = await _client.post<Map<String, dynamic>>('/login', {'email': email, 'password': password});
      var token = j['token'] as String;
      final customers = (j['customers'] as List? ?? const []).whereType<Map>().toList();
      final code = ref.read(appConfigProvider).customerCode ?? info?.customerCode;
      if (customers.length == 1 && code != null && customers.first['code'] != code) {
        // Another organization's token: not this app's tenant. Drop it.
        _client.token = token;
        try {
          await _client.post<dynamic>('/logout', null);
        } catch (_) {}
        _client.token = null;
        state = SessionState(info: info, error: deviceStrings().noAccessToCustomer);
        return;
      }
      if (customers.length != 1) {
        final match = customers.where((c) => c['code'] == code).firstOrNull;
        if (match == null) {
          // The token from /login is not bound to any customer, so it is not kept.
          state = SessionState(info: info, error: deviceStrings().noAccessToCustomer);
          return;
        }
        _client.token = token;
        try {
          final u = await _client.post<Map<String, dynamic>>('/customers/${match['id']}/use', null);
          token = u['token'] as String;
        } catch (_) {
          _client.token = null;
          rethrow;
        }
      }
      _client.token = token;
      await _storage.write(token);
      await loadUser();
    } on ApiError catch (e) {
      _client.token = null;
      state = SessionState(info: info, error: e.message);
    } catch (_) {
      _client.token = null;
      state = SessionState(info: info, error: deviceStrings().somethingWrong);
    }
  }

  Future<void> loadUser() async {
    final info = state.info;
    state = state.copyWith(loading: true, clearError: true);
    try {
      final r = await Future.wait<dynamic>([
        _client.get<dynamic>('/user'),
        _client.get<dynamic>('/user/access'),
        _client.get<dynamic>('/user/session'),
      ]);
      final user = Map<String, dynamic>.from(r[0] as Map);
      final loc = user['locale'];
      _client.locale = loc is String && loc.isNotEmpty ? loc : null;
      final values = r[2];
      state = SessionState(
        info: info,
        user: user,
        access: Access.fromJson(Map<String, dynamic>.from(r[1] as Map)),
        sessionValues: values is Map ? Map<String, dynamic>.from(values) : const {},
      );
    } on ApiError catch (e) {
      if (e.status == 401) {
        _client.token = null;
        await _storage.clear();
        state = SessionState(info: info);
      } else {
        state = state.copyWith(loading: false, error: e.message);
      }
    } catch (_) {
      state = state.copyWith(loading: false, error: deviceStrings().somethingWrong);
    }
  }

  Future<void> signOut() async {
    try {
      await _client.post<dynamic>('/logout', null);
    } catch (_) {
      // Signing out locally matters more than the server being reachable.
    }
    _client.token = null;
    _client.locale = null;
    await _storage.clear();
    state = SessionState(info: state.info);
  }

  bool can(int? metaId, String ability) => state.access?.can(metaId, ability) ?? false;

  String? sessionValue(String path) {
    final v = state.sessionValues[path];
    return v == null ? null : '$v';
  }
}

final sessionProvider = NotifierProvider<SessionController, SessionState>(SessionController.new);
