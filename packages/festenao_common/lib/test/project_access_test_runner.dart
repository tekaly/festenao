import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/festenao_firestore.dart';
import 'package:festenao_common/festenao_support.dart';
import 'package:festenao_common/src/data/firestore/firestore_doc_api.dart';
import 'festenao_test_server_test_runner.dart';

/// Check access error
bool isExceptionPermissionError(Object e) {
  if (e is FirestoreException) {
    return e.code == FirestoreErrorCode.permissionDenied;
  }
  return false;
}

/// Check access using standard common rules
void appProjectAccessTestRunner(
  Future<FestenaoTestClientContext> Function() contextBuilder,
) {
  late FestenaoTestClientContext testContext;
  late FirebaseAuth auth;
  late final firestore = testContext.firestore!;
  late final docApiService = testContext.apiService.docApiService;

  setUp(() async {
    initTkCmsFsBuilders();
    initFestenaoFsEntityApiBuilders<TkCmsFsProject>();
    testContext = await contextBuilder();
    auth = testContext.firebaseAuth!;
    testContext.apiService.httpsApiUri!;
  });

  test('min project access', () async {
    var credential = const TkCmsEmailPasswordCredentials(
      email: 'admin@festenao-dartff-test.local',
      password: 'test1234',
    );
    // Sign in the future app admin.
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: credential.email,
      password: credential.password,
    );
    expect(auth.currentUser, isNotNull);
    var userId = userCredential.user.uid;

    var projectId = 'test_festenao_access_common';
    var appId = 'test_app';

    final projectCollectionInfo = fsProjectCollectionInfo;

    /// Create the user access first
    var entityAccess =
        TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
          entityCollectionInfo: projectCollectionInfo,
          firestore: firestore, // Not used for access
          rootDocument: fsAppRoot(appId),
        );

    var accessRef = entityAccess.fsEntityUserAccessRef(projectId, userId);

    /// Grant admin access
    await docApiService.cvSetDoc(accessRef.cv()..grantAdminAccess());

    // User can create the project
    var entityRef = entityAccess.fsEntityRef(projectId);
    await firestore.cvSet(entityRef.cv()..name.v = 'test');
    await entityRef.get(firestore);
    // User can can write access
    // NO in the core rules ! await firestore.cvSet(accessRef.cv()..grantAdminAccess());

    Future<void> expectPermissionError(Future<void> Function() action) async {
      // Cannot read
      try {
        await action();
        fail('should fail before');
      } catch (e) {
        expect(isExceptionPermissionError(e), isTrue, reason: '$e');
      }
    }

    // Remove admin access
    await docApiService.cvSetDoc((accessRef.cv()..write.v = true)..fixAccess());
    // Can still write
    await firestore.cvSet(entityRef.cv()..name.v = 'test2');
    await entityRef.get(firestore);

    // Remove write access
    await docApiService.cvSetDoc((accessRef.cv()..read.v = true)..fixAccess());
    // Cannot write
    await expectPermissionError(() async {
      await firestore.cvSet(entityRef.cv()..name.v = 'test3');
    });
    // can still read
    // NOT yet in the core rules ! await entityRef.get(firestore);

    // Remove read access
    await docApiService.cvSetDoc((accessRef.cv()..read.v = false)..fixAccess());
    // Cannot read
    await expectPermissionError(() async {
      await entityRef.get(firestore);
    });

    await auth.signOut();

    // Cannot read
    await expectPermissionError(() async {
      await entityRef.get(firestore);
    });
  });
}

/// Check access using standard common rules
///     match /{top}/{topId}/user_prv/{userId} {
//       allow read, write: if request.auth != null && request.auth.uid == userId;
//     }
void appUserPrvAccessTestRunner(
  Future<FestenaoTestClientContext> Function() contextBuilder,
) {
  late FestenaoTestClientContext testContext;
  late FirebaseAuth auth;
  late final firestore = testContext.firestore!;

  setUp(() async {
    initTkCmsFsBuilders();
    initFestenaoFsEntityApiBuilders<TkCmsFsProject>();
    testContext = await contextBuilder();
    auth = testContext.firebaseAuth!;
    testContext.apiService.httpsApiUri!;
  });

  test('user prv access', () async {
    var credential = const TkCmsEmailPasswordCredentials(
      email: 'admin@festenao-dartff-test.local',
      password: 'test1234',
    );
    // Sign in.
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: credential.email,
      password: credential.password,
    );
    expect(auth.currentUser, isNotNull);
    var userId = userCredential.user.uid;

    var appId = 'test_app';
    var userPrvRef = firestore.doc(
      'app/$appId/$tkCmsUserPrvFirestorePathPart/$userId',
    );
    var otherUserPrvRef = firestore.doc(
      'app/$appId/$tkCmsUserPrvFirestorePathPart/other_user',
    );

    Future<void> expectPermissionError(Future<void> Function() action) async {
      try {
        await action();
        fail('should fail before');
      } catch (e) {
        expect(isExceptionPermissionError(e), isTrue, reason: '$e');
      }
    }

    // Can write and read own user_prv
    await userPrvRef.set({'test': 'value'});
    var snapshot = await userPrvRef.get();
    expect(snapshot.data, {'test': 'value'});

    // Cannot write or read other user_prv
    await expectPermissionError(() async {
      await otherUserPrvRef.set({'test': 'value'});
    });
    await expectPermissionError(() async {
      await otherUserPrvRef.get();
    });

    // Sign out
    await auth.signOut();

    // Cannot read or write own user_prv when signed out
    await expectPermissionError(() async {
      await userPrvRef.get();
    });
    await expectPermissionError(() async {
      await userPrvRef.set({'test': 'value'});
    });
  });
}

