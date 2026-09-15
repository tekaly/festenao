// Temporary: the runnable examples of skills/*/SKILL.md, verified here.
import 'dart:convert';

import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firebase_memory.dart';
import 'package:festenao_common/firebase/firebase_rest.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:festenao_common/server/festeano_server_firestore_handler.dart';
import 'package:festenao_common/server/festeano_server_object_storage_handler.dart';
import 'package:festenao_common/test/festenao_test_server_test_runner.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_app_http/app_http.dart';
import 'package:test/test.dart';

// ---- skill 1: entity api ----

FestenaoApiFsEntityClient<FsProject> projectClient({
  required Firestore firestore,
  required FirebaseFunctionsCall functionsCall,
  required String appId,
}) {
  initFestenaoFsBuilders();
  initFestenaoFsEntityApiBuilders<FsProject>();
  var apiService = FestenaoApiService(
    app: appId,
    httpClientFactory: httpClientFactoryUniversal,
    httpsApiUri: Uri.parse('https://commandv2dev-xxxx-ew.a.run.app'),
    callableApi: functionsCall.callableFromUri(
      Uri.parse('https://callcommandv2dev-xxxx-ew.a.run.app'),
    ),
  );
  return FestenaoApiFsEntityClient<FsProject>(
    apiService: apiService,
    entityAccess: TkCmsFirestoreDatabaseServiceEntityAccess<FsProject>(
      entityCollectionInfo: projectCollectionInfo,
      firestore: firestore,
      rootDocument: fsAppRoot(appId),
    ),
  );
}

class FsBooklet extends TkCmsFsEntity {
  final description = CvField<String>('description');

  @override
  CvFields get fields => [...super.fields, description];
}

final bookletCollectionInfo =
    TkCmsFirestoreDatabaseEntityCollectionInfo<FsBooklet>(
      id: 'booklet',
      name: 'Booklet',
      treeDef: tkCmsSyncedTreeDef,
    );

class BookletServerApp extends FestenaoServerApp {
  BookletServerApp({required super.context}) : super(app: 'booklets') {
    initTkCmsFsBuilders();
    cvAddConstructor(FsBooklet.new);
    initFestenaoFsEntityApiBuilders<FsBooklet>();
  }

  // `this.`: tkcms exports same-named globals, see the server app skill.
  late final bookletDb = TkCmsFirestoreDatabaseServiceEntityAccess<FsBooklet>(
    entityCollectionInfo: bookletCollectionInfo,
    firestore: firestore,
    rootDocument: fsAppRoot(app),
  );

  late final bookletHandler = FestenaoEntityHandler<FsBooklet>(
    app: this,
    entityAccess: bookletDb,
    options: FestenaoEntityHandlerOptions(
      setPublicCheck: ({required userId, required entityId}) async {
        var rights = await firestore.doc('app/$app/user_access/$userId').get();
        print('PROBE check user $userId entity $entityId exists ${rights.exists} data ${rights.exists ? rights.data : null} path ${rights.ref.path} fs ${identical(this.firestore, this.firebaseContext.firestore)}');
        return rights.exists && rights.data['publish'] == true;
      },
    ),
  );

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    return await bookletHandler.onCommandOrNull(apiRequest) ??
        await super.onCommand(apiRequest);
  }
}

// ---- skill 2: server app ----

class ApiShoutQuery extends ApiQuery {
  final text = CvField<String>('text');

  @override
  CvFields get fields => [text];
}

class ApiShoutResult extends ApiResult {
  final text = CvField<String>('text');

  @override
  CvFields get fields => [text];
}

const commandShout = 'shout';

class MyServerApp extends FestenaoServerApp {
  MyServerApp({required super.context}) : super(app: 'myapp') {
    cvAddConstructors([ApiShoutQuery.new, ApiShoutResult.new]);
  }

  // `this.`: tkcms exports same-named globals (a deprecated
  // `firebaseContext` among them) and an unqualified name resolves to the
  // library level one before an inherited member.
  late final fsDatabase = FestenaoFirestoreDatabase(
    firebaseContext: this.firebaseContext,
    flavorContext: this.appFlavorContext,
  );

