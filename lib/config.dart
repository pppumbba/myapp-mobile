/// Build-time settings, passed by `tool/build_app.dart` as --dart-define values.
class AppConfig {
  final int appMetaId;
  final String? customerCode;
  final String apiBase;

  AppConfig({required this.appMetaId, String? customerCode, required String apiBase})
      : customerCode = (customerCode == null || customerCode.isEmpty) ? null : customerCode,
        apiBase = apiBase.replaceFirst(RegExp(r'/+$'), '');

  static AppConfig fromEnvironment() => AppConfig(
        appMetaId: const int.fromEnvironment('APP_META_ID'),
        customerCode: const String.fromEnvironment('CUSTOMER_CODE'),
        apiBase: const String.fromEnvironment(
          'API_BASE',
          defaultValue: 'https://5-223-38-162.sslip.io/api',
        ),
      );
}
