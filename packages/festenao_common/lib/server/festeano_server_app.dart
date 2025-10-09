import 'package:festenao_common/amp/amp_page.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_firebase_firestore/utils/json_utils.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// Server app for Festenao CMS.
class FestenaoServerApp extends TkAppCmsServerAppBase {
  /// AMP command name.
  late String ampCommand;

  /// Creates a new [FestenaoServerApp] with the given [app], [context], and optional [version].
  FestenaoServerApp({
    String app = 'festenao',
    required super.context,
    super.version,
  }) : super(app, apiVersion: apiVersion2);

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    switch (apiRequest.command.v!) {
      default:
        return super.onCommand(apiRequest);
    }
  }

  /// Handles HTTPS AMP requests.
  Future<void> onHttpsAmp(ExpressHttpRequest request) async {
    var incomingRequest = IncomingAmpRequest(request: request);
    await onAmp(incomingRequest);
  }

  /// Handles AMP requests.
  Future<void> onAmp(IncomingAmpRequest ampRequest) async {
    var requestPath = ampRequest.path;
    var request = ampRequest.request;
    return onAppAmp(
      IncomingAppAmpRequest(request: request, app: app, path: requestPath),
    );
    /*
    // ignore: dead_code
    var parts = requestPath.split('/');
    var first = parts.first;
    if (first == 'app') {}
    try {
      print('$requestPath: requestPath');

      await sendHtml(request, '''OKd
      ''');
    } catch (e, st) {
      await sendHtml(request, ''''ERROR $e
      $st
      ''');
    }*/
  }

  /// Handles app-specific AMP requests.
  Future<void> onAppAmp(IncomingAppAmpRequest appAmpRequest) async {
    var requestPath = appAmpRequest.path;
    var request = appAmpRequest.request;
    var app = appAmpRequest.app;
    try {
      // print('requestPath: $requestPath');
      var page = FestenaoAmpPage();
      page.consoleAdd('app: $app');
      page.consoleAdd('requestPath: $requestPath');
      await sendHtml(request, await page.build());
    } catch (e, st) {
      var page = FestenaoAmpPage();
      page.consoleAdd('app: $app');
      page.consoleAdd('requestPath: $requestPath');
      page.consoleAdd('Error $e');
      page.consoleAdd('Stack trace $st');
      await sendHtml(request, await page.build());
    }
  }

  /// Gets the AMP HTTPS function.
  HttpsFunction get amp => functions.https.onRequestV2(
    HttpsOptions(cors: true, region: regionBelgium),
    onHttpsAmp,
  );
  @override
  void initFunctions() {
    ampCommand = 'amp${flavorContext.ifNotProdFlavor}';
    super.initFunctions();
    functions[ampCommand] = amp;
  }
}

/// Incoming request for app-specific AMP.
class IncomingAppAmpRequest extends IncomingAmpRequest {
  /// Creates a new [IncomingAppAmpRequest] with the given [request], [app], and optional [path].
  IncomingAppAmpRequest({
    required super.request,
    required this.app,
    super.path,
  });

  /// The app name.
  final String app;
}

/// Incoming request for AMP.
class IncomingAmpRequest implements AmpRequest {
  /// The HTTP request.
  final ExpressHttpRequest request;

  @override
  late final String path;

  /// The URI of the request.
  Uri get uri => request.uri;

  /// Creates a new [IncomingAmpRequest] with the given [request] and optional [path].
  IncomingAmpRequest({required this.request, String? path}) {
    var requestPath = path ?? uri.path;
    if (requestPath.startsWith('/')) {
      requestPath = requestPath.substring(1);
    }
    this.path = requestPath;
  }
}

/// Extension for [FestenaoServerApp] to initialize entity functions.
extension FesteanoServerAppExt on FestenaoServerApp {
  /// Initializes entity functions for the given [entityHandler].
  void initEntityFunctions<TFsEntity extends TkCmsFsEntity>(
    FestenaoEntityHandler<TkCmsFsEntity> entityHandler,
  ) {}
}

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
