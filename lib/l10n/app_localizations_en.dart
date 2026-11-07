// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get signIn => 'Sign in';

  @override
  String get email => 'Email';

  @override
  String get password => 'Password';

  @override
  String get signOut => 'Sign out';

  @override
  String get retry => 'Retry';

  @override
  String get fieldRequired => 'This field is required';

  @override
  String get serverUnreachable =>
      'The server could not be reached. Check your connection and try again.';

  @override
  String get somethingWrong => 'Something went wrong. Try again.';

  @override
  String get noAccessToCustomer =>
      'Your account does not have access to this app\'s organization.';

  @override
  String welcome(String name) {
    return 'Signed in as $name';
  }
}