/// Check access using standard common rules
///     match /{top}/{topId}/{entity}/{entityId}/user_prv/{userId} {
//       allow read, write: if request.auth != null && request.auth.uid == userId;
//     }
void appProjectUserPrvAccessTestRunner(
  Future<FestenaoTestClientContext> Function() contextBuilder,
) {
  late FestenaoTestClientContext testContext;
  late FirebaseAuth auth;
  late final firestore = testContext.firestore!;

  setUp(() async {
    initTkCmsFsBuilders();
    initFestenaoFsEntityApiBuilders<TkCmsFsProject>();
    testContext = await contextBuilder();
    auth = testContext.firebaseAuth!;
    testContext.apiService.httpsApiUri!;
  });

  test('project user prv access', () async {
    var credential = const TkCmsEmailPasswordCredentials(
      email: 'admin@festenao-dartff-test.local',
      password: 'test1234',
    );
    // Sign in.
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: credential.email,
      password: credential.password,
    );
    expect(auth.currentUser, isNotNull);
    var userId = userCredential.user.uid;

    var appId = 'test_app';
    var projectId = 'test_project';
    var userPrvRef = firestore.doc(
      'app/$appId/project/$projectId/$tkCmsUserPrvFirestorePathPart/$userId',
    );
    var otherUserPrvRef = firestore.doc(
      'app/$appId/project/$projectId/$tkCmsUserPrvFirestorePathPart/other_user',
    );

    Future<void> expectPermissionError(Future<void> Function() action) async {
      try {
        await action();
        fail('should fail before');
      } catch (e) {
        expect(isExceptionPermissionError(e), isTrue, reason: '$e');
      }
    }

    // Can write and read own user_prv
    await userPrvRef.set({'test': 'value'});
    var snapshot = await userPrvRef.get();
    expect(snapshot.data, {'test': 'value'});

    // Cannot write or read other user_prv
    await expectPermissionError(() async {
      await otherUserPrvRef.set({'test': 'value'});
    });
    await expectPermissionError(() async {
      await otherUserPrvRef.get();
    });

    // Sign out
    await auth.signOut();

    // Cannot read or write own user_prv when signed out
    await expectPermissionError(() async {
      await userPrvRef.get();
    });
    await expectPermissionError(() async {
      await userPrvRef.set({'test': 'value'});
    });
  });
}

/// Check access using standard common rules
void appProjectStandaloneAccessTestRunner(
  Future<FestenaoTestClientContext> Function() contextBuilder,
) {
  late FestenaoTestClientContext testContext;
  late FirebaseAuth auth;
  late final firestore = testContext.firestore!;
  late final docApiService = testContext.apiService.docApiService;

  setUp(() async {
    initTkCmsFsBuilders();
    initFestenaoFsEntityApiBuilders<TkCmsFsProject>();
    testContext = await contextBuilder();
    auth = testContext.firebaseAuth!;
    testContext.apiService.httpsApiUri!;
  });

  test('standalone project access', () async {
    var credential = const TkCmsEmailPasswordCredentials(
      email: 'admin@festenao-dartff-test.local',
      password: 'test1234',
    );
    // Sign in the future app admin.
    var userCredential = await auth.signInOrUpWithEmailAndPassword(
      email: credential.email,
      password: credential.password,
    );
    expect(auth.currentUser, isNotNull);
    var userId = userCredential.user.uid;

    var projectId = 'test_festenao_access_common';
    var appId = 'test_app';

    final projectCollectionInfo = fsProjectCollectionInfo;

    /// Create the user access first
    var entityAccess =
        TkCmsFirestoreDatabaseServiceEntityAccess<TkCmsFsProject>(
          entityCollectionInfo: projectCollectionInfo,
          firestore: firestore, // Not used for access
          rootDocument: fsAppRoot(appId),
        );

    var accessRef = entityAccess.fsEntityUserAccessRef(projectId, userId);

    /// Grant admin access
    await docApiService.cvSetDoc(accessRef.cv()..grantAdminAccess());

    // User can create the project
    var entityRef = entityAccess.fsEntityRef(projectId);
    await firestore.cvSet(entityRef.cv()..name.v = 'test');
    await entityRef.get(firestore);
    // User can can write access
    await firestore.cvSet(accessRef.cv()..grantAdminAccess());

    Future<void> expectPermissionError(Future<void> Function() action) async {
      // Cannot read
      try {
        await action();
        fail('should fail before');
      } catch (e) {
        expect(isExceptionPermissionError(e), isTrue, reason: '$e');
      }
    }

    // Remove admin access
    await docApiService.cvSetDoc((accessRef.cv()..write.v = true)..fixAccess());
    // Can still write
    await firestore.cvSet(entityRef.cv()..name.v = 'test2');
    await entityRef.get(firestore);

    // User cannot cannot write access
    await expectPermissionError(() async {
      await firestore.cvSet(accessRef.cv()..grantAdminAccess());
    });

    // Remove write access
    await docApiService.cvSetDoc((accessRef.cv()..read.v = true)..fixAccess());
    // Cannot write
    await expectPermissionError(() async {
      await firestore.cvSet(entityRef.cv()..name.v = 'test3');
    });
    // can still read
    // NOT yet await entityRef.get(firestore);

    // Remove read access
    await docApiService.cvSetDoc((accessRef.cv()..read.v = false)..fixAccess());
    // Cannot read
    await expectPermissionError(() async {
      await entityRef.get(firestore);
    });

    await auth.signOut();

    // Cannot read
    await expectPermissionError(() async {
      await entityRef.get(firestore);
    });
  });
}
