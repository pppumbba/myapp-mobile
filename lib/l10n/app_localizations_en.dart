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
  String get now => 'Now';

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

  @override
  String get personalInfo => 'Personal info';

  @override
  String get personalInfoNote =>
      'How you appear in the app, and the email you log in with.';

  @override
  String get name => 'Name';

  @override
  String get saveChanges => 'Save changes';

  @override
  String get appearance => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get language => 'Language';

  @override
  String get languageNote =>
      'The language of screen names, field labels, buttons and statuses, where they have been translated.';

  @override
  String get languageAsPhone => 'As my phone is';

  @override
  String get customers => 'Customers';

  @override
  String get customersNote =>
      'The companies you work in. Each has its own apps, people and data.';

  @override
  String get openNow => 'Open now';

  @override
  String get admin => 'Admin';

  @override
  String get currentPassword => 'Current password';

  @override
  String get newPassword => 'New password';

  @override
  String get confirmPassword => 'Confirm new password';

  @override
  String get passwordHint => 'At least 8 characters.';

  @override
  String get passwordsDontMatch => 'The passwords don\'t match.';

  @override
  String get changePassword => 'Change password';

  @override
  String get passwordChanged => 'Password changed';

  @override
  String get passwordNote =>
      'Changing it signs you out everywhere else; you stay signed in here.';

  @override
  String get choose => 'Choose';

  @override
  String get edit => 'Edit';

  @override
  String get addLine => 'Add line';

  @override
  String get noLines => 'No lines yet';

  @override
  String get total => 'Total';

  @override
  String get removeLine => 'Remove this line?';

  @override
  String newLine(String name) {
    return 'New: $name';
  }

  @override
  String get done => 'Done';

  @override
  String addPicked(int count) {
    return 'Add $count';
  }

  @override
  String pickToWorkOn(String name) {
    return 'Pick a $name to work on';
  }

  @override
  String get recordNotLoaded => 'This record could not be loaded.';

  @override
  String get workspaceNoSections => 'This workspace has no sections yet.';

  @override
  String get workspaceNeedsForm =>
      'This workspace needs a form for its record.';

  @override
  String get fieldEnter => 'Enter';

  @override
  String get inbox => 'Inbox';

  @override
  String get chats => 'Chats';

  @override
  String get newChat => 'New chat';

  @override
  String get noChats => 'No chats yet. Start one with +.';

  @override
  String get messageHint => 'Message';

  @override
  String get seen => 'Seen';

  @override
  String get typingNow => 'typing…';

  @override
  String get you => 'You';

  @override
  String get findPeople => 'Find people';

  @override
  String get sendFailed => 'Could not send. Try again.';

  @override
  String get send => 'Send';

  @override
  String get delivered => 'Delivered';

  @override
  String get noPeople => 'No one else is here yet.';

  @override
  String get noConnection => 'No connection';

  @override
  String get couldNotLoad => 'Couldn\'t load this';

  @override
  String get addFile => 'Add';

  @override
  String get replaceFile => 'Replace';

  @override
  String get removeFile => 'Remove file';

  @override
  String get noFiles => 'No files';

  @override
  String get takePhoto => 'Take photo';

  @override
  String get photoLibrary => 'Photo library';

  @override
  String get browseFiles => 'Browse files';

  @override
  String upTo(String size) {
    return 'up to $size';
  }

  @override
  String fileTypeNotAllowed(String name, String types) {
    return '$name can\'t be added here. Allowed: $types';
  }

  @override
  String fileTooBig(String name, String size) {
    return '$name is too big. The limit is $size.';
  }

  @override
  String fileLimit(int count) {
    return 'This field takes at most $count files.';
  }

  @override
  String get couldNotPick =>
      'Couldn\'t get the file. Check the app\'s photo and file permissions.';

  @override
  String get noAppToOpen => 'No app on this phone opens this kind of file.';

  @override
  String get filesUploading => 'Wait for the files to finish uploading.';

  @override
  String get shareToChat => 'Share to chat';

  @override
  String get addNote => 'Add a note (optional)';

  @override
  String get people => 'People';

  @override
  String sharedWith(String name) {
    return 'Shared with $name';
  }

  @override
  String noPeopleFound(String query) {
    return 'No one matches “$query”.';
  }

  @override
  String get dragPickHint => 'Tip: hold a card and slide to pick several';

  @override
  String get noMatchesHint => 'Nothing matches the search or filters.';

  @override
  String get clearSearch => 'Clear search and filters';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortOrder => 'Order';

  @override
  String get ascending => 'Ascending';

  @override
  String get descending => 'Descending';

  @override
  String get nothingYet => 'Nothing here yet';

  @override
  String get nothingYetAdd => 'Tap + to add the first one.';

  @override
  String get nothingYetHint => 'Records show up here once they are added.';
}
