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
  String get somethingWrong => 'Алдаа гарлаа. Дахин оролдоно уу.';

  @override
  String get noAccessToCustomer =>
      'Таны бүртгэл энэ аппын байгууллагад эрхгүй байна.';

  @override
  String get more => 'Бусад';

  @override
  String get yes => 'Тийм';

  @override
  String get no => 'Үгүй';

  @override
  String get active => 'Идэвхтэй';

  @override
  String get inactive => 'Идэвхгүй';

  @override
  String get account => 'Бүртгэл';

  @override
  String get organization => 'Байгууллага';

  @override
  String get openOnWebTitle => 'Вэбээр нээх';

  @override
  String get openOnWebBody =>
      'Энэ дэлгэц аппад хараахан ороогүй байна. Вэбээр нээнэ үү.';

  @override
  String get comingSoon => 'Удахгүй';

  @override
  String get noScreens => 'Энэ аппад харуулах зүйл одоохондоо алга.';

  @override
  String welcome(String name) {
    return '$name нэрээр нэвтэрсэн';
  }

  @override
  String get search => 'Хайх';

  @override
  String get noResults => 'Илэрц олдсонгүй';
}
