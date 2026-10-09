import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Command name for creating an entity.
const festenaoCreateEntityCommand = 'create-entity';

/// Prefix for entity command
String festenaoEntityCommandPrefix(String entityType) => 'entity/$entityType/';

/// Command name for creating an entity.
String festenaoEntityCreateCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}create';

/// Command name for deleting an entity.
const festenaoDeleteEntityCommand = 'delete-entity';

/// Command name for deleting an entity.
String festenaoEntityDeleteCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}delete';

/// Command name for purging an entity.
const festenaoPurgeEntityCommand = 'purge-entity';

/// Command name for purging an entity.
String festenaoEntityPurgeCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}purge';

/// Command name for joining an entity.
const festenaoJoinEntityCommand = 'join-entity';

/// Command name for joining an entity.
String festenaoEntityJoinCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}join';

/// Command name for leaving an entity.
const festenaoLeaveEntityCommand = 'leave-entity';

/// Command name for leaving an entity.
String festenaoEntityLeaveCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}leave';

/// Command name for creating an entity invite.
const festenaoCreateInviteCommand = 'create-invite';

/// Command name for creating an entity invite.
String festenaoEntityCreateInviteCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}create-invite';

/// Command name for accepting an entity invite.
const festenaoAcceptInviteCommand = 'accept-invite';

/// Command name for accepting an entity invite.
String festenaoEntityAcceptInviteCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}accept-invite';

/// Command name for deleting an entity invite.
const festenaoDeleteInviteCommand = 'delete-invite';

/// Command name for deleting an entity invite.
String festenaoEntityDeleteInviteCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}delete-invite';

/// Command name for making an entity public (or private again).
const festenaoSetEntityPublicCommand = 'set-entity-public';

/// Command name for making an entity public (or private again).
String festenaoEntitySetPublicCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}set-public';

/// Command name for creating an addressed email invite.
const festenaoCreateEmailInviteCommand = 'create-email-invite';

/// Command name for creating an addressed email invite.
String festenaoEntityCreateEmailInviteCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}$festenaoCreateEmailInviteCommand';

/// Command name for listing the email invites of an entity.
const festenaoListEmailInvitesCommand = 'list-email-invites';

/// Command name for listing the email invites of an entity.
String festenaoEntityListEmailInvitesCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}$festenaoListEmailInvitesCommand';

/// Command name for deleting (revoking) an email invite.
const festenaoDeleteEmailInviteCommand = 'delete-email-invite';

/// Command name for deleting (revoking) an email invite.
String festenaoEntityDeleteEmailInviteCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}$festenaoDeleteEmailInviteCommand';

/// Command name for checking the email invites addressed to the user.
const festenaoCheckEmailInvitesCommand = 'check-email-invites';

/// Command name for checking the email invites addressed to the user.
String festenaoEntityCheckEmailInvitesCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}$festenaoCheckEmailInvitesCommand';

/// Command name for accepting an email invite.
const festenaoAcceptEmailInviteCommand = 'accept-email-invite';

/// Command name for accepting an email invite.
String festenaoEntityAcceptEmailInviteCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}$festenaoAcceptEmailInviteCommand';

/// Command name for discarding an email invite.
const festenaoDiscardEmailInviteCommand = 'discard-email-invite';

/// Command name for discarding an email invite.
String festenaoEntityDiscardEmailInviteCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}$festenaoDiscardEmailInviteCommand';

/// Command name for reading the account information of a user (name, email)
/// to fill an access being edited.
const festenaoGetUserInfoCommand = 'get-user-info';

/// Command name for reading the account information of a user.
String festenaoEntityGetUserInfoCommand(String entityType) =>
    '${festenaoEntityCommandPrefix(entityType)}$festenaoGetUserInfoCommand';

/// Initializes API builders for Festenao file system entities.
void initFestenaoFsEntityApiBuilders<T extends TkCmsFsEntity>() {
  initTkCmsFsUserAccessBuilders();
  cvAddConstructors([
    FsCmsEntityCreateApiQuery<T>.new,
    FsCmsEntityCreateApiResult<T>.new,
    FsCmsEntityDeleteApiQuery<T>.new,
    FsCmsEntityDeleteApiResult<T>.new,
    FsCmsEntityJoinApiQuery<T>.new,
    FsCmsEntityCreateInviteApiQuery<T>.new,
    FsCmsEntityCreateInviteApiResult<T>.new,
    FsCmsEntityAcceptInviteApiQuery<T>.new,
    FsCmsEntitySetPublicApiQuery<T>.new,
    FsCmsEntitySetPublicApiResult<T>.new,
    FsCmsEntityCreateEmailInviteApiQuery<T>.new,
    FsCmsEntityCreateEmailInviteApiResult<T>.new,
    FsCmsEntityListEmailInvitesApiQuery<T>.new,
    FsCmsEntityListEmailInvitesApiResult<T>.new,
    FsCmsEntityEmailInviteIdApiQuery<T>.new,
    FsCmsEntityEmailInviteIdApiResult<T>.new,
    FsCmsEntityCheckEmailInvitesApiQuery<T>.new,
    FsCmsEntityCheckEmailInvitesApiResult<T>.new,
    FsCmsEntityGetUserInfoApiQuery<T>.new,
    FsCmsEntityGetUserInfoApiResult<T>.new,
  ]);
}

