import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/server/festeano_server_app.dart';
import 'package:tekartik_firebase_functions/ff_server.dart';
import 'package:tkcms_common/tkcms_app.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// Festenao server app for test.
class FestenaoServerAppTest extends FestenaoServerApp {
  /// Festenao server app for test.
  FestenaoServerAppTest({required super.context, super.app}) {
    initFestenaoFsEntityApiBuilders<FsProject>();
  }

  /// Firestore database.
  late var fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: this.firebaseContext,
    flavorContext: appFlavorContext,
  );

  /// Project handler.
  late final projectHandler = FestenaoEntityHandler(
    app: this,
    entityAccess: fsDatabase.projectDb,
  );

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    var command = apiRequest.apiCommand;
    if (FestenaoEntityHandler.isEntityCommand(
      projectCollectionInfo.id,
      command,
    )) {
      var result = await projectHandler.onCommandOrNull(apiRequest);
      if (result != null) {
        return result;
      }
    }
    return super.onCommand(apiRequest);
  }
}

/// Test api context.
class FestenaoTestApiContext {
  /// Api service.
  final FestenaoApiService apiService;

  /// Project api client.
  late final FestenaoApiFsEntityClient<FsProject> projectApiClient;

  /// Test api context.
  FestenaoTestApiContext({required this.apiService});

  /// Close context.
  @mustCallSuper
  Future<void> close() async {
    await apiService.close();
  }
}

/// Test amp context.
class FestenaoTestAmpContext {
  /// Amp service.
  final FestenaoAmpService ampService;

  /// Constructor for [FestenaoTestAmpContext].
  FestenaoTestAmpContext({required this.ampService});

  /// Close context.
  @mustCallSuper
  Future<void> close() async {
    await ampService.close();
  }
}

/// Test ff server context.
class FestenaoTestFfServerContext {
  /// The ff server.
  final FfServer? ffServer;

  /// Test server context.
  FestenaoTestFfServerContext({required this.ffServer});

  /// Close context.
  @mustCallSuper
  Future<void> close() async {
    await ffServer?.close();
  }
}

/// Test server context.
class FestenaoTestServerContext
    implements
        FestenaoTestApiContext,
        FestenaoTestAmpContext,
        FestenaoTestFfServerContext {
  @override
  final FestenaoApiService apiService;
  @override
  final FestenaoAmpService ampService;
  @override
  final FfServer? ffServer;
  @override
  late final FestenaoApiFsEntityClient<FsProject> projectApiClient;

  /// Firestore database.
  late final FestenaoFirestoreDatabase fsDatabase;

  /// Firebase context.
  late final FirebaseContext ffContext;

  /// Test server context.
  FestenaoTestServerContext({
    required this.apiService,
    this.ffServer,
    required this.ampService,
  }) {
    initFestenaoFsEntityApiBuilders<FsProject>();
  }

  @override
  Future<void> close() async {
    //await ffServer.close();
    await apiService.close();
    await ffServer?.close();
    await ampService.close();
  }
}

/// Init all in memory.
Future<FestenaoTestServerContext> initFestenaoAllMemory() async {
  var ffServicesContext = await initFirebaseServicesSimMemory();
  var ffServerContext = await ffServicesContext.initServer();

  var httpClientFactory = httpClientFactoryMemory;
  var ff = ffServerContext.functions;
  var serverAppContext = TkCmsServerAppContext(
    firebaseContext: ffServerContext,
    flavorContext: FlavorContext.test,
  );
  var ffServerApp = FestenaoServerAppTest(context: serverAppContext);
  ffServerApp.initFunctions();
  //var httpServer = await ff.serveHttp();
  //var ffServer = FfServerHttp(httpServer);
  var ffServer = await ff.serve();
  var ffContext = firebaseFunctionsContextSimOrNull = await ffServicesContext
      .init(
        firebaseApp: ffServerContext.firebaseApp,
        ffServer: ffServer,
        serverApp: ffServerApp,
      );

  await ffContext.auth.signInWithEmailAndPassword(
    email: 'test',
    password: 'test',
  );
  var commandUri = ffServer.uri.replace(path: ffServerApp.command);
  var apiService = FestenaoApiService(
    callableApi: ffContext.functionsCall.callable(ffServerApp.callCommand),
    httpClientFactory: httpClientFactory,
    httpsApiUri: commandUri,
    app: tkCmsAppDev,
  );
  var fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: ffContext,
    flavorContext: ffServerApp.appFlavorContext,
  );
  var projectApiClient = FestenaoApiFsEntityClient(
    apiService: apiService,
    entityAccess: fsDatabase.projectDb,
  );
  await apiService.initClient();
  var ampUri = ffServer.uri.replace(path: ffServerApp.ampCommand);
  var ampService = FestenaoAmpService(
    httpsAmpUri: ampUri,
    httpClientFactory: httpClientFactory,
  );
  await ampService.initClient();

  return FestenaoTestServerContext(
      apiService: apiService,
      ffServer: ffServer,
      ampService: ampService,
    )
    ..projectApiClient = projectApiClient
    ..fsDatabase = fsDatabase
    ..ffContext = ffContext;
}

