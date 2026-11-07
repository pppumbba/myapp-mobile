import 'package:flutter_test/flutter_test.dart';
import 'package:wand_mobile/api/client.dart';
import 'package:wand_mobile/form/errors.dart';

void main() {
  test('mapErrors puts unknown and line keys in the banner', () {
    final e = ApiError(422, 'The title field is required. (and 2 more errors)', {
      'title': ['The title field is required.', 'Second'],
      'lines.0.qty': ['The qty of line 1 is required.'],
      'zzz': ['Something else.'],
    });
    final m = mapErrors(e, {'title', 'asset_id'});
    expect(m.byField, {'title': 'The title field is required.'});
    expect(m.banner, contains('The qty of line 1 is required.'));
    expect(m.banner, contains('Something else.'));
    expect(m.banner, isNot(contains('Second')));
  });

  test('mapErrors with all keys on screen has no banner', () {
    final m = mapErrors(ApiError(422, 'The title field is required.', {'title': ['The title field is required.']}), {'title'});
    expect(m.banner, isNull);
    expect(m.byField, {'title': 'The title field is required.'});
  });

  test('mapErrors without field errors shows the message', () {
    final m = mapErrors(ApiError(500, 'Server error'), {'title'});
    expect(m.banner, 'Server error');
    expect(m.byField, isEmpty);
  });
}
