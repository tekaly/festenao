import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/auth/festenao_auth.dart';
import 'package:festenao_common/data/firestore_doc.dart';
import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/server/festeano_server_firestore_handler.dart';
import 'package:festenao_common/server/festeano_server_object_storage_handler.dart';
import 'package:festenao_common/server/festenao_projects_server_app.dart';
import 'package:festenao_common/test/entity_set_public_api_test_runner.dart';
import 'package:tekartik_app_media/mime_type.dart';
import 'package:tekartik_firebase_functions/ff_server.dart';
import 'package:tkcms_common/tkcms_app.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// Festenao server app for test: the projects app plus a raw firestore
/// access (the doc api, get/set/delete any document with the server rights,
/// for test setups) and an optional object storage.
///
/// Never deployed: a function runs `FestenaoProjectsServerApp`.
class FestenaoServerAppTest extends FestenaoProjectsServerApp {
  /// Object storage.
  final ObjectStorage? objectStorage;

  /// Festenao server app for test.
  FestenaoServerAppTest({
    required super.context,
    super.app,
    this.objectStorage,
  });

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

  @override
  List<FestenaoApiHandler> get apiHandlers => [
    firestoreHandler,
    ?objectStorageHandler,
    ...super.apiHandlers,
  ];
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

  var _closed = false;

  /// True once [close] has been called.
  ///
  /// A context can be shared by several test groups, each closing it when it
  /// is done: closing is a no-op after the first time.
  bool get closed => _closed;

  @override
  Future<void> close() async {
    if (_closed) {
      return;
    }
    _closed = true;
    //await ffServer.close();
    await clientContext.apiService.close();
    await ffServer?.close();
    await ampService.close();
  }
}

