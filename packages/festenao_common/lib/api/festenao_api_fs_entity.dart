import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Create entity
const festenaoCreateEntityCommand = 'create-entity';

/// Delete entity
const festenaoDeleteEntityCommand = 'delete-entity';

/// Purge entity
const festenaoPurgeEntityCommand = 'purge-entity';

/// join entity
const festenaoJoinEntityCommand = 'join-entity';

/// leave entity
const festenaoLeaveEntityCommand = 'leave-entity';

/// Init api builder
void initFestenaoFsEntityApiBuilders<T extends TkCmsFsEntity>() {
  cvAddConstructors([
    FsCmsEntityCreateApiQuery<T>.new,
    FsCmsEntityCreateApiResult<T>.new,
    FsCmsEntityDeleteApiQuery<T>.new,
    FsCmsEntityDeleteApiResult<T>.new,
    FsCmsEntityJoinApiQuery<T>.new,
  ]);
}

/// Info extension for the api
extension FestenaoFirestoreDatabaseEntityCollectionInfoApiExt<
  TEntity extends TkCmsFsEntity
>
    on TkCmsFirestoreDatabaseEntityCollectionInfo<TEntity> {
  String _command(String subCommand) => '$id-$subCommand';
  String get createCommand => _command(festenaoCreateEntityCommand);
  String get deleteCommand => _command(festenaoDeleteEntityCommand);
  String get purgeCommand => _command(festenaoPurgeEntityCommand);
  String get joinCommand => _command(festenaoJoinEntityCommand);
  String get leaveCommand => _command(festenaoLeaveEntityCommand);
}

class FsCmsEntityCreateApiQuery<T extends TkCmsFsEntity> extends ApiQuery {
  final entityId = CvField<String>('entityId');

  final data = CvField<Map>('data');

  @override
  late final CvFields fields = [entityId, data];
}

class FsCmsEntityCreateApiResult<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon
    implements ApiResult {
  final entity = CvField<Map>('entity');
  @override
  CvFields get fields => [...super.fields, entity];
}

class FsCmsEntityDeleteApiQuery<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiQuery {}

class FsCmsEntityDeleteApiResult<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiResult {}

typedef FsCmsEntityPurgeApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiResult<T>;
typedef FsCmsEntityPurgeApiQuery<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiQuery<T>;
typedef FsCmsEntityJoinApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiResult<T>;

class FsCmsEntityJoinApiQuery<T extends TkCmsFsEntity>
    extends FsCmsEntityEntityIdBaseApiCommon<T>
    implements ApiQuery {
  /// Data being a user access
  final access = CvField<Map>('access');
  @override
  CvFields get fields => [...super.fields, access];
}

typedef FsCmsEntityLeaveApiResult<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiResult<T>;
typedef FsCmsEntityLeaveApiQuery<T extends TkCmsFsEntity> =
    FsCmsEntityDeleteApiQuery<T>;

class FsCmsEntityEntityIdBaseApiCommon<T extends TkCmsFsEntity>
    extends ApiCommonBase {
  late final entityId = CvField<String>('entityId');

  @override
  CvFields get fields => [entityId];
}
