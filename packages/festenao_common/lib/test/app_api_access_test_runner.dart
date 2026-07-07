import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/api/festenao_api_fs_entity_client.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/firebase/firebase_auth.dart';

import 'festenao_test_server_test_runner.dart';

/// Check access unsing standard entity api
void appAccessApiTestRunner(
  Future<FestenaoTestClientContext> Function() contextBuilder,
) {
  late FestenaoTestClientContext testContext;
  late FirebaseAuth auth;
  late final firestore = testContext.firestore!;

  setUp(() async {
    testContext = await contextBuilder();
    auth = testContext.firebaseAuth!;
    testContext.apiService.httpsApiUri!;
  });

  test('dummy', () {});

  test('admin can write, unrelated user cannot', () async {
    // Sign in the future app admin.
    await auth.signInOrUpWithEmailAndPassword(
      email: 'admin@festenao-dartff-test.local',
      password: 'test1234',
    );
    expect(auth.currentUser, isNotNull);

    // Bootstrap the "app" (top) entity and grant this user admin access to
    // it, using the cloud function's entity create command: this runs
    // through the admin SDK server side, which bypasses security rules --
    // the only way to create the very first admin for an entity.
    initTkCmsFsBuilders();
    initFestenaoFsEntityApiBuilders<TkCmsFsApp>();
    var bootstrapApiService = testContext.apiService;

    var appApiClient = FestenaoApiFsEntityClient<TkCmsFsApp>(
      apiService: bootstrapApiService,
      entityAccess: TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsApp>(
        entityCollectionInfo: tkCmsFsAppCollectionInfo,
        firestore: firestore, // Not used for access
      ),
    );
    var entity = await appApiClient.createEntity(entity: TkCmsFsApp());
    var appId = entity.id;

    var docRef = firestore.doc('app/$appId/sub/data');
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
  }, skip: 'TODO with security rules');
}