/// The second test user of [initFestenaoTestServerContextAllMemory], for
/// [TestFestenaoServerGroupOptions.strangerCredentials].
const memoryStrangerCredentials = TkCmsEmailPasswordCredentials(
  email: 'test2',
  password: 'test2',
);

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

  // The second test user of the memory context (a stranger), then the first
  // one, signed in.
  await ffContext.auth.signInOrUpWithEmailAndPassword(
    email: memoryStrangerCredentials.email,
    password: memoryStrangerCredentials.password,
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

/// Expect [call] to fail with the api error [code].
Future<void> _expectApiErrorCode(
  Future<Object?> Function() call,
  String code,
) async {
  try {
    await call();
    fail('should fail with $code');
  } on ApiException catch (e) {
    expect(e.error?.code.v, code, reason: '$e');
  }
}

/// Server group options
class TestFestenaoServerGroupOptions {
  /// Requires auth and firestore doc function
  final bool addFirestoreDoc;

  /// A second test user, with no access on anything, for the tests that
  /// need a stranger (the set public suite); those are skipped without it.
  final TkCmsEmailPasswordCredentials? strangerCredentials;

  /// Constructor for [TestFestenaoServerGroupOptions].
  TestFestenaoServerGroupOptions({
    this.addFirestoreDoc = false,
    this.strangerCredentials,
  });
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

    /// Removes the entity a failed run may have left, signed in: delete and
    /// purge require its admin (the signed in user, its creator), the admin
    /// calls only work without the security rules (admin sdk checks).
    Future<void> cleanUp() async {
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
    }

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
      await cleanUp();
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

    // userId is the signed in user, set above. It used to be overwritten here
    // with `apiService.userIdOrNull`, an unauthenticated client side value the
    // server no longer honours.
    //
    // Joining within its own access (the creator is an admin) is allowed, a
    // role it does not have is not (no escalation through join).
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
    await _expectApiErrorCode(
      () => client.joinEntity(
        entityId: entityId,
        fsUserAccess: TkCmsFsUserAccess.superAdmin(),
      ),
      HttpsErrorCode.permissionDenied,
    );

    await client.deleteEntity(entityId: entityId);
    var userEntityAccessRef = fsDatabase.projectDb.fsUserEntityAccessRef(
      userId,
      entityId,
    );
    if (!noFirestoreCheck) {
      entity = await fsDatabase.projectDb
          .fsEntityRef(entityId)
          .get(fsDatabase.firestore);
      expect(entity.exists, isTrue);
      expect(entity.deleted.v, isTrue);
      var userEntityAccess = await userEntityAccessRef.get(
        fsDatabase.firestore,
      );
      expect(userEntityAccess.exists, isTrue);
    }
    await client.purgeEntity(entityId: entityId);
    if (!noFirestoreCheck) {
      // Through the rules (the emulator) the client has no access left to
      // the purged entity: its read is refused rather than empty. Read as
      // the server does when the doc api is there, a refused client read
      // counts as gone otherwise.
      var docApiService = options!.addFirestoreDoc
          ? FirestoreDocApiService(
              httpsApiUri: apiService.httpsApiUri,
              callableApi: apiService.callableApi,
              httpClientFactory: apiService.httpClientFactory,
              app: apiService.app,
            )
          : null;
      Future<bool> purgedDocExists(String path) async {
        if (docApiService != null) {
          return await docApiService.getDoc(path) != null;
        }
        try {
          return (await fsDatabase.firestore.doc(path).get()).exists;
        } on FirestoreException catch (e) {
          if (e.code == FirestoreErrorCode.permissionDenied) {
            return false;
          }
          rethrow;
        }
      }

      expect(
        await purgedDocExists(fsDatabase.projectDb.fsEntityRef(entityId).path),
        isFalse,
      );
      expect(await purgedDocExists(userEntityAccessRef.path), isFalse);
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
  group(
    'entity rights',
    () {
      // A user with no access on a project (the stranger) cannot give itself
      // one, nor manage it; the owner, once it left, cannot come back without
      // an invite.
      late FestenaoApiFsEntityClient<FsProject> client;
      late FirebaseAuth auth;
      late String ownerId;
      late String strangerId;

      Future<String> signIn(TkCmsEmailPasswordCredentials credentials) async =>
          (await auth.signInWithEmailAndPassword(
            email: credentials.email,
            password: credentials.password,
          )).user.uid;
      Future<String> signInOwner() =>
          signIn(context.clientContext.credentials!);
      Future<String> signInStranger() => signIn(options!.strangerCredentials!);

      Future<bool> hasAccess(String entityId, String userId) async =>
          (await context.fsDatabase.projectDb
                  .fsEntityUserAccessRef(entityId, userId)
                  .get(context.fsDatabase.firestore))
              .exists;

      Future<String> createProject() async => (await client.createEntity(
        entity: FsProject()
          ..name.v = 'Rights ${DateTime.timestamp().toIso8601String()}',
      )).id;

      setUpAll(() async {
        client = context.projectApiClient;
        auth = context.clientContext.firebaseAuth!;
        strangerId = await signInStranger();
        ownerId = await signInOwner();
      });

      test('stranger join refused', () async {
        await signInOwner();
        var entityId = await createProject();
        await signInStranger();
        for (var access in [
          TkCmsFsUserAccess.superAdmin(),
          TkCmsFsUserAccess.admin(),
          TkCmsFsUserAccess()..read.v = true,
        ]) {
          await _expectApiErrorCode(
            () => client.joinEntity(entityId: entityId, fsUserAccess: access),
            HttpsErrorCode.permissionDenied,
          );
        }
        if (!noFirestoreCheck) {
          expect(await hasAccess(entityId, strangerId), isFalse);
        }
        await signInOwner();
        await client.deleteEntity(entityId: entityId);
        await client.purgeEntity(entityId: entityId);
      });

      test('stranger delete invite, delete and purge refused', () async {
        await signInOwner();
        var entityId = await createProject();
        var inviteId = await client.createEntityInvite(
          entityId: entityId,
          fsUserAccess: TkCmsFsUserAccess()..read.v = true,
        );
        await signInStranger();
        await _expectApiErrorCode(
          () =>
              client.deleteEntityInvite(entityId: entityId, inviteId: inviteId),
          HttpsErrorCode.permissionDenied,
        );
        await _expectApiErrorCode(
          () => client.deleteEntity(entityId: entityId),
          HttpsErrorCode.permissionDenied,
        );

        // Deleted by its owner (the invite still there, read as the owner:
        // the rules hide it from the stranger), a stranger cannot purge it.
        await signInOwner();
        if (!noFirestoreCheck) {
          var invite = await context.fsDatabase.projectDb
              .fsInviteEntityRef(inviteId, entityId)
              .get(context.fsDatabase.firestore);
          expect(invite.exists, isTrue);
        }
        await client.deleteEntity(entityId: entityId);
        await signInStranger();
        await _expectApiErrorCode(
          () => client.purgeEntity(entityId: entityId),
          HttpsErrorCode.permissionDenied,
        );
        await signInOwner();
        if (!noFirestoreCheck) {
          expect(await hasAccess(entityId, ownerId), isTrue);
        }
        await client.deleteEntityInvite(entityId: entityId, inviteId: inviteId);
        await client.purgeEntity(entityId: entityId);
      });

      test('owner left cannot join again', () async {
        await signInOwner();
        var entityId = await createProject();
        await client.leaveEntity(entityId: entityId);
        if (!noFirestoreCheck) {
          expect(await hasAccess(entityId, ownerId), isFalse);
        }
        await _expectApiErrorCode(
          () => client.joinEntity(
            entityId: entityId,
            fsUserAccess: TkCmsFsUserAccess.admin(),
          ),
          HttpsErrorCode.permissionDenied,
        );
      });
    },
    skip: noSignIn || options.strangerCredentials == null
        ? 'no sign in or no stranger'
        : null,
  );
  group('set public', () {
    // The shared suite of `entity/project/set-public`: the first test user
    // publishes and unpublishes a project it created; a second one, when
    // the deployment has one, is refused.
    entitySetPublicApiTestRunner<FsProject>(() async {
      var auth = context.clientContext.firebaseAuth;
      var credentials = context.clientContext.credentials;
      if (auth == null || credentials == null) {
        throw StateError('Auth and credentials are required for this test');
      }
      var strangerCredentials = options!.strangerCredentials;
      var client = context.projectApiClient;
      Future<String> signIn(TkCmsEmailPasswordCredentials credentials) async =>
          (await auth.signInWithEmailAndPassword(
            email: credentials.email,
            password: credentials.password,
          )).user.uid;
      return EntitySetPublicApiTestContext<FsProject>(
        client: client,
        signInAdmin: () => signIn(credentials),
        signInStranger: strangerCredentials == null
            ? null
            : () => signIn(strangerCredentials),
        createEntity: () async => (await client.createEntity(
          entity: FsProject()
            ..name.v = 'Set public ${DateTime.timestamp().toIso8601String()}',
        )).id,
        purgeEntity: (entityId) async {
          await client.deleteEntity(entityId: entityId);
          await client.purgeEntity(entityId: entityId);
        },
        // The festenao project handler has no app level condition.
        privilegeRequired: false,
        flagReadable: !noFirestoreCheck,
      );
    });
  }, skip: noSignIn ? 'no sign in' : null);
}
