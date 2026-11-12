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
  String get deleteConfirm => 'Энэ бичлэгийг устгах уу?';

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

  @override
  String get fixErrors => 'Тэмдэглэсэн талбаруудыг шалгана уу.';

  @override
  String get notifications => 'Мэдэгдэл';

  @override
  String get noNotifications => 'Мэдэгдэл алга.';

  @override
  String get markAllRead => 'Бүгдийг уншсан';

  @override
  String get searchMenus => 'Цэс хайх';

  @override
  String get noMenuMatch => 'Тохирох цэс алга.';

  @override
  String get welcomeBack => 'Тавтай морил';

  @override
  String get signInToContinue => 'Үргэлжлүүлэхийн тулд нэвтэрнэ үү';

  @override
  String get or => 'эсвэл';

  @override
  String get continueWithGoogle => 'Google-ээр нэвтрэх';

  @override
  String get showPassword => 'Нууц үг харуулах';

  @override
  String get hidePassword => 'Нууц үг нуух';

  @override
  String get noData => 'Өгөгдөл алга.';

  @override
  String get deleteForGood => 'Бүрмөсөн устгагдана.';

  @override
  String get justNow => 'одоо';

  @override
  String get today => 'Өнөөдөр';

  @override
  String get now => 'Одоо';

  @override
  String get tomorrow => 'Маргааш';

  @override
  String get yesterday => 'Өчигдөр';

  @override
  String inDays(int count) {
    return '$count хоногийн дараа';
  }

  @override
  String daysAgo(int count) {
    return '$count хоногийн өмнө';
  }

  @override
  String get personalInfo => 'Хувийн мэдээлэл';

  @override
  String get personalInfoNote =>
      'Апп дотор та хэрхэн харагдах, нэвтэрдэг и-мэйл.';

  @override
  String get name => 'Нэр';

  @override
  String get saveChanges => 'Өөрчлөлтийг хадгалах';

  @override
  String get appearance => 'Харагдах байдал';

  @override
  String get themeSystem => 'Систем';

  @override
  String get themeLight => 'Цайвар';

  @override
  String get themeDark => 'Бараан';

  @override
  String get language => 'Хэл';

  @override
  String get languageNote =>
      'Дэлгэцийн нэр, талбарын нэр, товч, төлвүүдийн хэл (орчуулагдсан бол).';

  @override
  String get languageAsPhone => 'Утасныхаараа';

  @override
  String get customers => 'Харилцагчид';

  @override
  String get customersNote =>
      'Таны ажилладаг компаниуд. Тус бүр өөрийн апп, хүмүүс, өгөгдөлтэй.';

  @override
  String get openNow => 'Одоо нээлттэй';

  @override
  String get admin => 'Админ';

  @override
  String get currentPassword => 'Одоогийн нууц үг';

  @override
  String get newPassword => 'Шинэ нууц үг';

  @override
  String get confirmPassword => 'Шинэ нууц үгээ давтах';

  @override
  String get passwordHint => 'Дор хаяж 8 тэмдэгт.';

  @override
  String get passwordsDontMatch => 'Нууц үгнүүд таарахгүй байна.';

  @override
  String get changePassword => 'Нууц үг солих';

  @override
  String get passwordChanged => 'Нууц үг солигдлоо';

  @override
  String get passwordNote =>
      'Солих нь бусад бүх газраас таныг гаргана; энд нэвтэрсэн хэвээр үлдэнэ.';

  @override
  String get choose => 'Сонгох';

  @override
  String get edit => 'Засах';

  @override
  String get addLine => 'Мөр нэмэх';

  @override
  String get noLines => 'Мөр алга';

  @override
  String get total => 'Нийт';

  @override
  String get removeLine => 'Энэ мөрийг устгах уу?';

  @override
  String newLine(String name) {
    return 'Шинэ: $name';
  }

  @override
  String get done => 'Болсон';

  @override
  String addPicked(int count) {
    return '$count нэмэх';
  }

  @override
  String pickToWorkOn(String name) {
    return 'Ажиллах $name сонгоно уу';
  }

  @override
  String get recordNotLoaded => 'Энэ бичлэгийг ачаалж чадсангүй.';

  @override
  String get workspaceNoSections => 'Энэ ажлын талбарт хэсэг алга.';

  @override
  String get workspaceNeedsForm =>
      'Энэ ажлын талбарт бичлэгийн маягт хэрэгтэй.';

  @override
  String get fieldEnter => 'Оруулах';

  @override
  String get inbox => 'Ирсэн';

  @override
  String get chats => 'Чат';

  @override
  String get newChat => 'Шинэ чат';

  @override
  String get noChats => 'Чат алга. + дарж эхлүүлнэ үү.';

  @override
  String get messageHint => 'Зурвас';

  @override
  String get seen => 'Үзсэн';

  @override
  String get typingNow => 'бичиж байна…';

  @override
  String get you => 'Та';

  @override
  String get findPeople => 'Хүн хайх';

  @override
  String get sendFailed => 'Илгээж чадсангүй. Дахин оролдоно уу.';

  @override
  String get send => 'Илгээх';

  @override
  String get delivered => 'Хүргэсэн';

  @override
  String get noPeople => 'Өөр хүн алга байна.';

  @override
  String get noConnection => 'Холболт алга';

  @override
  String get couldNotLoad => 'Ачаалж чадсангүй';

  @override
  String get addFile => 'Нэмэх';

  @override
  String get replaceFile => 'Солих';

  @override
  String get removeFile => 'Файл хасах';

  @override
  String get noFiles => 'Файл алга';

  @override
  String get takePhoto => 'Зураг авах';

  @override
  String get photoLibrary => 'Зургийн сан';

  @override
  String get browseFiles => 'Файл сонгох';

  @override
  String upTo(String size) {
    return '$size хүртэл';
  }

  @override
  String fileTypeNotAllowed(String name, String types) {
    return '$name-г энд нэмэх боломжгүй. Зөвшөөрөгдсөн: $types';
  }

  @override
  String fileTooBig(String name, String size) {
    return '$name хэт том байна. Дээд хэмжээ $size.';
  }

  @override
  String fileLimit(int count) {
    return 'Энэ талбарт хамгийн ихдээ $count файл нэмнэ.';
  }

  @override
  String get couldNotPick =>
      'Файлыг авч чадсангүй. Аппын зураг, файлын зөвшөөрлийг шалгана уу.';

  @override
  String get noAppToOpen => 'Энэ төрлийн файлыг нээх апп утсанд алга.';

  @override
  String get filesUploading => 'Файлууд хуулагдаж дуустал хүлээнэ үү.';

  @override
  String get shareToChat => 'Чатад хуваалцах';

  @override
  String get addNote => 'Тайлбар нэмэх (заавал биш)';

  @override
  String get people => 'Хүмүүс';

  @override
  String sharedWith(String name) {
    return '$name-д илгээлээ';
  }

  @override
  String noPeopleFound(String query) {
    return '“$query” гэх хүн олдсонгүй.';
  }

  @override
  String get dragPickHint =>
      'Зөвлөмж: картыг удаан дараад гулсуулж олныг сонгоно';

  @override
  String get noMatchesHint => 'Хайлт, шүүлтүүрт тохирох зүйл алга.';

  @override
  String get clearSearch => 'Хайлт, шүүлтүүр арилгах';

  @override
  String get sortBy => 'Эрэмбэлэх';

  @override
  String get sortOrder => 'Дараалал';

  @override
  String get ascending => 'Өсөхөөр';

  @override
  String get descending => 'Буурахаар';

  @override
  String get nothingYet => 'Одоогоор хоосон байна';

  @override
  String get nothingYetAdd => 'Эхнийхийг нэмэхийн тулд + дарна уу.';

  @override
  String get nothingYetHint => 'Бичлэг нэмэгдмэгц энд харагдана.';
}
