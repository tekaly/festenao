import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Client for managing Festenao CMS entities via API and Firestore.
class FestenaoApiFsEntityClient<T extends TkCmsFsEntity> {
  /// The API service used for CMS operations.
  final FestenaoApiService apiService;

  /// The entity access service for Firestore operations.
  final TkCmsFirestoreDatabaseServiceEntityAccess<T> entityAccess;

  /// Creates a new [FestenaoApiFsEntityClient] instance.
  FestenaoApiFsEntityClient({
    required this.apiService,
    required this.entityAccess,
  });

  /// Creates a new entity in the CMS and returns the created entity.
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

  /// Deletes an entity by [entityId]. Always succeeds (ok if not exists).
  Future<void> deleteEntity({required String entityId}) async {
    await apiService.getApiResult<FsCmsEntityDeleteApiResult<T>>(
      ApiRequest(command: entityAccess.info.deleteCommand)
        ..setQuery(FsCmsEntityDeleteApiQuery<T>()..entityId.setValue(entityId)),
    );
  }

  /// Purges an entity by [entityId]. Always succeeds (ok if not exists).
  Future<void> purgeEntity({required String entityId}) async {
    await apiService.getApiResult<FsCmsEntityPurgeApiResult<T>>(
      ApiRequest(command: entityAccess.info.purgeCommand)
        ..setQuery(FsCmsEntityPurgeApiQuery<T>()..entityId.setValue(entityId)),
    );
  }

  /// Joins an entity by [entityId] with the given [fsUserAccess]. Always succeeds (ok if not exists).
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

  /// Leaves an entity by [entityId]. Always succeeds (ok if not exists).
  Future<void> leaveEntity({required String entityId}) async {
    await apiService.getApiResult<FsCmsEntityLeaveApiResult<T>>(
      ApiRequest(command: entityAccess.info.leaveCommand)
        ..setQuery(FsCmsEntityLeaveApiQuery<T>()..entityId.setValue(entityId)),
    );
  }
}
