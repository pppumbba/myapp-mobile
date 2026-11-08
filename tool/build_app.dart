// Builds the APK for one app meta.
//   dart run tool/build_app.dart --app <id> [--customer <code>] [--api <url>] [--release] [--no-build]
import 'dart:convert';
import 'dart:io';

const defaultApi = 'https://5-223-38-162.sslip.io/api';

Never fail(String message) {
  stderr.writeln(message);
  exit(1);
}

Future<void> main(List<String> args) async {
  String? app, customer;
  var api = defaultApi;
  var release = false, build = true;
  for (var i = 0; i < args.length; i++) {
    String value() => i + 1 < args.length ? args[++i] : fail('${args[i]} needs a value');
    switch (args[i]) {
      case '--app':
        app = value();
      case '--customer':
        customer = value();
      case '--api':
        api = value();
      case '--release':
        release = true;
      case '--no-build':
        build = false;
      default:
        fail('Unknown argument ${args[i]}');
    }
  }
  if (app == null || int.tryParse(app) == null) {
    fail('Usage: dart run tool/build_app.dart --app <id> [--customer <code>] [--api <url>] [--release] [--no-build]');
  }
  api = api.replaceFirst(RegExp(r'/+$'), '');
  final prefix = customer == null || customer.isEmpty ? '' : '/c/$customer';
  final url = Uri.parse('$api$prefix/mobile/$app');

  final client = HttpClient();
  late final int status;
  late final String body;
  try {
    final res = await (await client.getUrl(url)..headers.set('Accept', 'application/json')).close();
    status = res.statusCode;
    body = await res.transform(utf8.decoder).join();
  } catch (e) {
    fail('Could not reach $url: $e');
  } finally {
    client.close();
  }

  Map<String, dynamic> data = {};
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) data = decoded;
  } catch (_) {}
  if (status != 200) {
    fail('$url answered $status: ${data['message'] ?? body}');
  }
  final packageId = data['package_id'];
  if (packageId is! String || packageId.isEmpty) {
    fail('App $app has no package_id. Turn on Phone app and set a package id on the app meta.');
  }
  final name = (data['name'] ?? 'Wand').toString();
  final color = data['color'];
  final validColor = color is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(color);

  File('app.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
          'appId': packageId,
          'appName': name,
          'color': validColor ? color : '#4f46e5',
        })}\n',
  );
  stdout.writeln('Wrote app.json: $packageId / $name');

  final customerCode = (customer != null && customer.isNotEmpty)
      ? customer
      : (data['customer'] is Map ? data['customer']['code']?.toString() : null);

  final flutterArgs = [
    'build',
    'apk',
    release ? '--release' : '--debug',
    '--dart-define=APP_META_ID=$app',
    '--dart-define=API_BASE=$api',
    '--dart-define=APP_ID=$packageId',
    if (customerCode != null && customerCode.isNotEmpty) '--dart-define=CUSTOMER_CODE=$customerCode',
  ];
  if (!build) {
    stdout.writeln('--no-build: would run flutter ${flutterArgs.join(' ')}');
    return;
  }
  final process = await Process.start('flutter', flutterArgs,
      mode: ProcessStartMode.inheritStdio, runInShell: Platform.isWindows);
  exit(await process.exitCode);
}
