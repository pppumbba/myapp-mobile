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

  final hasIcon = await writeIcon(data['icon'], Uri.parse('$api$prefix/mobile/$app/icon'), validColor ? color : '#4f46e5');

  File('app.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({
          'appId': packageId,
          'appName': name,
          'color': validColor ? color : '#4f46e5',
          'icon': hasIcon,
        })}\n',
  );
  stdout.writeln('Wrote app.json: $packageId / $name${hasIcon ? ' (own icon)' : ''}');

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

/// Where the app's own launcher icon resources go; android/app/build.gradle.kts adds it as a
/// resource folder and points the manifest at @mipmap/ic_app when app.json says "icon": true.
const iconRes = 'build/app_icon/res';

/// The in-app mark (AppMark): the same picture, bundled as an asset.
const iconAsset = 'assets/app/icon.png';

/// Fetches the app meta's icon ([file] is its name from GET /mobile/{id}; null: none) and writes
/// the launcher icon: an adaptive icon whose picture fills the part every phone shape shows, on
/// [color], and the picture itself for phones older than Android 8. True when it was written.
Future<bool> writeIcon(Object? file, Uri url, String color) async {
  final res = Directory(iconRes);
  if (res.existsSync()) res.deleteSync(recursive: true);
  final asset = File(iconAsset);
  if (asset.existsSync()) asset.deleteSync();
  if (file is! String || file.isEmpty) return false;

  final client = HttpClient();
  List<int> bytes;
  try {
    final r = await (await client.getUrl(url)).close();
    if (r.statusCode != 200) fail('$url answered ${r.statusCode}: the app\'s icon could not be fetched.');
    bytes = [for (final chunk in await r.toList()) ...chunk];
  } catch (e) {
    fail('Could not fetch the app\'s icon from $url: $e');
  } finally {
    client.close();
  }
  final ext = file.split('.').last; // png, jpg or webp: Android and Flutter read each

  void write(String path, Object content) {
    final f = File('$iconRes/$path')..parent.createSync(recursive: true);
    content is String ? f.writeAsStringSync(content) : f.writeAsBytesSync(content as List<int>);
  }

  write('drawable-nodpi/ic_app_image.$ext', bytes);
  write('mipmap-nodpi/ic_app.$ext', bytes);
  write('values/ic_app.xml', '<?xml version="1.0" encoding="utf-8"?>\n<resources>\n    <color name="ic_app_background">$color</color>\n</resources>\n');
  // Phones mask the outer 18 of the icon's 108 dp on each side; inset by that, the picture fills
  // what every shape (circle, squircle, rounded square) can show.
  write('mipmap-anydpi-v26/ic_app.xml', '''
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@color/ic_app_background"/>
    <foreground>
        <inset android:drawable="@drawable/ic_app_image" android:inset="16.7%"/>
    </foreground>
</adaptive-icon>
''');
  File(iconAsset)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes);
  return true;
}
