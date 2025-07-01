import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

const festenaoCreateEntityCommand = 'create-entity';

/// Info extension for the api
extension FestenaoFirestoreDatabaseEntityCollectionInfoApiExt<
  TEntity extends TkCmsFsEntity
>
    on TkCmsFirestoreDatabaseEntityCollectionInfo<TEntity> {
  String get createCommand => '$id-$festenaoCreateEntityCommand';
}

class FsCmsEntityCreateApiQuery<T extends TkCmsFsEntity> extends ApiQuery {
  final entityId = CvField<String>('entityId');

  final data = CvField<Map>('data');

  @override
  late final CvFields fields = [entityId, data];
}

class FsCmsEntityCreateApiResult<T extends TkCmsFsEntity> extends ApiResult {
  late final entityId = CvField<String>('entityId');
  final data = CvField<Map>('data');
  @override
  late final CvFields fields = [entityId, data];
}
