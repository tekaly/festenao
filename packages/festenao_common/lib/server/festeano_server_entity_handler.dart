import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_firebase_firestore/utils/json_utils.dart';
import 'package:tkcms_common/tkcms_server.dart';

import 'festeano_server_app.dart';

/// Options for entity handler.
class FestenaoEntityHandlerOptions {
  /// Creates a new [FestenaoEntityHandlerOptions] with optional [customIdGenerator].
  const FestenaoEntityHandlerOptions({this.customIdGenerator});

  /// Custom ID generator function.
  final String Function()? customIdGenerator;
}

/// Entity handler for Festenao entities.
class FestenaoEntityHandler<T extends TkCmsFsEntity> {
  /// Options for the handler.
  final FestenaoEntityHandlerOptions options;

  /// The server app.
  final FestenaoServerApp app;

  /// Entity access for Firestore operations.
  final TkCmsFirestoreDatabaseServiceEntityAccess<T> entityAccess;

  /// Firestore instance.
  Firestore get firestore => entityAccess.firestore;

  String get _collectionIdPrefix =>
      _buildCollectionIdPrefix(entityAccess.entityCollectionInfo.id);
  static String _buildCollectionIdPrefix(String entityCollectionId) =>
      '$entityCollectionId-';

  /// Checks if the [command] is an entity command for the given [entity].
  static bool isEntityCommand(String entity, String command) {
    return command.startsWith(_buildCollectionIdPrefix(entity));
  }

  /// Creates a new [FestenaoEntityHandler] with the given [app], [entityAccess], and [options].
  FestenaoEntityHandler({
    required this.app,
    required this.entityAccess,
    this.options = const FestenaoEntityHandlerOptions(),
  });

  /// Handles the command if it's an entity command, otherwise returns null.
  Future<ApiResult?> onCommandOrNull(ApiRequest apiRequest) async {
    var command = apiRequest.command.v!;
    if (command.startsWith(_collectionIdPrefix)) {
      var subCommand = command.substring(_collectionIdPrefix.length);
      switch (subCommand) {
        case festenaoCreateEntityCommand:
          return await onCreateCommand(apiRequest);
        case festenaoDeleteEntityCommand:
          return await onDeleteCommand(apiRequest);
        case festenaoPurgeEntityCommand:
          return await onPurgeCommand(apiRequest);
        case festenaoJoinEntityCommand:
          return await onJoinCommand(apiRequest);
        case festenaoLeaveEntityCommand:
          return await onLeaveCommand(apiRequest);
        default:
      }
    }
    return null;
  }

  /// Handles the create entity command.
  Future<FsCmsEntityCreateApiResult> onCreateCommand(
    ApiRequest apiRequest,
  ) async {
    {
      var query = apiRequest.query<FsCmsEntityCreateApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v;
      if (userId == null) {
        throw StateError('Missing userId');
      }
      var entityId = query.entityId.v;
      //var entity = entityAccess.fsEntityRef(entityId).cv()..fsDataFromJsonMap(firestore, query.data.v!);
      var model = documentDataMapFromJsonMap(firestore, asModel(query.data.v!));
      var entity = model.cv<T>();
      entityId = await entityAccess.createEntity(
        userId: userId,
        entity: entity,
        entityId: entityId,
        customIdGenerator: options.customIdGenerator,
      );
      var result = FsCmsEntityCreateApiResult()
        ..entityId.setValue(entityId)
        ..entity.v = entity.fsDataToJsonMap();
      return result;
    }
  }

  /// Handles the delete entity command.
  Future<FsCmsEntityDeleteApiResult> onDeleteCommand(
    ApiRequest apiRequest,
  ) async {
    {
      var query = apiRequest.query<FsCmsEntityDeleteApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v!;
      var entityId = query.entityId.v!;
      await entityAccess.deleteEntity(entityId, userId: userId);

      var result = FsCmsEntityDeleteApiResult()..entityId.setValue(entityId);
      return result;
    }
  }

  /// Handles the purge entity command.
  Future<FsCmsEntityPurgeApiResult> onPurgeCommand(
    ApiRequest apiRequest,
  ) async {
    {
      var query = apiRequest.query<FsCmsEntityPurgeApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v!;
      var entityId = query.entityId.v!;
      await entityAccess.purgeEntity(entityId, userId: userId);

      var result = FsCmsEntityPurgeApiResult()..entityId.setValue(entityId);
      return result;
    }
  }

  /// Handles the join entity command.
  Future<FsCmsEntityJoinApiResult> onJoinCommand(ApiRequest apiRequest) async {
    {
      var query = apiRequest.query<FsCmsEntityJoinApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v!;
      var entityId = query.entityId.v!;
      var model = documentDataMapFromJsonMap(
        firestore,
        asModel(query.access.v!),
      );
      var userAccess = model.cv<TkCmsFsUserAccess>();
      await entityAccess.joinEntity(
        entityId: entityId,
        userId: userId,
        userAccess: userAccess,
      );

      var result = FsCmsEntityJoinApiResult()..entityId.setValue(entityId);
      return result;
    }
  }

  /// Handles the leave entity command.
  Future<FsCmsEntityLeaveApiResult> onLeaveCommand(
    ApiRequest apiRequest,
  ) async {
    {
      var query = apiRequest.query<FsCmsEntityLeaveApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v!;
      var entityId = query.entityId.v!;
      await entityAccess.leaveEntity(entityId, userId: userId);

      var result = FsCmsEntityLeaveApiResult()..entityId.setValue(entityId);
      return result;
    }
  }
}
