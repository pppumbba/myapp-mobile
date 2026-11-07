import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/config.dart';

void main() {
  test('apiBase has no trailing slash and empty customer is null', () {
    final c = AppConfig(appMetaId: 160, customerCode: '', apiBase: 'http://x/api/');
    expect(c.apiBase, 'http://x/api');
    expect(c.customerCode, isNull);
  });

  test('keeps a customer code and strips several trailing slashes', () {
    final c = AppConfig(appMetaId: 1, customerCode: 'acme', apiBase: 'http://x/api//');
    expect(c.apiBase, 'http://x/api');
    expect(c.customerCode, 'acme');
  });
}
