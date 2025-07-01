import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Create entity
const festenaoCreateEntityCommand = 'create-entity';

/// Delete entity
const festenaoDeleteEntityCommand = 'delete-entity';

/// Purge entity
const festenaoPurgeEntityCommand = 'purge-entity';

/// Init api builder
void initFestenaoEntityApiBuilders<T extends TkCmsFsEntity>() {
  cvAddConstructors([
    FsCmsEntityCreateApiQuery<T>.new,
    FsCmsEntityCreateApiResult<T>.new,
    FsCmsEntityDeleteApiQuery<T>.new,
    FsCmsEntityDeleteApiResult<T>.new,
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
  final data = CvField<Map>('data');
  @override
  CvFields get fields => [...super.fields, data];
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

class FsCmsEntityEntityIdBaseApiCommon<T extends TkCmsFsEntity>
    extends ApiCommonBase {
  late final entityId = CvField<String>('entityId');

  @override
  CvFields get fields => [entityId];
}