/// Extension for [TkCmsFirestoreDatabaseEntityCollectionInfo] to provide API command names.
extension FestenaoFirestoreDatabaseEntityCollectionInfoApiExt<
  TEntity extends TkCmsFsEntity
>
    on TkCmsFirestoreDatabaseEntityCollectionInfo<TEntity> {
  /// Command for creating an entity.
  String get createCommand => festenaoEntityCreateCommand(entityType);

  /// Command for deleting an entity.
  String get deleteCommand => festenaoEntityDeleteCommand(entityType);

  /// Command for purging an entity.
  String get purgeCommand => festenaoEntityPurgeCommand(entityType);

  /// Command for joining an entity / could require an invite...
  String get joinCommand => festenaoEntityJoinCommand(entityType);

  /// Command for leaving an entity.
  String get leaveCommand => festenaoEntityLeaveCommand(entityType);

  /// Command for creating an entity invite.
  String get createInviteCommand =>
      festenaoEntityCreateInviteCommand(entityType);

  /// Command for accepting an entity invite.
  String get acceptInviteCommand =>
      festenaoEntityAcceptInviteCommand(entityType);

  /// Command for deleting an entity invite.
  String get deleteInviteCommand =>
      festenaoEntityDeleteInviteCommand(entityType);

  /// Command for making an entity public (or private again).
  String get setPublicCommand => festenaoEntitySetPublicCommand(entityType);

  /// Command for creating an addressed email invite.
  String get createEmailInviteCommand =>
      festenaoEntityCreateEmailInviteCommand(entityType);

  /// Command for listing the email invites of an entity.
  String get listEmailInvitesCommand =>
      festenaoEntityListEmailInvitesCommand(entityType);

  /// Command for deleting (revoking) an email invite.
  String get deleteEmailInviteCommand =>
      festenaoEntityDeleteEmailInviteCommand(entityType);

  /// Command for checking the email invites addressed to the user.
  String get checkEmailInvitesCommand =>
      festenaoEntityCheckEmailInvitesCommand(entityType);

  /// Command for accepting an email invite.
  String get acceptEmailInviteCommand =>
      festenaoEntityAcceptEmailInviteCommand(entityType);

  /// Command for discarding an email invite.
  String get discardEmailInviteCommand =>
      festenaoEntityDiscardEmailInviteCommand(entityType);

  /// Command for reading the account information of a user.
  String get getUserInfoCommand => festenaoEntityGetUserInfoCommand(entityType);
}

/// API query for creating a CMS entity.
class FsCmsEntityCreateApiQuery<T extends TkCmsFsEntity> extends ApiQuery {
  /// The entity ID.
  final entityId = CvField<String>('entityId');

  /// The entity data as a map.
  final data = CvField<Map>('data');

  @override
  late final CvFields fields = [entityId, data];
}

/// API result for creating a CMS entity.
class FsCmsEntityCreateApiResult<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon
    implements ApiResult {
  /// The created entity as a map.
  final entity = CvField<Map>('entity');

  /// The firestore path
  final path = CvField<String>('path');

  @override
  CvFields get fields => [...super.fields, entity, path];
}

/// API query for deleting a CMS entity.
class FsCmsEntityDeleteApiQuery<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiQuery {}

/// API result for deleting a CMS entity.
class FsCmsEntityDeleteApiResult<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiResult {}

/// API result for purging a CMS entity.
typedef FsCmsEntityPurgeApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiResult<T>;

/// API query for purging a CMS entity.
typedef FsCmsEntityPurgeApiQuery<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiQuery<T>;

/// API result for joining a CMS entity.
typedef FsCmsEntityJoinApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiResult<T>;

/// API query for joining a CMS entity.
class FsCmsEntityJoinApiQuery<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiQuery {
  /// Data representing user access.
  final access = CvField<Map>('access');

  @override
  CvFields get fields => [...super.fields, access];
}

/// API result for leaving a CMS entity.
typedef FsCmsEntityLeaveApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiResult<T>;

