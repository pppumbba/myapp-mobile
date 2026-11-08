/// Build-time settings, passed by `tool/build_app.dart` as --dart-define values.
class AppConfig {
  final int appMetaId;
  final String? customerCode;
  final String apiBase;

  /// The Android package id; empty in tests and plain `flutter run`, where Google sign-in is hidden.
  final String appId;

  AppConfig({required this.appMetaId, String? customerCode, required String apiBase, this.appId = ''})
      : customerCode = (customerCode == null || customerCode.isEmpty) ? null : customerCode,
        apiBase = apiBase.replaceFirst(RegExp(r'/+$'), '');

  /// The link the backend sends the browser back to (a scheme may not hold _, so - stands in).
  String get authScheme => appId.replaceAll('_', '-');

  /// The backend's own address, for its web routes (Google sign-in).
  String get webBase => apiBase.replaceFirst(RegExp(r'/api$'), '');

  static AppConfig fromEnvironment() => AppConfig(
        appMetaId: const int.fromEnvironment('APP_META_ID'),
        customerCode: const String.fromEnvironment('CUSTOMER_CODE'),
        appId: const String.fromEnvironment('APP_ID'),
        apiBase: const String.fromEnvironment(
          'API_BASE',
          defaultValue: 'https://5-223-38-162.sslip.io/api',
        ),
      );
}