  late final projectHandler = FestenaoEntityHandler(
    app: this,
    entityAccess: fsDatabase.projectDb,
  );

  late final firestoreHandler = FestenaoFirestoreHandler(
    options: FestenaoFirestoreHandlerOptions(firestore: this.firestore),
  );

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    for (var handler in [projectHandler, firestoreHandler]) {
      var result = await handler.onCommandOrNull(apiRequest);
      if (result != null) {
        return result;
      }
    }
    switch (apiRequest.apiCommand) {
      case commandShout:
        if (apiRequest.userId.v == null) {
          throw (ApiError()
                ..code.v = HttpsErrorCode.unauthenticated
                ..message.v = 'Sign in first'
                ..noRetry.v = true)
              .exception();
        }
        var query = apiRequest.query<ApiShoutQuery>();
        return ApiShoutResult()..text.v = query.text.v!.toUpperCase();
      default:
        return super.onCommand(apiRequest);
    }
  }

  @override
  Future<ApiResult> onCronCommand(ApiRequest apiRequest) async {
    await fsDatabase.projectDb.purgeDeletedEntities();
    await fsDatabase.projectDb.deleteOldInvites();
    return ApiEmpty();
  }
}

// ---- skill 3: rest tool (compiled, not run) ----

Future<FirebaseContext> initToolFirebase() async {
  var services = await festenaoInitFirebaseServicesContextRest(
    appOptions: FirebaseAppOptions(projectId: 'my-project', apiKey: 'AIza...'),
  );
  var ffContext = await services.init();
  await ffContext.auth.signInWithEmailAndPassword(
    email: 'me@example.com',
    password: 'secret',
  );
  return ffContext;
}

// ---- skill 4: files server ----

class FilesServerApp extends FestenaoServerApp {
  final ObjectStorage objectStorage;

  FilesServerApp({required super.context, required this.objectStorage})
    : super(app: 'files');

  late final objectStorageHandler = FestenaoObjectStorageHandler(
    options: FestenaoObjectStorageHandlerOptions(objectStorage: objectStorage),
  );

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    return await objectStorageHandler.onCommandOrNull(apiRequest) ??
        await super.onCommand(apiRequest);
  }
}

