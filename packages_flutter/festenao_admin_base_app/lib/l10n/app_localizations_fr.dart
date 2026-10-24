// ignore_for_file: deprecated_member_use

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get acceptButtonLabel => 'Accepter';

  @override
  String get appVersion => 'Version :';

  @override
  String get cancelButtonLabel => 'Annuler';

  @override
  String get contentMarkdownInfo => 'Contenu au format Markdown';

  @override
  String get createProjectInfo =>
      'Créez un projet pour commencer. Les projets locaux sont stockés sur votre appareil, tandis que les projets synchronisés sont stockés dans le cloud.';

  @override
  String get createProjectTitle => 'Créer un projet';

  @override
  String get deleteButtonLabel => 'Supprimer';

  @override
  String get editDiscardChanges => 'Supprimer';

  @override
  String get editSaveChanges => 'Enregistrer';

  @override
  String get editUnsavedChangesTitle => 'Modifications non enregistrées';

  @override
  String get editYouHaveUnsavedChanges =>
      'Vous avez des modifications non enregistrées\n\nVous pouvez continuer l\'édition en choisissant d\'annuler ou de quitter l\'édition, en sauvegardant ou en supprimant vos modifications';

  @override
  String get emailLabel => 'E-mail';

  @override
  String get festenaoTitle => 'Festenao';

  @override
  String get genericCopied => 'Copié dans le presse-papiers';

  @override
  String get leaveButtonLabel => 'Quitter';

  @override
  String get localProjectTitle => 'Projet local';

  @override
  String get manageProjectTitle => 'Gérer le projet';

  @override
  String get manageProjectsTitle => 'Gérer les projets';

  @override
  String get markdownGuideAsset => 'markdown_guide_fr.md';

  @override
  String get markdownGuideTitle => 'Guide Markdown';

  @override
  String get nameLabel => 'Nom';

  @override
  String get nameRequired => 'Le nom est requis';

  @override
  String get notSignedInInfo => 'Vous n\'êtes pas connecté';

  @override
  String get noteContentHint => 'Contenu de la note';

  @override
  String get noteContentLabel => 'Contenu';

  @override
  String get noteCreateTitle => 'Créer une note';

  @override
  String get noteDelete => 'Supprimer la note';

  @override
  String get noteDeleteConfirm =>
      'Confirmez-vous la suppression de cette note ?';

  @override
  String get noteDescriptionHint => 'Description de la note';

  @override
  String get noteDescriptionLabel => 'Description';

  @override
  String get noteEditTitle => 'Modifier la note';

  @override
  String get noteTitleHint => 'Titre de la note';

  @override
  String get noteTitleLabel => 'Titre';

  @override
  String get notesOthers => 'Autres notes';

  @override
  String get notesPinned => 'Notes épinglées';

  @override
  String get notesTitle => 'Notes';

  @override
  String get operationFailed => 'Échec de l\'opération\nVeuillez réessayer';

  @override
  String get privacyPolicy => 'Politique de confidentialité';

  @override
  String get pendingEmailInvitesTitle => 'Invitations';

  @override
  String pendingEmailInviteFor(String email) {
    return 'Pour $email';
  }

  @override
  String get pendingEmailInviteAccept => 'Accepter';

  @override
  String pendingEmailInviteAcceptConfirm(String entity) {
    return 'Rejoindre $entity avec l\'accès proposé ?';
  }

  @override
  String get pendingEmailInviteAccepted => 'Invitation acceptée';

  @override
  String get pendingEmailInviteDecline => 'Refuser';

  @override
  String pendingEmailInviteDeclineConfirm(String entity) {
    return 'Refuser l\'invitation pour $entity ?';
  }

  @override
  String get pendingEmailInviteDeclined => 'Invitation refusée';

  @override
  String get projectAccessAdmin => 'Accès administrateur';

  @override
  String get projectAccessNone => 'Aucun accès';

  @override
  String get projectAccessRead => 'Accès lecteur';

  @override
  String get projectAccessRole => 'Rôle';

  @override
  String get projectAccessWrite => 'Accès éditeur';

  @override
  String get projectDefaultName => 'Projet';

  @override
  String get projectDelete => 'Supprimer le projet';

  @override
  String get projectDeleteConfirm =>
      'Êtes-vous sûr de vouloir supprimer ce projet ?\nTout le contenu de ce projet sera supprimé.';

  @override
  String get projectEditTitle => 'Modifier le projet';

  @override
  String get projectEmailInviteTitle => 'Inviter par e-mail';

  @override
  String get projectEmailInviteInformation =>
      'L\'invitation est réservée à cette adresse : la personne la voit dans l\'application une fois connectée avec cet e-mail, vérifié.';

  @override
  String get projectEmailInviteEmailLabel => 'Adresse e-mail';

  @override
  String get projectEmailInviteSend => 'Envoyer l\'invitation';

  @override
  String projectEmailInviteSent(String email) {
    return 'Invitation envoyée à $email';
  }

  @override
  String projectEmailInviteSaved(String email) {
    return 'Invitation enregistrée pour $email : la personne la voit dans l\'application une fois connectée avec cette adresse';
  }

  @override
  String get projectEmailInviteInvalidEmail =>
      'Saisissez une adresse e-mail valide';

  @override
  String get projectEmailInviteListTitle => 'Invitations par e-mail';

  @override
  String get projectEmailInviteNone => 'Aucune invitation par e-mail';

  @override
  String get projectEmailInviteStatusPending => 'En attente';

  @override
  String get projectEmailInviteStatusAccepted => 'Acceptée';

  @override
  String get projectEmailInviteStatusDiscarded => 'Refusée';

  @override
  String get projectEmailInviteRevoke => 'Supprimer l\'invitation';

  @override
  String projectEmailInviteRevokeConfirm(String email) {
    return 'Supprimer l\'invitation envoyée à $email ?';
  }

  @override
  String get projectInviteAccept => 'Accepter l\'invitation';

  @override
  String get projectInviteAcceptConfirm =>
      'Rejoindre ce projet avec l\'accès proposé ?';

  @override
  String get projectInviteDelete => 'Supprimer l\'invitation';

  @override
  String get projectInviteDeleteConfirm =>
      'Voulez-vous vraiment supprimer cette invitation ?';

  @override
  String get projectInviteLink => 'Lien d\'invitation';

  @override
  String get projectInviteLinkInformation =>
      'Envoyez ce lien pour inviter quelqu\'un à ce projet';

  @override
  String get projectInviteMessage =>
      'Vous avez été invité à rejoindre ce projet';

  @override
  String get projectInviteMustBeLoggedIn =>
      'Vous devez être connecté pour accepter cette invitation';

  @override
  String get projectInviteNotFound => 'Invitation introuvable ou expirée';

  @override
  String get projectInviteTitle => 'Invitation';

  @override
  String get projectInviteView => 'Voir l\'invitation';

  @override
  String get projectJoin => 'Rejoindre le projet';

  @override
  String get projectLeave => 'Quitter le projet';

  @override
  String get projectLeaveConfirm =>
      'Êtes-vous sûr de vouloir quitter ce projet ?\nVous ne pourrez plus accéder à son contenu';

  @override
  String get projectNotFound => 'Projet introuvable';

  @override
  String get projectShare => 'Partager le projet';

  @override
  String get projectShareInformation =>
      'Cliquez sur le bouton Partager ci-dessous pour inviter quelqu\'un à rejoindre ce projet';

  @override
  String get projectTypeLocal => 'Local';

  @override
  String get projectTypeSynced => 'Synchronisé';

  @override
  String get projectViewNotes => 'Voir les notes';

  @override
  String get projectsTitle => 'Projets';

  @override
  String settingCurrentProject(String project) {
    return 'Projet actuel \'$project\'';
  }

  @override
  String get settingManageProject => 'Gérer le projet';

  @override
  String get settingSwitchProject => 'Changer de projet';

  @override
  String get settingsTitle => 'Paramètres';

  @override
  String get signInButtonLabel => 'Se connecter';

  @override
  String get userNotSignedInInfo => 'Vous n\'êtes pas connecté';

  @override
  String userSignedInInfo(String user) {
    return 'Vous êtes connecté en tant que $user';
  }

  @override
  String get userTitle => 'Utilisateur';

  @override
  String get accessTitle => 'Accès';

  @override
  String get accessSubtitle => 'Qui peut ouvrir et modifier ce projet';

  @override
  String get accessAppSubtitle =>
      'Les utilisateurs de l\'application et leur rôle';

  @override
  String accessMembers(int count) {
    return 'Membres · $count';
  }

  @override
  String get accessAddUser => 'Ajouter un utilisateur';

  @override
  String get accessNoUser => 'Aucun utilisateur';

  @override
  String get accessNoMatch => 'Aucun utilisateur ne correspond';

  @override
  String get accessSearchHint => 'Rechercher un utilisateur';

  @override
  String get accessYou => 'vous';

  @override
  String get accessRoleReader => 'Lecteur';

  @override
  String get accessRoleEditor => 'Éditeur';

  @override
  String get accessRoleAdmin => 'Admin';

  @override
  String get accessRoleReaderDetail => 'Consulte le contenu et les rapports';

  @override
  String get accessRoleEditorDetail => 'Modifie le contenu';

  @override
  String get accessRoleAdminDetail => 'Gère aussi les accès et le projet';

  @override
  String get accessRoleNoneDetail => 'Aucun accès : choisissez un rôle';

  @override
  String get accessAccountSection => 'Compte';

  @override
  String get accessAdvancedSection => 'Avancé';

  @override
  String get accessAppRole => 'Rôle dans l\'application';

  @override
  String get accessAppRoleHelper =>
      'Facultatif, pour les rôles de toute l\'application';

  @override
  String get accessCustomRole => 'Rôle personnalisé';

  @override
  String get accessUserId => 'Identifiant';

  @override
  String get accessUserIdRequired => 'L\'identifiant est requis';

  @override
  String get accessFillFromAccount => 'Remplir depuis le compte';

  @override
  String get accessFillNotAllowed => 'Vous ne pouvez pas lire ce compte';

  @override
  String accessFillUnknown(String userId) {
    return 'Compte inconnu : $userId';
  }

  @override
  String get accessFillError => 'Lecture du compte impossible';

  @override
  String get accessFillMeAsAdmin => 'M\'ajouter comme admin';

  @override
  String get accessCopyId => 'Copier l\'identifiant';

  @override
  String get accessIdCopied => 'Identifiant copié';

  @override
  String get accessEdit => 'Modifier';

  @override
  String get accessRawData => 'Données brutes';

  @override
  String get syncNow => 'Synchroniser';

  @override
  String get syncInProgress => 'Synchronisation…';

  @override
  String get syncFailed =>
      'Échec de la synchronisation, toucher pour réessayer';

  @override
  String get exportWrapOn => 'Activer le retour à la ligne';

  @override
  String get exportWrapOff => 'Désactiver le retour à la ligne';

  @override
  String get exportDownload => 'Télécharger';

  @override
  String get exportDownloadStarted => 'Téléchargement lancé.';

  @override
  String get projectsSubtitle => 'Les projets que vous pouvez ouvrir';

  @override
  String get projectsNone => 'Aucun projet pour l\'instant';

  @override
  String get projectNew => 'Nouveau projet';

  @override
  String get projectIdLabel => 'Identifiant du projet';

  @override
  String get projectIdOptionalHint => 'Optionnel, généré si vide';

  @override
  String get projectUrl => 'Url';

  @override
  String get projectDetailsSection => 'Projet';

  @override
  String get projectYourRole => 'Votre rôle';

  @override
  String get projectNotSyncedYet => 'Pas encore synchronisé';

  @override
  String get projectUsersTitle => 'Utilisateurs';

  @override
  String get projectShareInvite => 'Partager / inviter';

  @override
  String get projectShareInviteDetail => 'Inviter par lien ou par email';

  @override
  String get projectLeaveDetail => 'Vous ne verrez plus ce projet';

  @override
  String get projectDeleteDetail => 'Supprime le projet pour tout le monde';

  @override
  String get projectInviteRoleInformation => 'Le rôle donné par l\'invitation';

  @override
  String get projectInviteGenerate => 'Générer une invitation';

  @override
  String get projectInviteIdLabel => 'Identifiant de l\'invitation';

  @override
  String get projectInviteAccepted => 'Invitation acceptée';

  @override
  String get projectInviteRoleEdit => 'Le rôle donné, modifiable par un admin';

  @override
  String get copyButtonLabel => 'Copier';

  @override
  String get linkCopied => 'Lien copié';

  @override
  String get accessRemoveUser => 'Retirer l\'utilisateur';

  @override
  String get accessRemoveUserConfirm => 'Retirer cet utilisateur du projet ?';

  @override
  String get editLeaveWithoutSaving =>
      'Vous avez des modifications non enregistrées\n\nVous pouvez continuer l\'édition en choisissant d\'annuler ou quitter l\'édition en supprimant vos modifications';
}
