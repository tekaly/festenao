import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

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

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
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
    Locale('fr'),
  ];

  /// Accept button label
  ///
  /// In en, this message translates to:
  /// **'Accept'**
  String get acceptButtonLabel;

  /// App version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get appVersion;

  /// Cancel button label
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancelButtonLabel;

  /// Content markdown info message
  ///
  /// In en, this message translates to:
  /// **'Content in markdown format'**
  String get contentMarkdownInfo;

  /// Create project info message
  ///
  /// In en, this message translates to:
  /// **'Create a project to start storing your notes, local projects are stored on your device, synced projects are stored in the cloud'**
  String get createProjectInfo;

  /// Create project title
  ///
  /// In en, this message translates to:
  /// **'Create Project'**
  String get createProjectTitle;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get deleteButtonLabel;

  /// Edit discard changes
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get editDiscardChanges;

  /// Edit save changes
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get editSaveChanges;

  /// Unsaved changes title
  ///
  /// In en, this message translates to:
  /// **'Unsaved changes'**
  String get editUnsavedChangesTitle;

  /// Edit unsaved changes
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes\n\nYou can continue editing by choosing cancel or quit edition, saving or discarding your changes'**
  String get editYouHaveUnsavedChanges;

  /// App title
  ///
  /// In en, this message translates to:
  /// **'Festenao'**
  String get festenaoTitle;

  /// Copied to clipboard
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get genericCopied;

  /// Delete button label
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get leaveButtonLabel;

  /// Local project title
  ///
  /// In en, this message translates to:
  /// **'Local Project'**
  String get localProjectTitle;

  /// Manage project title
  ///
  /// In en, this message translates to:
  /// **'Manage Project'**
  String get manageProjectTitle;

  /// Manage projects title
  ///
  /// In en, this message translates to:
  /// **'Manage Projects'**
  String get manageProjectsTitle;

  /// Markdown guide asset
  ///
  /// In en, this message translates to:
  /// **'markdown_guide_en.md'**
  String get markdownGuideAsset;

  /// Markdown guide title
  ///
  /// In en, this message translates to:
  /// **'Markdown Guide'**
  String get markdownGuideTitle;

  /// Name label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get nameLabel;

  /// Name required error message
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// Info message when user is not signed in
  ///
  /// In en, this message translates to:
  /// **'You are not signed in'**
  String get notSignedInInfo;

  /// Note content hint
  ///
  /// In en, this message translates to:
  /// **'Note content'**
  String get noteContentHint;

  /// Note content label
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get noteContentLabel;

  /// Create note title
  ///
  /// In en, this message translates to:
  /// **'Create Note'**
  String get noteCreateTitle;

  /// Delete note
  ///
  /// In en, this message translates to:
  /// **'Delete Note'**
  String get noteDelete;

  /// Delete note confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this note?'**
  String get noteDeleteConfirm;

  /// Note description hint
  ///
  /// In en, this message translates to:
  /// **'Note description'**
  String get noteDescriptionHint;

  /// Note description label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get noteDescriptionLabel;

  /// Edit note title
  ///
  /// In en, this message translates to:
  /// **'Edit Note'**
  String get noteEditTitle;

  /// Note title hint
  ///
  /// In en, this message translates to:
  /// **'Note title'**
  String get noteTitleHint;

  /// Note title label
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get noteTitleLabel;

  /// Other notes
  ///
  /// In en, this message translates to:
  /// **'Other notes'**
  String get notesOthers;

  /// Pinned notes
  ///
  /// In en, this message translates to:
  /// **'Pinned notes'**
  String get notesPinned;

  /// Notes title
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get notesTitle;

  /// Operation failed
  ///
  /// In en, this message translates to:
  /// **'Operation failed\nPlease try again'**
  String get operationFailed;

  /// Privacy policy
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// Project access admin
  ///
  /// In en, this message translates to:
  /// **'Admin access'**
  String get projectAccessAdmin;

  /// No access
  ///
  /// In en, this message translates to:
  /// **'No access'**
  String get projectAccessNone;

  /// Project access read
  ///
  /// In en, this message translates to:
  /// **'Reader access'**
  String get projectAccessRead;

  /// User project access role
  ///
  /// In en, this message translates to:
  /// **'Role'**
  String get projectAccessRole;

  /// No description provided for @projectAccessWrite.
  ///
  /// In en, this message translates to:
  /// **'Editor access'**
  String get projectAccessWrite;

  /// Project default name
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get projectDefaultName;

  /// Delete project
  ///
  /// In en, this message translates to:
  /// **'Delete Project'**
  String get projectDelete;

  /// Delete project confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this project?\nAll notes in this project will be deleted'**
  String get projectDeleteConfirm;

  /// Edit Project title
  ///
  /// In en, this message translates to:
  /// **'Edit Project'**
  String get projectEditTitle;

  /// Accept project
  ///
  /// In en, this message translates to:
  /// **'Accept project invite'**
  String get projectInviteAccept;

  /// Accept project invite confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to accept this project invite?'**
  String get projectInviteAcceptConfirm;

  /// Delete project invite
  ///
  /// In en, this message translates to:
  /// **'Delete Project invite'**
  String get projectInviteDelete;

  /// Delete project invite confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this project invite?'**
  String get projectInviteDeleteConfirm;

  /// Project invite link
  ///
  /// In en, this message translates to:
  /// **'Project invite link'**
  String get projectInviteLink;

  /// Project invite link information
  ///
  /// In en, this message translates to:
  /// **'Send this link to invite someone to this project'**
  String get projectInviteLinkInformation;

  /// Project invite message
  ///
  /// In en, this message translates to:
  /// **'You have a project invite'**
  String get projectInviteMessage;

  /// Project invite not logged in message
  ///
  /// In en, this message translates to:
  /// **'You must be logged in to accept a project invite'**
  String get projectInviteMustBeLoggedIn;

  /// Project invite not found
  ///
  /// In en, this message translates to:
  /// **'Project invite not found'**
  String get projectInviteNotFound;

  /// Project invite title
  ///
  /// In en, this message translates to:
  /// **'Accept project invite'**
  String get projectInviteTitle;

  /// View invite
  ///
  /// In en, this message translates to:
  /// **'View invite'**
  String get projectInviteView;

  /// Join project button label
  ///
  /// In en, this message translates to:
  /// **'Join Project'**
  String get projectJoin;

  /// Leave project
  ///
  /// In en, this message translates to:
  /// **'Leave Project'**
  String get projectLeave;

  /// Leave project confirmation message
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this project?\nYou won\'t be able to access any notes contained in this project'**
  String get projectLeaveConfirm;

  /// Project not found
  ///
  /// In en, this message translates to:
  /// **'Project not found'**
  String get projectNotFound;

  /// Share project
  ///
  /// In en, this message translates to:
  /// **'Share project'**
  String get projectShare;

  /// Project share information
  ///
  /// In en, this message translates to:
  /// **'Click on the Share button below to invite someone to this project'**
  String get projectShareInformation;

  /// Local project type
  ///
  /// In en, this message translates to:
  /// **'Local'**
  String get projectTypeLocal;

  /// Synced project type
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get projectTypeSynced;

  /// View notes
  ///
  /// In en, this message translates to:
  /// **'View notes'**
  String get projectViewNotes;

  /// Projects title
  ///
  /// In en, this message translates to:
  /// **'Projects'**
  String get projectsTitle;

  /// Current project setting
  ///
  /// In en, this message translates to:
  /// **'Current project \'{project}\''**
  String settingCurrentProject(String project);

  /// Manage current project
  ///
  /// In en, this message translates to:
  /// **'Manage Project'**
  String get settingManageProject;

  /// Switch current project
  ///
  /// In en, this message translates to:
  /// **'Switch Project'**
  String get settingSwitchProject;

  /// Settings title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// Sign in button label
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInButtonLabel;

  /// User not signed in info message
  ///
  /// In en, this message translates to:
  /// **'You are not signed in'**
  String get userNotSignedInInfo;

  /// User sign in info message
  ///
  /// In en, this message translates to:
  /// **'You are signed in as {user}'**
  String userSignedInInfo(String user);

  /// User title
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get userTitle;
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
      <String>['en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
