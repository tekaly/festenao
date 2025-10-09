import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Command name for creating an entity.
const festenaoCreateEntityCommand = 'create-entity';

/// Command name for deleting an entity.
const festenaoDeleteEntityCommand = 'delete-entity';

/// Command name for purging an entity.
const festenaoPurgeEntityCommand = 'purge-entity';

/// Command name for joining an entity.
const festenaoJoinEntityCommand = 'join-entity';

/// Command name for leaving an entity.
const festenaoLeaveEntityCommand = 'leave-entity';

/// Initializes API builders for Festenao file system entities.
void initFestenaoFsEntityApiBuilders<T extends TkCmsFsEntity>() {
  cvAddConstructors([
    FsCmsEntityCreateApiQuery<T>.new,
    FsCmsEntityCreateApiResult<T>.new,
    FsCmsEntityDeleteApiQuery<T>.new,
    FsCmsEntityDeleteApiResult<T>.new,
    FsCmsEntityJoinApiQuery<T>.new,
  ]);
}

/// Extension for [TkCmsFirestoreDatabaseEntityCollectionInfo] to provide API command names.
extension FestenaoFirestoreDatabaseEntityCollectionInfoApiExt<
  TEntity extends TkCmsFsEntity
>
    on TkCmsFirestoreDatabaseEntityCollectionInfo<TEntity> {
  String _command(String subCommand) => '$id-$subCommand';

  /// Command for creating an entity.
  String get createCommand => _command(festenaoCreateEntityCommand);

  /// Command for deleting an entity.
  String get deleteCommand => _command(festenaoDeleteEntityCommand);

  /// Command for purging an entity.
  String get purgeCommand => _command(festenaoPurgeEntityCommand);

  /// Command for joining an entity.
  String get joinCommand => _command(festenaoJoinEntityCommand);

  /// Command for leaving an entity.
  String get leaveCommand => _command(festenaoLeaveEntityCommand);
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
  @override
  CvFields get fields => [...super.fields, entity];
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
