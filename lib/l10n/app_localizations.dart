import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_mn.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('mn'),
  ];

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @fieldRequired.
  ///
  /// In en, this message translates to:
  /// **'This field is required'**
  String get fieldRequired;

  /// No description provided for @serverUnreachable.
  ///
  /// In en, this message translates to:
  /// **'The server could not be reached. Check your connection and try again.'**
  String get serverUnreachable;

  /// No description provided for @somethingWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Try again.'**
  String get somethingWrong;

  /// No description provided for @noAccessToCustomer.
  ///
  /// In en, this message translates to:
  /// **'Your account does not have access to this app\'s organization.'**
  String get noAccessToCustomer;

  /// No description provided for @more.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get more;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @organization.
  ///
  /// In en, this message translates to:
  /// **'Organization'**
  String get organization;

  /// No description provided for @openOnWebTitle.
  ///
  /// In en, this message translates to:
  /// **'Open on the web'**
  String get openOnWebTitle;

  /// No description provided for @openOnWebBody.
  ///
  /// In en, this message translates to:
  /// **'This screen is not available in the app yet. Open it on the web.'**
  String get openOnWebBody;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get comingSoon;

  /// No description provided for @noScreens.
  ///
  /// In en, this message translates to:
  /// **'There is nothing to show in this app yet.'**
  String get noScreens;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String welcome(String name);

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @noResults.
  ///
  /// In en, this message translates to:
  /// **'No results'**
  String get noResults;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAndAdd.
  ///
  /// In en, this message translates to:
  /// **'Save and add'**
  String get saveAndAdd;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @general.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get general;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @fillRequired.
  ///
  /// In en, this message translates to:
  /// **'Fill in the required fields.'**
  String get fillRequired;

  /// No description provided for @fillBeforeNext.
  ///
  /// In en, this message translates to:
  /// **'Fill this in before going on.'**
  String get fillBeforeNext;

  /// No description provided for @autonumberNext.
  ///
  /// In en, this message translates to:
  /// **'Given when saved: this is the next number.'**
  String get autonumberNext;

  /// No description provided for @autonumberExisting.
  ///
  /// In en, this message translates to:
  /// **'Numbered when it was added.'**
  String get autonumberExisting;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String stepOf(int step, int total);

  /// No description provided for @filter.
  ///
  /// In en, this message translates to:
  /// **'Filter'**
  String get filter;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @actions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actions;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @deleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this record?'**
  String get deleteConfirm;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @filterFirst.
  ///
  /// In en, this message translates to:
  /// **'Choose a filter first: {labels}'**
  String filterFirst(String labels);

  /// No description provided for @stageNothing.
  ///
  /// In en, this message translates to:
  /// **'Nothing to change: no rows match.'**
  String get stageNothing;

  /// No description provided for @stageWillChange.
  ///
  /// In en, this message translates to:
  /// **'This will change {n} rows. Run it?'**
  String stageWillChange(int n);

  /// No description provided for @stageDone.
  ///
  /// In en, this message translates to:
  /// **'Done: {n} rows changed.'**
  String stageDone(int n);

  /// No description provided for @stageFailed.
  ///
  /// In en, this message translates to:
  /// **'The query could not run.'**
  String get stageFailed;

  /// No description provided for @fixErrors.
  ///
  /// In en, this message translates to:
  /// **'Check the marked fields.'**
  String get fixErrors;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotifications.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotifications;

  /// No description provided for @markAllRead.
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get markAllRead;

  /// No description provided for @searchMenus.
  ///
  /// In en, this message translates to:
  /// **'Search screens'**
  String get searchMenus;

  /// No description provided for @noMenuMatch.
  ///
  /// In en, this message translates to:
  /// **'No screen matches.'**
  String get noMenuMatch;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @or.
  ///
  /// In en, this message translates to:
  /// **'or'**
  String get or;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @showPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get showPassword;

  /// No description provided for @hidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get hidePassword;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data yet.'**
  String get noData;

  /// No description provided for @deleteForGood.
  ///
  /// In en, this message translates to:
  /// **'It will be removed for good.'**
  String get deleteForGood;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get justNow;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @now.
  ///
  /// In en, this message translates to:
  /// **'Now'**
  String get now;

  /// No description provided for @tomorrow.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get tomorrow;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @inDays.
  ///
  /// In en, this message translates to:
  /// **'In {count} days'**
  String inDays(int count);

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(int count);

  /// No description provided for @personalInfo.
  ///
  /// In en, this message translates to:
  /// **'Personal info'**
  String get personalInfo;

  /// No description provided for @personalInfoNote.
  ///
  /// In en, this message translates to:
  /// **'How you appear in the app, and the email you log in with.'**
  String get personalInfoNote;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @saveChanges.
  ///
  /// In en, this message translates to:
  /// **'Save changes'**
  String get saveChanges;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'The language of screen names, field labels, buttons and statuses, where they have been translated.'**
  String get languageNote;

  /// No description provided for @languageAsPhone.
  ///
  /// In en, this message translates to:
  /// **'As my phone is'**
  String get languageAsPhone;

  /// No description provided for @customers.
  ///
  /// In en, this message translates to:
  /// **'Customers'**
  String get customers;

  /// No description provided for @customersNote.
  ///
  /// In en, this message translates to:
  /// **'The companies you work in. Each has its own apps, people and data.'**
  String get customersNote;

  /// No description provided for @openNow.
  ///
  /// In en, this message translates to:
  /// **'Open now'**
  String get openNow;

  /// No description provided for @admin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get admin;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get currentPassword;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPassword;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get confirmPassword;

  /// No description provided for @passwordHint.
  ///
  /// In en, this message translates to:
  /// **'At least 8 characters.'**
  String get passwordHint;

  /// No description provided for @passwordsDontMatch.
  ///
  /// In en, this message translates to:
  /// **'The passwords don\'t match.'**
  String get passwordsDontMatch;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get changePassword;

  /// No description provided for @passwordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get passwordChanged;

  /// No description provided for @passwordNote.
  ///
  /// In en, this message translates to:
  /// **'Changing it signs you out everywhere else; you stay signed in here.'**
  String get passwordNote;

  /// No description provided for @choose.
  ///
  /// In en, this message translates to:
  /// **'Choose'**
  String get choose;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @addLine.
  ///
  /// In en, this message translates to:
  /// **'Add line'**
  String get addLine;

  /// No description provided for @noLines.
  ///
  /// In en, this message translates to:
  /// **'No lines yet'**
  String get noLines;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @removeLine.
  ///
  /// In en, this message translates to:
  /// **'Remove this line?'**
  String get removeLine;

  /// No description provided for @newLine.
  ///
  /// In en, this message translates to:
  /// **'New: {name}'**
  String newLine(String name);

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @addPicked.
  ///
  /// In en, this message translates to:
  /// **'Add {count}'**
  String addPicked(int count);

  /// No description provided for @pickToWorkOn.
  ///
  /// In en, this message translates to:
  /// **'Pick a {name} to work on'**
  String pickToWorkOn(String name);

  /// No description provided for @recordNotLoaded.
  ///
  /// In en, this message translates to:
  /// **'This record could not be loaded.'**
  String get recordNotLoaded;

  /// No description provided for @workspaceNoSections.
  ///
  /// In en, this message translates to:
  /// **'This workspace has no sections yet.'**
  String get workspaceNoSections;

  /// No description provided for @workspaceNeedsForm.
  ///
  /// In en, this message translates to:
  /// **'This workspace needs a form for its record.'**
  String get workspaceNeedsForm;

  /// Placeholder on the right of an empty text row in a form
  ///
  /// In en, this message translates to:
  /// **'Enter'**
  String get fieldEnter;

  /// No description provided for @inbox.
  ///
  /// In en, this message translates to:
  /// **'Inbox'**
  String get inbox;

  /// No description provided for @chats.
  ///
  /// In en, this message translates to:
  /// **'Chats'**
  String get chats;

  /// No description provided for @newChat.
  ///
  /// In en, this message translates to:
  /// **'New chat'**
  String get newChat;

  /// No description provided for @noChats.
  ///
  /// In en, this message translates to:
  /// **'No chats yet. Start one with +.'**
  String get noChats;

  /// No description provided for @messageHint.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageHint;

  /// No description provided for @seen.
  ///
  /// In en, this message translates to:
  /// **'Seen'**
  String get seen;

  /// No description provided for @typingNow.
  ///
  /// In en, this message translates to:
  /// **'typing…'**
  String get typingNow;

  /// No description provided for @you.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get you;

  /// No description provided for @findPeople.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get findPeople;

  /// No description provided for @sendFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not send. Try again.'**
  String get sendFailed;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @noPeople.
  ///
  /// In en, this message translates to:
  /// **'No one else is here yet.'**
  String get noPeople;

  /// No description provided for @noConnection.
  ///
  /// In en, this message translates to:
  /// **'No connection'**
  String get noConnection;

  /// No description provided for @couldNotLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this'**
  String get couldNotLoad;

  /// No description provided for @addFile.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addFile;

  /// No description provided for @replaceFile.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get replaceFile;

  /// No description provided for @removeFile.
  ///
  /// In en, this message translates to:
  /// **'Remove file'**
  String get removeFile;

  /// No description provided for @noFiles.
  ///
  /// In en, this message translates to:
  /// **'No files'**
  String get noFiles;

  /// No description provided for @takePhoto.
  ///
  /// In en, this message translates to:
  /// **'Take photo'**
  String get takePhoto;

  /// No description provided for @photoLibrary.
  ///
  /// In en, this message translates to:
  /// **'Photo library'**
  String get photoLibrary;

  /// No description provided for @browseFiles.
  ///
  /// In en, this message translates to:
  /// **'Browse files'**
  String get browseFiles;

  /// No description provided for @upTo.
  ///
  /// In en, this message translates to:
  /// **'up to {size}'**
  String upTo(String size);

  /// No description provided for @fileTypeNotAllowed.
  ///
  /// In en, this message translates to:
  /// **'{name} can\'t be added here. Allowed: {types}'**
  String fileTypeNotAllowed(String name, String types);

  /// No description provided for @fileTooBig.
  ///
  /// In en, this message translates to:
  /// **'{name} is too big. The limit is {size}.'**
  String fileTooBig(String name, String size);

  /// No description provided for @fileLimit.
  ///
  /// In en, this message translates to:
  /// **'This field takes at most {count} files.'**
  String fileLimit(int count);

  /// No description provided for @couldNotPick.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t get the file. Check the app\'s photo and file permissions.'**
  String get couldNotPick;

  /// No description provided for @noAppToOpen.
  ///
  /// In en, this message translates to:
  /// **'No app on this phone opens this kind of file.'**
  String get noAppToOpen;

  /// No description provided for @filesUploading.
  ///
  /// In en, this message translates to:
  /// **'Wait for the files to finish uploading.'**
  String get filesUploading;

  /// No description provided for @shareToChat.
  ///
  /// In en, this message translates to:
  /// **'Share to chat'**
  String get shareToChat;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note (optional)'**
  String get addNote;

  /// No description provided for @people.
  ///
  /// In en, this message translates to:
  /// **'People'**
  String get people;

  /// No description provided for @sharedWith.
  ///
  /// In en, this message translates to:
  /// **'Shared with {name}'**
  String sharedWith(String name);

  /// No description provided for @noPeopleFound.
  ///
  /// In en, this message translates to:
  /// **'No one matches “{query}”.'**
  String noPeopleFound(String query);

  /// No description provided for @dragPickHint.
  ///
  /// In en, this message translates to:
  /// **'Tip: hold a card and slide to pick several'**
  String get dragPickHint;

  /// No description provided for @noMatchesHint.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches the search or filters.'**
  String get noMatchesHint;

  /// No description provided for @clearSearch.
  ///
  /// In en, this message translates to:
  /// **'Clear search and filters'**
  String get clearSearch;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortOrder.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get sortOrder;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @nothingYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get nothingYet;

  /// No description provided for @nothingYetAdd.
  ///
  /// In en, this message translates to:
  /// **'Tap + to add the first one.'**
  String get nothingYetAdd;

  /// No description provided for @nothingYetHint.
  ///
  /// In en, this message translates to:
  /// **'Records show up here once they are added.'**
  String get nothingYetHint;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'mn'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'mn':
      return AppLocalizationsMn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
