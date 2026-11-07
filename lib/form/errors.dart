import '../api/client.dart';

/// A failed save, split into messages under fields and a banner at the top of the form.
class FieldErrors {
  final String? banner;
  final Map<String, String> byField;
  const FieldErrors({this.banner, this.byField = const {}});

  bool get isEmpty => banner == null && byField.isEmpty;
}

/// Keys in [fieldsOnScreen] go under their field (first message). The first message of every other
/// key (lines like `lines.0.qty`, unknown keys) goes to the banner; when nothing would show
/// otherwise the banner is [ApiError.message].
FieldErrors mapErrors(ApiError e, Set<String> fieldsOnScreen) {
  final byField = <String, String>{};
  final rest = <String>[];
  e.errors.forEach((key, messages) {
    if (messages.isEmpty) return;
    if (fieldsOnScreen.contains(key)) {
      byField[key] = messages.first;
    } else {
      rest.add(messages.first);
    }
  });
  final banner = rest.isNotEmpty ? rest.join('\n') : (byField.isEmpty && e.message.isNotEmpty ? e.message : null);
  return FieldErrors(banner: banner, byField: byField);
}
