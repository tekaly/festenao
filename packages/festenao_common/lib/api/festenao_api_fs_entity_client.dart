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
    var jsonMap = result.entity.v!;
    var resultEntityId = result.entityId.v!;

    return entityAccess.fsEntityRef(resultEntityId).cv()
      ..fsDataFromJsonMap(entityAccess.firestore, jsonMap);
  }

  /// Always succeed (ok if not exists)
  Future<void> deleteEntity({required String entityId}) async {
    await apiService.getApiResult<FsCmsEntityDeleteApiResult<T>>(
      ApiRequest(command: entityAccess.info.deleteCommand)
        ..setQuery(FsCmsEntityDeleteApiQuery<T>()..entityId.setValue(entityId)),
    );
  }

  /// Always succeed (ok if not exists)
  Future<void> purgeEntity({required String entityId}) async {
    await apiService.getApiResult<FsCmsEntityPurgeApiResult<T>>(
      ApiRequest(command: entityAccess.info.purgeCommand)
        ..setQuery(FsCmsEntityPurgeApiQuery<T>()..entityId.setValue(entityId)),
    );
  }

  /// Always succeed (ok if not exists)
  Future<void> joinEntity({
    required String entityId,
    required TkCmsFsUserAccess fsUserAccess,
  }) async {
    await apiService.getApiResult<FsCmsEntityJoinApiResult<T>>(
      ApiRequest(command: entityAccess.info.joinCommand)..setQuery(
        FsCmsEntityJoinApiQuery<T>()
          ..entityId.setValue(entityId)
          ..access.v = fsUserAccess.fsDataToJsonMap(),
      ),
    );
  }

  /// Always succeed (ok if not exists)
  Future<void> leaveEntity({required String entityId}) async {
    await apiService.getApiResult<FsCmsEntityLeaveApiResult<T>>(
      ApiRequest(command: entityAccess.info.leaveCommand)
        ..setQuery(FsCmsEntityLeaveApiQuery<T>()..entityId.setValue(entityId)),
    );
  }
}
