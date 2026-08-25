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

/// Initializes API builders for Festenao file system entities.
void initFestenaoFsEntityApiBuilders<T extends TkCmsFsEntity>() {
  cvAddConstructors([
    FsCmsEntityCreateApiQuery<T>.new,
    FsCmsEntityCreateApiResult<T>.new,
    FsCmsEntityDeleteApiQuery<T>.new,
    FsCmsEntityDeleteApiResult<T>.new,
    FsCmsEntityJoinApiQuery<T>.new,
    FsCmsEntityCreateInviteApiQuery<T>.new,
    FsCmsEntityCreateInviteApiResult<T>.new,
    FsCmsEntityAcceptInviteApiQuery<T>.new,
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
