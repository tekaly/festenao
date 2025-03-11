// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get acceptButtonLabel => 'Accept';

  @override
  String get appVersion => 'Version';

  @override
  String get projectAccessAdmin => 'Admin access';

  @override
  String get projectAccessRead => 'Reader access';

  @override
  String get projectAccessWrite => 'Editor access';

  @override
  String get projectDefaultName => 'Project';

  @override
  String get projectAccessNone => 'No access';

  @override
  String get projectDelete => 'Delete Project';

  @override
  String get projectDeleteConfirm =>
      'Are you sure you want to delete this project?\nAll notes in this project will be deleted';

  @override
  String get projectEditTitle => 'Edit Project';

  @override
  String get projectInviteAccept => 'Accept project invite';

  @override
  String get projectInviteAcceptConfirm =>
      'Are you sure you want to accept this project invite?';

  @override
  String get projectInviteDelete => 'Delete Project invite';

  @override
  String get projectInviteDeleteConfirm =>
      'Are you sure you want to delete this project invite?';

  @override
  String get projectInviteLink => 'Project invite link';

  @override
  String get projectInviteLinkInformation =>
      'Send this link to invite someone to this project';

  @override
  String get projectInviteMessage => 'You have a project invite';

  @override
  String get projectInviteMustBeLoggedIn =>
      'You must be logged in to accept a project invite';

  @override
  String get projectInviteNotFound => 'Project invite not found';

  @override
  String get projectInviteTitle => 'Accept project invite';

  @override
  String get projectInviteView => 'View invite';

  @override
  String get projectLeave => 'Leave Project';

  @override
  String get projectLeaveConfirm =>
      'Are you sure you want to leave this project?\nYou won\'t be able to access any notes contained in this project';

  @override
  String get projectNotFound => 'Project not found';

  @override
  String get projectShare => 'Share project';

  @override
  String get projectShareInformation =>
      'Click on the Share button below to invite someone to this project';

  @override
  String get projectTypeLocal => 'Local';

  @override
  String get projectTypeSynced => 'Synced';

  @override
  String get projectViewNotes => 'View notes';

  @override
  String get projectsTitle => 'Projects';

  @override
  String get cancelButtonLabel => 'Cancel';

  @override
  String get contentMarkdownInfo => 'Content in markdown format';

  @override
  String get createProjectInfo =>
      'Create a project to start storing your notes, local projects are stored on your device, synced projects are stored in the cloud';

  @override
  String get createProjectTitle => 'Create Project';

  @override
  String get deleteButtonLabel => 'Delete';

  @override
  String get editDiscardChanges => 'Discard';

  @override
  String get editSaveChanges => 'Save';

  @override
  String get editUnsavedChangesTitle => 'Unsaved changes';

  @override
  String get editYouHaveUnsavedChanges =>
      'You have unsaved changes\n\nYou can continue editing by choosing cancel or quit edition, saving or discarding your changes';

  @override
  String get genericCopied => 'Copied to clipboard';

  @override
  String get leaveButtonLabel => 'Leave';

  @override
  String get localProjectTitle => 'Local Project';

  @override
  String get manageProjectTitle => 'Manage Project';

  @override
  String get manageProjectsTitle => 'Manage Projects';

  @override
  String get markdownGuideAsset => 'markdown_guide_en.md';

  @override
  String get markdownGuideTitle => 'Markdown Guide';

  @override
  String get nameRequired => 'Name is required';

  @override
  String get notSignedInInfo => 'You are not signed in';

  @override
  String get noteContentHint => 'Note content';

  @override
  String get noteContentLabel => 'Content';

  @override
  String get noteCreateTitle => 'Create Note';

  @override
  String get noteDelete => 'Delete Note';

  @override
  String get noteDeleteConfirm => 'Are you sure you want to delete this note?';

  @override
  String get noteDescriptionHint => 'Note description';

  @override
  String get noteDescriptionLabel => 'Description';

  @override
  String get noteEditTitle => 'Edit Note';

  @override
  String get noteTitleHint => 'Note title';

  @override
  String get noteTitleLabel => 'Title';

  @override
  String get festenaoTitle => 'Festenao';

  @override
  String get notesOthers => 'Other notes';

  @override
  String get notesPinned => 'Pinned notes';

  @override
  String get notesTitle => 'Notes';

  @override
  String get operationFailed => 'Operation failed\nPlease try again';

  @override
  String get privacyPolicy => 'Privacy Policy';

  @override
  String settingCurrentProject(String project) {
    return 'Current project \'$project\'';
  }

  @override
  String get settingManageProject => 'Manage Project';

  @override
  String get settingSwitchProject => 'Switch Project';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get signInButtonLabel => 'Sign in';

  @override
  String get userNotSignedInInfo => 'You are not signed in';

  @override
  String userSignedInInfo(String user) {
    return 'You are signed in as $user';
  }

  @override
  String get userTitle => 'User';
}