/// API query for leaving a CMS entity.
typedef FsCmsEntityLeaveApiQuery<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiQuery<T>;

/// Base class for API queries and results containing an entity ID.
class FsCmsEntityEntityIdBaseApiCommon<T extends TkCmsFsEntity>
    extends ApiCommonBase {
  /// The entity ID.
  late final entityId = CvField<String>('entityId');

  @override
  CvFields get fields => [entityId];
}

/// API query for creating a CMS entity invite.
class FsCmsEntityCreateInviteApiQuery<T extends TkCmsFsEntity> extends ApiQuery
    with TkCmsCvUserAccessMixin {
  /// The entity ID.
  final entityId = CvField<String>('entityId');

  /// The invited email, when the invite targets a given user email.
  ///
  /// When set, only a user with this email can accept the invite.
  final email = CvField<String>('email');

  @override
  late final CvFields fields = [entityId, email, ...userAccessFields];
}

/// API result for creating a CMS entity invite.
class FsCmsEntityCreateInviteApiResult<T extends TkCmsFsEntity>
    extends ApiResult {
  /// The invite ID.
  final inviteId = CvField<String>('inviteId');

  /// The invited email if any (normalized).
  final email = CvField<String>('email');

  @override
  CvFields get fields => [inviteId, email];
}

/// API query for accepting a CMS entity invite.
class FsCmsEntityAcceptInviteApiQuery<T extends TkCmsFsEntity>
    extends ApiQuery {
  /// The invite ID.
  final inviteId = CvField<String>('inviteId');

  /// The entity ID.
  final entityId = CvField<String>('entityId');

  /// The accepting user email, needed for an email invite.
  ///
  /// Beware: the api request only carries a verified user id, the email is
  /// supplied by the client, it is a convenience check, not a strong
  /// authentication of the email.
  final email = CvField<String>('email');

  @override
  late final CvFields fields = [inviteId, entityId, email];
}

/// API result for accepting a CMS entity invite.
typedef FsCmsEntityAcceptInviteApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityCreateInviteApiResult<T>;

/// API query for deleting a CMS entity invite.
typedef FsCmsEntityDeleteInviteApiQuery<T extends TkCmsFsEntity> =
    FsCmsEntityAcceptInviteApiQuery<T>;

/// API result for deleting a CMS entity invite.
typedef FsCmsEntityDeleteInviteApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityAcceptInviteApiResult<T>;

/// API query for making a CMS entity public — readable by anyone, signed in
/// or not, through its `public_access/public` flag (`TkCmsFsPublicAccess`) —
/// or private again.
///
/// Server side, only an admin of the entity may do it, and the app may add a
/// condition of its own (`FestenaoEntityHandlerOptions.setPublicCheck`).
class FsCmsEntitySetPublicApiQuery<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiQuery {
  /// True to make the entity public, false to make it private again.
  final public = CvField<bool>('public');

  @override
  CvFields get fields => [...super.fields, public];
}

/// API result for making a CMS entity public: the state it ended up in.
class FsCmsEntitySetPublicApiResult<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiResult {
  /// Whether the entity is public now.
  final public = CvField<bool>('public');

  @override
  CvFields get fields => [...super.fields, public];
}

/// Base class for API queries and results naming an email invite of an
/// entity.
class FsCmsEntityEmailInviteIdBaseApiCommon<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T> {
  /// The invite ID.
  late final inviteId = CvField<String>('inviteId');

  @override
  CvFields get fields => [...super.fields, inviteId];
}

/// API query for creating an addressed email invite (`TkCmsFsEmailInvite`):
/// only the user whose verified email is [email] can accept it, after
/// finding it with the check command.
///
/// Server side, only an admin of the entity or a global app admin may do it,
/// and the granted access cannot exceed the inviter's own. Inviting the same
/// email again updates the pending invite.
class FsCmsEntityCreateEmailInviteApiQuery<T extends TkCmsFsEntity>
    extends ApiQuery
    with TkCmsCvUserAccessMixin {
  /// The entity ID.
  final entityId = CvField<String>('entityId');

  /// The invited email.
  final email = CvField<String>('email');

  @override
  late final CvFields fields = [entityId, email, ...userAccessFields];
}

/// API result for creating an addressed email invite: its id, the normalized
/// email, and whether the invite mail went ([mailSent], false when the app
/// sends none or when it failed: the invite exists either way, the invitee
/// finds it in the app).
class FsCmsEntityCreateEmailInviteApiResult<T extends TkCmsFsEntity>
    extends ApiResult {
  /// The invite ID.
  final inviteId = CvField<String>('inviteId');

  /// The invited email (normalized).
  final email = CvField<String>('email');

  /// True when the invite mail was sent.
  final mailSent = CvField<bool>('mailSent');

  @override
  late final CvFields fields = [inviteId, email, mailSent];
}