void main() {
  test('entity api: create, invite, publish (memory server)', () async {
    var context = await initFestenaoTestServerContextAllMemory();
    var auth = context.clientContext.firebaseAuth!;
    var client = context.projectApiClient;
    var projectDb = context.fsDatabase.projectDb;

    await auth.signInOrUpWithEmailAndPassword(
      email: 'owner@test.local',
      password: 'test1234',
    );
    var project = await client.createEntity(
      entity: FsProject()..name.v = 'Demo',
    );
    var inviteId = await client.createEntityInvite(
      entityId: project.id,
      fsUserAccess: TkCmsFsUserAccess()
        ..read.v = true
        ..write.v = true,
    );
    var isPublic = await client.setEntityPublic(
      entityId: project.id,
      public: true,
    );
    expect(isPublic, isTrue);
    expect(await projectDb.isEntityPublic(project.id), isTrue);

    await auth.signOut();
    await auth.signInOrUpWithEmailAndPassword(
      email: 'guest@test.local',
      password: 'test1234',
    );
    await client.acceptEntityInvite(entityId: project.id, inviteId: inviteId);
    var access = await projectDb
        .fsEntityUserAccessRef(project.id, auth.currentUser!.uid)
        .get(projectDb.firestore);
    expect(access.write.v, isTrue);
    expect(access.admin.v, isNot(isTrue));
    try {
      await client.setEntityPublic(entityId: project.id, public: false);
      fail('should fail');
    } on ApiException catch (e) {
      expect(e.error?.code.v, 'permission-denied');
    }
    await context.close();
  });

  test('entity api: own entity type with setPublicCheck', () async {
    var services = initFirebaseServicesLocalMemory(projectId: 'booklets');
    var serverContext = await services.initServer();
    var app = BookletServerApp(
      context: TkCmsServerAppContext(
        firebaseContext: serverContext,
        flavorContext: FlavorContext.dev,
      ),
    );
    app.initFunctions();
    var ffServer = await serverContext.functions.serve();
    addTearDown(ffServer.close);
    var clientContext = await services.init(
      firebaseApp: serverContext.firebaseApp,
      ffServer: ffServer,
      serverApp: app,
    );
    var userId = (await clientContext.auth.signInOrUpWithEmailAndPassword(
      email: 'test',
      password: 'test',
    )).user.uid;
    var apiService = FestenaoApiService(
      app: 'booklets',
      httpClientFactory: httpClientFactoryMemory,
      httpsApiUri: ffServer.uri.replace(path: app.command),
      callableApi: clientContext.functionsCall.callable(app.callCommand),
    );
    await apiService.initClient();
    var client = FestenaoApiFsEntityClient<FsBooklet>(
      apiService: apiService,
      entityAccess: TkCmsFirestoreDatabaseServiceEntityAccess<FsBooklet>(
        entityCollectionInfo: bookletCollectionInfo,
        firestore: clientContext.firestore,
        rootDocument: fsAppRoot('booklets'),
      ),
    );
    var booklet = await client.createEntity(
      entity: FsBooklet()
        ..name.v = 'Songs'
        ..description.v = 'Set list',
    );
    expect(booklet.description.v, 'Set list');
    expect(booklet.path, 'app/booklets/booklet/${booklet.id}');
    // Admin, but no app level privilege yet.
    try {
      await client.setEntityPublic(entityId: booklet.id, public: true);
      fail('should fail');
    } on ApiException catch (e) {
      print('PROBE first call: ${e.error?.toMap()}');
      expect(e.error?.code.v, 'permission-denied');
    }
    await serverContext.firestore.doc('app/booklets/user_access/$userId').set({
      'publish': true,
    });
    print('PROBE wrote for $userId, same fs ${identical(serverContext.firestore, app.firestore)}');
    expect(
      await client.setEntityPublic(entityId: booklet.id, public: true),
      isTrue,
    );
    expect(await app.bookletDb.isEntityPublic(booklet.id), isTrue);
    await apiService.close();
    await ffServer.close();
  });

  test('server app: serve in memory and call', () async {
    var services = initFirebaseServicesLocalMemory(projectId: 'demo');
    var serverContext = await services.initServer();
    var app = MyServerApp(
      context: TkCmsServerAppContext(
        firebaseContext: serverContext,
        flavorContext: FlavorContext.dev,
      ),
    );
    app.initFunctions();
    expect(app.command, 'commandv2dev');
    var ffServer = await serverContext.functions.serve();
    addTearDown(ffServer.close);
    var clientContext = await services.init(
      firebaseApp: serverContext.firebaseApp,
      ffServer: ffServer,
      serverApp: app,
    );
    await clientContext.auth.signInOrUpWithEmailAndPassword(
      email: 'test',
      password: 'test',
    );
    var apiService = FestenaoApiService(
      app: 'myapp',
      httpClientFactory: httpClientFactoryMemory,
      httpsApiUri: ffServer.uri.replace(path: app.command),
      callableApi: clientContext.functionsCall.callable(app.callCommand),
    );
    await apiService.initClient();
    var result = await apiService.getApiResult<ApiShoutResult>(
      ApiRequest(command: commandShout)
        ..setQuery(ApiShoutQuery()..text.v = 'hi'),
    );
    expect(result.text.v, 'HI');
    // The base commands still answer.
    expect((await apiService.getTimestamp()).timestamp.v, isNotNull);
    await apiService.cron();
    await apiService.close();
    await ffServer.close();
  });

  test('firebase context: memory layout', () async {
    var ffContext = await festenaoInitFirebaseMemory();
    var appFlavorContext = FlavorContext.dev.toAppFlavorContext(
      baseAppId: 'demo',
    );
    expect(appFlavorContext.app, 'demo-dev');
    var db = FestenaoFirestoreDatabase(
      firebaseContext: ffContext,
      flavorContext: appFlavorContext,
    );
    expect(db.projectDb.fsEntityCollectionRef.path, 'app/demo-dev/project');
    var projectRef = db.projectDb.fsEntityRef('p1');
    await projectRef.set(ffContext.firestore, FsProject()..name.v = 'Demo');
    var project = await projectRef.get(ffContext.firestore);
    expect(project.exists, isTrue);
    expect(project.name.v, 'Demo');
    expect(FlavorContext.prod.ifNotProdFlavor, '');
    expect(FlavorContext.dev.ifNotProdFlavor, 'dev');
  });

  test('firebase context: local server and client share firestore', () async {
    var services = initFirebaseServicesLocalMemory(projectId: 'demo');
    var serverContext = await services.initServer();
    var app = FestenaoServerApp(
      app: 'demo-dev',
      context: TkCmsServerAppContext(
        firebaseContext: serverContext,
        flavorContext: FlavorContext.dev,
      ),
    );
    app.initFunctions();
    var ffServer = await serverContext.functions.serve();
    addTearDown(ffServer.close);
    var clientContext = await services.init(
      firebaseApp: serverContext.firebaseApp,
      ffServer: ffServer,
      serverApp: app,
    );
    await serverContext.firestore.doc('app/demo-dev').set({'name': 'Demo'});
    expect((await clientContext.firestore.doc('app/demo-dev').get()).data, {
      'name': 'Demo',
    });
    await ffServer.close();
  });

  test('object storage: memory file system', () async {
    ObjectStorage storage = ObjectStorageFs(
      fileSystem: newFileSystemMemory(),
      rootPath: '/drive',
    );
    var meta = await storage.upload(
      'songs',
      name: 'intro.txt',
      data: Uint8List.fromList(utf8.encode('hello')),
      mimeType: 'text/plain',
    );
    expect(meta.path, 'songs/intro.txt');
    expect(meta.size, 5);
    expect(meta.mimeType, 'text/plain');
    var listed = await storage.list('songs');
    expect(listed.items.map((item) => item.name).toList(), ['intro.txt']);
    expect(utf8.decode(await storage.download('songs/intro.txt')), 'hello');
    var part = <int>[];
    await for (var chunk in storage.downloadStream(
      'songs/intro.txt',
      start: 1,
      size: 3,
      chunkSize: 2,
    )) {
      part.addAll(chunk);
    }
    expect(utf8.decode(part), 'ell');
    expect(await storage.getDownloadUrl('songs/intro.txt'), isNull);
    await storage.delete('songs/intro.txt');
    expect((await storage.list('songs')).items, isEmpty);
  });

  test('object storage: through the api', () async {
    var services = initFirebaseServicesLocalMemory(projectId: 'demo');
    var serverContext = await services.initServer();
    var app = FilesServerApp(
      context: TkCmsServerAppContext(
        firebaseContext: serverContext,
        flavorContext: FlavorContext.dev,
      ),
      objectStorage: ObjectStorageFs(
        fileSystem: newFileSystemMemory(),
        rootPath: '/drive',
      ),
    );
    app.initFunctions();
    var ffServer = await serverContext.functions.serve();
    addTearDown(ffServer.close);
    ObjectStorage remote = ObjectStorageApiClient(
      httpsUri: ffServer.uri.replace(path: app.command),
      httpClientFactory: httpClientFactoryMemory,
    );
    await remote.upload(
      'docs',
      name: 'readme.txt',
      data: Uint8List.fromList('hi'.codeUnits),
      mimeType: 'text/plain',
    );
    expect((await remote.list('docs')).items.single.path, 'docs/readme.txt');
    expect(utf8.decode(await remote.download('docs/readme.txt')), 'hi');
    expect(await remote.getDownloadUrl('docs/readme.txt'), isNull);
    await ffServer.close();
  });

  test('compiles only', () {
    expect(projectClient, isNotNull);
    expect(initToolFirebase, isNotNull);
  });
}
