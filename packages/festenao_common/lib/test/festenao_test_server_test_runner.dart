import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/firestore_doc.dart';
import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/server/festeano_server_app.dart';
import 'package:festenao_common/server/festeano_server_entity_handler.dart';
import 'package:festenao_common/server/festeano_server_firestore_handler.dart';
import 'package:festenao_common/server/festeano_server_object_storage_handler.dart';
import 'package:tekartik_app_media/mime_type.dart';
import 'package:tekartik_firebase_functions/ff_server.dart';
import 'package:tkcms_common/tkcms_app.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// Festenao server app for test.
class FestenaoServerAppTest extends FestenaoServerApp {
  /// Object storage.
  final ObjectStorage? objectStorage;

  /// Festenao server app for test.
  FestenaoServerAppTest({
    required super.context,
    super.app,
    this.objectStorage,
  }) {
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

  /// Object storage handler
  late final objectStorageHandler = objectStorage != null
      ? FestenaoObjectStorageHandler(
          options: FestenaoObjectStorageHandlerOptions(
            objectStorage: objectStorage!,
          ),
        )
      : null;

  /// Firestore doc handler
  late final firestoreHandler = FestenaoFirestoreHandler(
    options: FestenaoFirestoreHandlerOptions(firestore: fsDatabase.firestore),
  );

  late final _handlers = <FestenaoApiHandler>[
    firestoreHandler,
    ?objectStorageHandler,
    projectHandler,
  ];

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    var command = apiRequest.apiCommand;
    for (var handler in _handlers) {
      var result = await handler.onCommandOrNull(apiRequest);
      if (result != null) {
        return result;
      }
    }
    if (FestenaoEntityHandler.isEntityCommand(
      projectCollectionInfo.id,
      command,
    )) {
      var result = await projectHandler.onCommandOrNull(apiRequest);
      if (result != null) {
        return result;
      }
    }
    var result = await objectStorageHandler?.onCommandOrNull(apiRequest);
    if (result != null) {
      return result;
    }
    result = await firestoreHandler.onCommandOrNull(apiRequest);
    if (result != null) {
      return result;
    }
    return super.onCommand(apiRequest);
  }
}

/// Test api context.
abstract class FestenaoTestApiContext {
  /// Api service.
  FestenaoApiService get apiService;

  /// Project api client.
  FestenaoApiFsEntityClient<FsProject> get projectApiClient;

  /// Close context.
  Future<void> close();
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

/// Test client extension
extension FestenaoTestClientContextExt on FestenaoTestClientContext {
  /// Firestore
  Firestore? get firestore => firebaseApp.firestore();

  /// Firestore
  FirebaseAuth? get firebaseAuth => firebaseApp.auth();
}

/// Festenao client context.
abstract class FestenaoTestClientContext {
  /// Api service.
  FestenaoApiService get apiService;

  /// Firebase auth.
  FirebaseApp get firebaseApp;

  /// Credentials.
  TkCmsEmailPasswordCredentials? get credentials;

  /// Constructor for [FestenaoTestClientContext].
  factory FestenaoTestClientContext({
    required FestenaoApiService apiService,
    required FirebaseApp firebaseApp,
    TkCmsEmailPasswordCredentials? credentials,
  }) => _FestenaoTestClientContext(
    apiService: apiService,
    firebaseApp: firebaseApp,
    credentials: credentials,
  );
}

/// Internal implementation of [FestenaoTestClientContext].
class _FestenaoTestClientContext implements FestenaoTestClientContext {
  @override
  final FestenaoApiService apiService;

  @override
  final FirebaseApp firebaseApp;

  @override
  final TkCmsEmailPasswordCredentials? credentials;

  /// Constructor for [_FestenaoTestClientContext].
  _FestenaoTestClientContext({
    required this.apiService,
    required this.firebaseApp,
    this.credentials,
  });
}

/// Test server context.
class FestenaoTestServerContext
    implements
        FestenaoTestApiContext,
        FestenaoTestAmpContext,
        FestenaoTestFfServerContext {
  /// Client context.
  final FestenaoTestClientContext clientContext;

  @override
  FestenaoApiService get apiService => clientContext.apiService;

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
    required this.clientContext,
    this.ffServer,
    required this.ampService,
  }) {
    initFestenaoFsEntityApiBuilders<FsProject>();
  }

  @override
  Future<void> close() async {
    //await ffServer.close();
    await clientContext.apiService.close();
    await ffServer?.close();
    await ampService.close();
  }
}

/// Init all in memory.
Future<FestenaoTestServerContext>
initFestenaoTestServerContextAllMemory() async {
  var ffServicesContext = initFirebaseServicesLocalMemory(
    projectId: 'festenao_test_memory',
  );
  var ffServerContext = await ffServicesContext.initServer();

  var httpClientFactory = httpClientFactoryMemory;
  var ff = ffServerContext.functions;
  var serverAppContext = TkCmsServerAppContext(
    firebaseContext: ffServerContext,
    flavorContext: FlavorContext.test,
  );
  var ffServerApp = FestenaoServerAppTest(
    context: serverAppContext,
    objectStorage: ObjectStorageFirebase(
      storage: ffServerContext.storage,
      bucket: ffServerContext.storage.bucket(),
    ),
  );
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

  await ffContext.auth.signInOrUpWithEmailAndPassword(
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
      clientContext: FestenaoTestClientContext(
        apiService: apiService,
        firebaseApp: ffContext.firebaseApp,
        credentials: const TkCmsEmailPasswordCredentials(
          email: 'test',
          password: 'test',
        ),
      ),
      ffServer: ffServer,
      ampService: ampService,
    )
    ..projectApiClient = projectApiClient
    ..fsDatabase = fsDatabase
    ..ffContext = ffContext;
}

