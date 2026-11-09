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
  String get more => 'More';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get account => 'Account';

  @override
  String get organization => 'Organization';

  @override
  String get openOnWebTitle => 'Open on the web';

  @override
  String get openOnWebBody =>
      'This screen is not available in the app yet. Open it on the web.';

  @override
  String get comingSoon => 'Coming soon';

  @override
  String get noScreens => 'There is nothing to show in this app yet.';

  @override
  String welcome(String name) {
    return 'Signed in as $name';
  }

  @override
  String get search => 'Search';

  @override
  String get noResults => 'No results';

  @override
  String get save => 'Save';

  @override
  String get saveAndAdd => 'Save and add';

  @override
  String get next => 'Next';

  @override
  String get back => 'Back';

  @override
  String get general => 'General';

  @override
  String get saved => 'Saved';

  @override
  String get fillRequired => 'Fill in the required fields.';

  @override
  String get fillBeforeNext => 'Fill this in before going on.';

  @override
  String get autonumberNext => 'Given when saved: this is the next number.';

  @override
  String get autonumberExisting => 'Numbered when it was added.';

  @override
  String get clear => 'Clear';

  @override
  String stepOf(int step, int total) {
    return 'Step $step of $total';
  }

  @override
  String get filter => 'Filter';

  @override
  String get apply => 'Apply';

  @override
  String get add => 'Add';

  @override
  String get actions => 'Actions';

  @override
  String get cancel => 'Cancel';

  @override
  String get close => 'Close';

  @override
  String get delete => 'Delete';

  @override
  String get deleteConfirm => 'Delete this record?';

  @override
  String get check => 'Check';

  @override
  String get run => 'Run';

  @override
  String filterFirst(String labels) {
    return 'Choose a filter first: $labels';
  }

  @override
  String get stageNothing => 'Nothing to change: no rows match.';

  @override
  String stageWillChange(int n) {
    return 'This will change $n rows. Run it?';
  }

  @override
  String stageDone(int n) {
    return 'Done: $n rows changed.';
  }

  @override
  String get stageFailed => 'The query could not run.';

  @override
  String get fixErrors => 'Check the marked fields.';

  @override
  String get notifications => 'Notifications';

  @override
  String get noNotifications => 'No notifications yet.';

  @override
  String get markAllRead => 'Mark all read';

  @override
  String get searchMenus => 'Search screens';

  @override
  String get noMenuMatch => 'No screen matches.';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get or => 'or';

  @override
  String get continueWithGoogle => 'Continue with Google';

  @override
  String get showPassword => 'Show password';

  @override
  String get hidePassword => 'Hide password';

  @override
  String get noData => 'No data yet.';

  @override
  String get deleteForGood => 'It will be removed for good.';

  @override
  String get justNow => 'now';

  @override
  String get today => 'Today';

  @override
  String get tomorrow => 'Tomorrow';

  @override
  String get yesterday => 'Yesterday';

  @override
  String inDays(int count) {
    return 'In $count days';
  }

  @override
  String daysAgo(int count) {
    return '$count days ago';
  }
}
