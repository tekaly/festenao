import 'package:festenao_common/amp/amp_page.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_firebase_firestore/utils/json_utils.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// Our server app
class FestenaoServerApp extends TkAppCmsServerAppBase {
  late String ampCommand;
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

  Future<void> onHttpsAmp(ExpressHttpRequest request) async {
    var incomingRequest = IncomingAmpRequest(request: request);
    await onAmp(incomingRequest);
  }

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

class IncomingAppAmpRequest extends IncomingAmpRequest {
  IncomingAppAmpRequest({
    required super.request,
    required this.app,
    super.path,
  });

  final String app;
}

class IncomingAmpRequest implements AmpRequest {
  final ExpressHttpRequest request;
  @override
  late final String path;
  Uri get uri => request.uri;
  IncomingAmpRequest({required this.request, String? path}) {
    var requestPath = path ?? uri.path;
    if (requestPath.startsWith('/')) {
      requestPath = requestPath.substring(1);
    }
    this.path = requestPath;
  }
}

extension FesteanoServerAppExt on FestenaoServerApp {
  void initEntityFunctions<TFsEntity extends TkCmsFsEntity>(
    FestenaoEntityHandler<TkCmsFsEntity> entityHandler,
  ) {}
}

class FestenaoEntityHandler<T extends TkCmsFsEntity> {
  final FestenaoServerApp app;
  final TkCmsFirestoreDatabaseServiceEntityAccess<T> entityAccess;
  Firestore get firestore => entityAccess.firestore;

  String get _collectionIdPrefix =>
      _buildCollectionIdPrefix(entityAccess.entityCollectionInfo.id);
  static String _buildCollectionIdPrefix(String entityCollectionId) =>
      '$entityCollectionId-';

  /// True if onCommandOrNull should be called
  static bool isEntityCommand(String entity, String command) {
    return command.startsWith(_buildCollectionIdPrefix(entity));
  }

  FestenaoEntityHandler({required this.app, required this.entityAccess});

  /// Returns null if not handled
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
        default:
      }
    }
    return null;
  }

  Future<FsCmsEntityCreateApiResult> onCreateCommand(
    ApiRequest apiRequest,
  ) async {
    {
      var query = apiRequest.query<FsCmsEntityCreateApiQuery<T>>()
        ..fromMap(apiRequest.data.v!);
      var userId = apiRequest.userId.v!;
      var entityId = query.entityId.v;
      //var entity = entityAccess.fsEntityRef(entityId).cv()..fsDataFromJsonMap(firestore, query.data.v!);
      var model = documentDataMapFromJsonMap(firestore, asModel(query.data.v!));
      var entity = model.cv<T>();
      entityId = await entityAccess.createEntity(
        userId: userId,
        entity: entity,
        entityId: entityId,
      );

      var result = FsCmsEntityCreateApiResult()
        ..entityId.setValue(entityId)
        ..data.v = entity.fsDataToJsonMap();
      return result;
    }
  }

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
}