Future<void> main() async {
  debugWebServices = true;
  testFestenaoServerGroup(
    initFestenaoTestServerContextAllMemory,
    options: TestFestenaoServerGroupOptions(addFirestoreDoc: true),
  );
}

/// Server group options
class TestFestenaoServerGroupOptions {
  /// Requires auth and firestore doc function
  final bool addFirestoreDoc;

  /// Constructor for [TestFestenaoServerGroupOptions].
  TestFestenaoServerGroupOptions({this.addFirestoreDoc = false});
}

/// Test server group.
void testFestenaoServerGroup(
  Future<FestenaoTestServerContext> Function() initAllContext, {
  bool noFirestoreCheck = false,
  bool noSignIn = false,
  bool noObjectStorage = false,
  bool noFirestoreDoc = false,
  TestFestenaoServerGroupOptions? options,
}) {
  options ??= TestFestenaoServerGroupOptions();

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
    var auth = context.clientContext.firebaseAuth;
    if (auth == null || noSignIn) {
      return;
    }
    var client = context.projectApiClient;
    var fsDatabase = context.fsDatabase;

    await auth.signOut();
    var authMe = await client.apiService.getAuthMe();
    expect(authMe.uid.v, isNull);

    var projectDb = fsDatabase.projectDb;
    var now = DateTime.timestamp().toIso8601String();
    var name = 'Test $now';
    var createEntityId = 'test';

    try {
      await client.deleteEntity(entityId: createEntityId);
    } catch (_) {}
    try {
      await client.purgeEntity(entityId: createEntityId);
    } catch (_) {}

    try {
      await projectDb.adminDeleteEntity(createEntityId);
    } catch (_) {}
    try {
      await projectDb.adminPurgeEntity(createEntityId);
    } catch (_) {}
    Future<FsProject> createEntity() async {
      var entity = await client.createEntity(
        entity: FsProject()..name.v = name,
        entityId: createEntityId,
      );
      expect(entity.name.v, name);
      var entityId = entity.id;
      expect(entityId, entityId);

      if (!noFirestoreCheck) {
        entity = await projectDb
            .fsEntityRef(entityId)
            .get(fsDatabase.firestore);
        expect(entity.exists, isTrue);
        expect(entity.name.v, name);
        return entity;
      }
      return entity;
    }

    late String userId;
    var fsUserAccess = TkCmsFsUserAccess()..grantAdminAccess();

    var credentials = context.clientContext.credentials;

    if (!noSignIn) {
      if (credentials == null) {
        throw StateError('Auth and credentials are required for this test');
      }
      var user = await auth.signInWithEmailAndPassword(
        email: credentials.email,
        password: credentials.password,
      );
      userId = user.user.uid;

      authMe = await client.apiService.getAuthMe();
      expect(authMe.uid.v, userId);
      if (!noFirestoreCheck) {
        expect(
          (await fsDatabase.projectDb
                  .fsEntityUserAccessRef(createEntityId, userId)
                  .get(fsDatabase.firestore))
              .exists,
          isFalse,
        );
      }
    } else {
      userId = 'test_user_id';
    }
    var entity = await createEntity();
    var entityId = entity.id;

    if (!noFirestoreCheck && !noSignIn) {
      // Leave first
      await client.leaveEntity(entityId: entityId);
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

  test('object storage', () async {
    var objectStorageApiClient = ObjectStorageApiClient(
      httpsUri: apiService.httpsApiUri!,
      httpClientFactory: apiService.httpClientFactory,
    );

    var path = 'test';
    var data = Uint8List.fromList([1, 2, 3, 4, 5]);
    var mimeType = mimeTypeOctetStream;

    // Upload
    var uploadResult = await objectStorageApiClient.upload(
      path,
      name: 'test.bin',
      data: data,
      mimeType: mimeType,
    );
    expect(uploadResult.size, data.length);

    var filePath = uploadResult.path;
    // Get Item
    var item = await objectStorageApiClient.getItem(filePath);
    expect(item.size, data.length);

    // Download
    var downloadedData = await objectStorageApiClient.download(filePath);
    expect(downloadedData, data);

    // List
    var listResult = await objectStorageApiClient.list('test');
    expect(listResult.items.map((e) => e.path), contains(filePath));

    // Delete
    await objectStorageApiClient.delete(filePath);
    try {
      await objectStorageApiClient.getItem(filePath);
      fail('Should have thrown an error');
    } catch (e) {
      expect(e, isNot(isA<TestFailure>()));
    }
  }, skip: noObjectStorage);

  test('firestore doc', () async {
    var firestoreDocApiService = FirestoreDocApiService(
      httpsApiUri: apiService.httpsApiUri,
      callableApi: apiService.callableApi,
      httpClientFactory: apiService.httpClientFactory,
      app: apiService.app,
    );

    var path = 'test/firestore_doc_test';
    expect(await firestoreDocApiService.getDoc(path), isNull);

    var data = {'message': 'hello', 'count': 1, 'when': Timestamp.now()};
    await firestoreDocApiService.setDoc(path, data);
    expect(await firestoreDocApiService.getDoc(path), data);

    var updatedData = {'message': 'world', 'count': 2, 'when': Timestamp.now()};
    await firestoreDocApiService.setDoc(path, updatedData);
    expect(await firestoreDocApiService.getDoc(path), updatedData);

    await firestoreDocApiService.deleteDoc(path);
    expect(await firestoreDocApiService.getDoc(path), isNull);
  }, skip: !options.addFirestoreDoc);
}
