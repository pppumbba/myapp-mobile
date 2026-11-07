// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Mongolian (`mn`).
class AppLocalizationsMn extends AppLocalizations {
  AppLocalizationsMn([String locale = 'mn']) : super(locale);

  @override
  String get signIn => 'Нэвтрэх';

  @override
  String get email => 'Имэйл';

  @override
  String get password => 'Нууц үг';

  @override
  String get signOut => 'Гарах';

  @override
  String get retry => 'Дахин оролдох';

  @override
  String get fieldRequired => 'Энэ талбарыг бөглөнө үү';

  @override
  String get serverUnreachable =>
      'Сервертэй холбогдож чадсангүй. Холболтоо шалгаад дахин оролдоно уу.';

  @override
  String get noAccessToCustomer =>
      'Таны бүртгэл энэ аппын байгууллагад эрхгүй байна.';

  @override
  String welcome(String name) {
    return '$name нэрээр нэвтэрсэн';
  }
}
