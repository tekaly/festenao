import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

class FestenaoApiFsEntityClient<T extends TkCmsFsEntity> {
  final FestenaoApiService apiService;
  final TkCmsFirestoreDatabaseServiceEntityAccess<T> entityAccess;

  FestenaoApiFsEntityClient({
    required this.apiService,
    required this.entityAccess,
  });

  Future<T> createEntity({required T entity, String? entityId}) async {
    var result = await apiService.getApiResult<FsCmsEntityCreateApiResult<T>>(
      ApiRequest(command: entityAccess.info.createCommand)..setQuery(
        FsCmsEntityCreateApiQuery<T>()
          ..entityId.setValue(entityId)
          ..data.v = entity.fsDataToJsonMap(),
      ),
    );
    var jsonMap = result.data.v!;
    var resultEntityId = result.entityId.v!;

    return entityAccess.fsEntityRef(resultEntityId).cv()
      ..fsDataFromJsonMap(entityAccess.firestore, jsonMap);
  }
}