Future<void> main() async {
  debugWebServices = true;
  testFestenaoServerGroup(initFestenaoAllMemory);
}

/// Test server group.
void testFestenaoServerGroup(
  Future<FestenaoTestServerContext> Function() initAllContext, {
  bool noFirestoreCheck = false,
  bool noSignIn = false,
}) {
  late FestenaoTestServerContext context;
  late FestenaoApiService apiService;
  late FestenaoAmpService ampService;
  setUpAll(() async {
    context = await initAllContext();
    apiService = context.apiService;
    ampService = context.ampService;
  });
  tearDownAll(() async {
    await context.close();
  });

  test('amp', () async {
    var response = await ampService.client.get(ampService.pathUri(''));
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], 'text/html; charset=utf-8');
  });

  test('callTimestamp', () async {
    if (apiService.callableApi != null) {
      var timestamp = await apiService.callGetTimestamp();
      expect(Timestamp.tryParse(timestamp.timestamp.v!), isNotNull);
      // ignore: avoid_print
      print(timestamp);
    }
  });
  test('echo', () async {
    var timestamp = (await apiService.getTimestamp()).timestamp.v!;
    var result = await apiService.echo(
      ApiEchoQuery()
        ..data.v = {'message': 'hello'}
        ..timestamp.v = timestamp,
    );
    expect(result.data.v, {'message': 'hello'});
    expect(result.timestamp.v, timestamp);
  });

  test('timestamp', () async {
    var timestamp = await apiService.getTimestamp();
    expect(Timestamp.tryParse(timestamp.timestamp.v!), isNotNull);
    // ignore: avoid_print
    print(timestamp);
  });
  test('httpTimestamp', () async {
    var timestamp = await apiService.httpGetTimestamp();
    expect(Timestamp.tryParse(timestamp.timestamp.v!), isNotNull);
    // ignore: avoid_print
    print(timestamp);
  });
  test('create/join/leave/delete/purge/Entity', () async {
    var client = context.projectApiClient;
    var now = DateTime.timestamp().toIso8601String();
    var name = 'Test $now';
    var createEntityId = 'test';
    try {
      await client.deleteEntity(entityId: createEntityId);
    } catch (_) {}
    try {
      await client.purgeEntity(entityId: createEntityId);
    } catch (_) {}
    var entity = await client.createEntity(
      entity: FsProject()..name.v = name,
      entityId: createEntityId,
    );
    expect(entity.name.v, name);
    var entityId = entity.id;
    expect(entityId, entityId);
    var fsDatabase = context.fsDatabase;
    if (!noFirestoreCheck) {
      entity = await fsDatabase.projectDb
          .fsEntityRef(entityId)
          .get(fsDatabase.firestore);
      expect(entity.exists, isTrue);
      expect(entity.name.v, name);
    }

    String userId;
    var fsUserAccess = TkCmsFsUserAccess()..grantAdminAccess();
    if (!noFirestoreCheck && !noSignIn) {
      var user = await context.ffContext.auth.signInWithEmailAndPassword(
        email: 'test2',
        password: 'test',
      );
      userId = user.user.uid;

      expect(
        (await fsDatabase.projectDb
                .fsEntityUserAccessRef(entityId, userId)
                .get(fsDatabase.firestore))
            .exists,
        isFalse,
      );

      await client.joinEntity(entityId: entityId, fsUserAccess: fsUserAccess);
      expect(
        (await fsDatabase.projectDb
                .fsEntityUserAccessRef(entityId, userId)
                .get(fsDatabase.firestore))
            .exists,
        isTrue,
      );
    } else {
      userId = apiService.userIdOrNull!;
    }
    await client.leaveEntity(entityId: entityId);
    if (!noFirestoreCheck) {
      expect(
        (await fsDatabase.projectDb
                .fsEntityUserAccessRef(entityId, userId)
                .get(fsDatabase.firestore))
            .exists,
        isFalse,
      );
    }
    await client.joinEntity(entityId: entityId, fsUserAccess: fsUserAccess);
    if (!noFirestoreCheck) {
      expect(
        (await fsDatabase.projectDb
                .fsEntityUserAccessRef(entityId, userId)
                .get(fsDatabase.firestore))
            .exists,
        isTrue,
      );
    }

    await client.deleteEntity(entityId: entityId);
    if (!noFirestoreCheck) {
      entity = await fsDatabase.projectDb
          .fsEntityRef(entityId)
          .get(fsDatabase.firestore);
      expect(entity.exists, isTrue);
      expect(entity.deleted.v, isTrue);
    }
    await client.purgeEntity(entityId: entityId);
    if (!noFirestoreCheck) {
      entity = await fsDatabase.projectDb
          .fsEntityRef(entityId)
          .get(fsDatabase.firestore);
      expect(entity.exists, isFalse);
    }
  });
}
