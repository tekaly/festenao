import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firestore.dart';

/// Client for managing Festenao CMS entities via API and Firestore.
class FestenaoApiFsEntityClient<T extends TkCmsFsEntity> {
  /// The API service used for CMS operations.
  final FestenaoApiService apiService;

  /// The entity access service for Firestore operations.
  /// firestore is not used as an accessor here but for data conversion
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

  /// Creates a new invite for the entity. Returns the invite ID.
  Future<String> createEntityInvite({
    required String entityId,
    required TkCmsFsUserAccess fsUserAccess,
  }) async {
    var result = await apiService
        .getApiResult<FsCmsEntityCreateInviteApiResult<T>>(
          ApiRequest(command: entityAccess.info.createInviteCommand)..setQuery(
            FsCmsEntityCreateInviteApiQuery<T>()
              ..entityId.setValue(entityId)
              ..write.v = fsUserAccess.write.v
              ..admin.v = fsUserAccess.admin.v
              ..read.v = fsUserAccess.read.v,
          ),
        );
    return result.inviteId.v!;
  }

  /// Accepts an invite for the entity.
  Future<void> acceptEntityInvite({
    required String entityId,
    required String inviteId,
  }) async {
    await apiService.getApiResult<FsCmsEntityAcceptInviteApiResult<T>>(
      ApiRequest(command: entityAccess.info.acceptInviteCommand)..setQuery(
        FsCmsEntityAcceptInviteApiQuery<T>()
          ..entityId.setValue(entityId)
          ..inviteId.setValue(inviteId),
      ),
    );
  }

  /// Deletes an invite for the entity.
  Future<void> deleteEntityInvite({
    required String entityId,
    required String inviteId,
  }) async {
    await apiService.getApiResult<FsCmsEntityDeleteInviteApiResult<T>>(
      ApiRequest(command: entityAccess.info.deleteInviteCommand)..setQuery(
        FsCmsEntityDeleteInviteApiQuery<T>()
          ..entityId.setValue(entityId)
          ..inviteId.setValue(inviteId),
      ),
    );
  }
}
