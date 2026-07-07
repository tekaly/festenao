import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_support.dart';
import 'festenao_test_server_test_runner.dart';

/// Check access unsing standard entity api
void appProjectAccessApiTestRunner(
  Future<FestenaoTestClientContext> Function() contextBuilder,
) {
  late FestenaoTestClientContext testContext;
  late FirebaseAuth auth;
  late final firestore = testContext.firestore!;

  setUp(() async {
    initFestenaoFsEntityApiBuilders<TkCmsFsProject>();
    testContext = await contextBuilder();
    auth = testContext.firebaseAuth!;
    testContext.apiService.httpsApiUri!;
  });

  test('admin can write, unrelated user cannot', () async {
    var credential = const TkCmsEmailPasswordCredentials(
      email: 'admin@festenao-dartff-test.local',
      password: 'test1234',
    );
    // Sign in the future app admin.
    await auth.signInOrUpWithEmailAndPassword(
      email: credential.email,
      password: credential.password,
    );
    expect(auth.currentUser, isNotNull);

    // Bootstrap the "app" (top) entity and grant this user admin access to
    // it, using the cloud function's entity create command: this runs
    // through the admin SDK server side, which bypasses security rules --
    // the only way to create the very first admin for an entity.
    initTkCmsFsBuilders();

    var appId = testContext.apiService.app;

    /// Project collection info.
    final projectCollectionInfo = fsProjectCollectionInfo;
    var appApiClient = FestenaoApiFsEntityClient<TkCmsFsProject>(
      apiService: testContext.apiService,
      entityAccess: TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
        entityCollectionInfo: projectCollectionInfo,
        firestore: firestore, // Not used for access
        rootDocument: fsAppRoot(appId),
      ),
    );

    var entity = await appApiClient.createEntity(entity: TkCmsFsProject());
    var projectId = entity.id;

    var docRef = firestore.doc('app/$appId/project/$projectId/sub/data');
    await docRef.set({'probe': 'admin-write-ok'});

    var snapshot = await docRef.get();
    var data = snapshot.data;
    expect(data, {'probe': 'admin-write-ok'});

    // A different, unrelated user has no access grant on this entity: a
    // direct Firestore write must be rejected by the security rules.
    await auth.signOut();
    expect(auth.currentUser, isNull);
    await auth.signInOrUpWithEmailAndPassword(
      email: 'stranger@festenao-dartff-test.local',
      password: 'test1234',
    );
    expect(auth.currentUser, isNotNull);
    try {
      await docRef.set({'probe': 'stranger-write'});
      fail('should fail');
    } on FirestoreException catch (e) {
      expect(e.code, FirestoreErrorCode.permissionDenied);
    }
    try {
      await docRef.get();
      fail('should fail');
    } on FirestoreException catch (e) {
      expect(e.code, FirestoreErrorCode.permissionDenied);
    }

    // Sign in the future app admin.
    await auth.signInOrUpWithEmailAndPassword(
      email: credential.email,
      password: credential.password,
    );
    await docRef.get();
    await appApiClient.deleteEntity(entityId: entity.id);
    await appApiClient.purgeEntity(entityId: entity.id);
  });
}