/// API query for listing the email invites of an entity (entity admin or app
/// admin).
class FsCmsEntityListEmailInvitesApiQuery<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiQuery {
  /// Only the invites with this status (`pending`, `accepted`, `discarded`),
  /// all of them when null.
  final status = CvField<String>('status');

  @override
  CvFields get fields => [...super.fields, status];
}

/// API result for listing the email invites of an entity.
class FsCmsEntityListEmailInvitesApiResult<T extends TkCmsFsEntity>
    extends ApiResult {
  /// The invites, most recent first.
  final invites = CvModelListField<TkCmsCvEmailInvite>('invites');

  @override
  late final CvFields fields = [invites];
}

/// API query naming an email invite of an entity (delete, accept, discard).
class FsCmsEntityEmailInviteIdApiQuery<T extends TkCmsFsEntity>
    extends FsCmsEntityEmailInviteIdBaseApiCommon<T>
    implements ApiQuery {}

/// API result naming the email invite acted upon.
class FsCmsEntityEmailInviteIdApiResult<T extends TkCmsFsEntity>
    extends FsCmsEntityEmailInviteIdBaseApiCommon<T>
    implements ApiResult {}

/// API query for deleting (revoking) an email invite.
typedef FsCmsEntityDeleteEmailInviteApiQuery<T extends TkCmsFsEntity> =
    FsCmsEntityEmailInviteIdApiQuery<T>;

/// API result for deleting (revoking) an email invite.
typedef FsCmsEntityDeleteEmailInviteApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityEmailInviteIdApiResult<T>;

/// API query for accepting an email invite (the invitee).
typedef FsCmsEntityAcceptEmailInviteApiQuery<T extends TkCmsFsEntity> =
    FsCmsEntityEmailInviteIdApiQuery<T>;

/// API result for accepting an email invite.
typedef FsCmsEntityAcceptEmailInviteApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityEmailInviteIdApiResult<T>;

/// API query for discarding an email invite (the invitee).
typedef FsCmsEntityDiscardEmailInviteApiQuery<T extends TkCmsFsEntity> =
    FsCmsEntityEmailInviteIdApiQuery<T>;

/// API result for discarding an email invite.
typedef FsCmsEntityDiscardEmailInviteApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityEmailInviteIdApiResult<T>;

/// API query for checking the pending email invites addressed to the signed
/// in user, on app start and after login; optionally only the ones of
/// [entityId].
class FsCmsEntityCheckEmailInvitesApiQuery<T extends TkCmsFsEntity>
    extends ApiQuery {
  /// Only the invites of this entity, when set.
  final entityId = CvField<String>('entityId');

  @override
  late final CvFields fields = [entityId];
}

/// API result of the check: the user email, whether it is verified (no
/// invite is listed otherwise, and none can be accepted until then) and the
/// pending invites addressed to it.
class FsCmsEntityCheckEmailInvitesApiResult<T extends TkCmsFsEntity>
    extends ApiResult {
  /// The user email (normalized), null when the account has none.
  final email = CvField<String>('email');

  /// Whether the user email is verified.
  final emailVerified = CvField<bool>('emailVerified');

  /// The pending invites, most recent first.
  final invites = CvModelListField<TkCmsCvEmailInvite>('invites');

  @override
  late final CvFields fields = [email, emailVerified, invites];
}

/// API query for reading the account information of [userId] (its name and
/// email in the auth service) to fill an access being edited.
///
/// Server side: an app admin reads any user; an admin of [entityId] reads the
/// users that have an access to it; anyone else gets `permission-denied`.
class FsCmsEntityGetUserInfoApiQuery<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiQuery {
  /// The user whose information is read.
  final userId = CvField<String>('userId');

  @override
  CvFields get fields => [...super.fields, userId];
}

/// API result for reading the account information of a user.
class FsCmsEntityGetUserInfoApiResult<T extends TkCmsFsEntity>
    extends ApiResult {
  /// The user.
  final userId = CvField<String>('userId');

  /// Its display name, null when none is set.
  final name = CvField<String>('name');

  /// Its email, null when none is set.
  final email = CvField<String>('email');

  /// Whether its email is verified.
  final emailVerified = CvField<bool>('emailVerified');

  /// Whether the account is disabled.
  final disabled = CvField<bool>('disabled');

  /// Whether the user has an access to the entity.
  final hasAccess = CvField<bool>('hasAccess');

  @override
  late final CvFields fields = [
    userId,
    name,
    email,
    emailVerified,
    disabled,
    hasAccess,
  ];
}
