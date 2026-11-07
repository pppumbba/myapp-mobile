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

  @override
  String get save => 'Хадгалах';

  @override
  String get saveAndAdd => 'Хадгалаад шинийг нэмэх';

  @override
  String get next => 'Дараах';

  @override
  String get back => 'Өмнөх';

  @override
  String get general => 'Ерөнхий';

  @override
  String get saved => 'Хадгаллаа';

  @override
  String get fillRequired => 'Заавал бөглөх талбаруудыг бөглөнө үү.';

  @override
  String get fillBeforeNext => 'Үргэлжлүүлэхийн өмнө үүнийг бөглөнө үү.';

  @override
  String get autonumberNext => 'Хадгалах үед олгоно: энэ бол дараагийн дугаар.';

  @override
  String get autonumberExisting => 'Нэмэх үед дугаарласан.';

  @override
  String get clear => 'Арилгах';

  @override
  String stepOf(int step, int total) {
    return '$total алхмын $step-р алхам';
  }

  @override
  String get filter => 'Шүүлтүүр';

  @override
  String get apply => 'Хэрэглэх';

  @override
  String get add => 'Нэмэх';

  @override
  String get actions => 'Үйлдлүүд';

  @override
  String get cancel => 'Болих';

  @override
  String get close => 'Хаах';

  @override
  String get delete => 'Устгах';

  @override
  String get deleteConfirm => 'Устгах уу?';

  @override
  String get check => 'Шалгах';

  @override
  String get run => 'Ажиллуулах';

  @override
  String filterFirst(String labels) {
    return 'Эхлээд шүүлтүүр сонгоно уу: $labels';
  }

  @override
  String get stageNothing => 'Өөрчлөх зүйл алга: тохирох мөр олдсонгүй.';

  @override
  String stageWillChange(int n) {
    return '$n мөр өөрчлөгдөнө. Ажиллуулах уу?';
  }

  @override
  String stageDone(int n) {
    return 'Боллоо: $n мөр өөрчлөгдлөө.';
  }

  @override
  String get stageFailed => 'Асуулгыг ажиллуулж чадсангүй.';
}
