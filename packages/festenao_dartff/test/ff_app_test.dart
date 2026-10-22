@TestOn('vm')
library;

import 'package:festenao_common/data/firestore_doc.dart';
import 'package:festenao_dartff/functions.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// The deployed [FfApp] has no raw firestore access (the doc api writes any
/// document with the admin rights, signed in or not): only the emulator
/// serves it, for the test setups.
void main() {
  late FirebaseContext firebaseContext;

  setUpAll(() {
    firebaseContext = initFirebaseServicesLocalMemory(
      projectId: 'ff-app-test',
    ).initContext();
    firebaseContextOrNull = firebaseContext;
  });

  FfApp newFfApp({bool firestoreDocApi = false}) => FfApp(
    context: TkCmsServerAppContext(
      firebaseContext: firebaseContext,
      flavorContext: FlavorContext.dev,
    ),
    firestoreDocApi: firestoreDocApi,
  );

  /// A signed out raw set (no user id), as an attacker would send it.
  ApiRequest rawSetRequest(String path) => ApiRequest()
    ..command.v = FirestoreDocApiService.setCommand
    ..data.v =
        (FirestoreDocSetQuery()
              ..path.v = path
              ..data.v = {'admin': true})
            .toMap();

  test('no raw firestore doc api', () async {
    var path = 'access/app/entity_id/festenao_dev/user_access/attacker';
    // An unknown command for the deployed app.
    await expectLater(
      newFfApp().onCommand(rawSetRequest(path)),
      throwsA(
        isA<ApiException>().having(
          (e) => e.error?.code.v,
          'code',
          apiErrorCodeUnimplemented,
        ),
      ),
    );
    expect((await firebaseContext.firestore.doc(path).get()).exists, isFalse);
  });

  test('raw firestore doc api in the emulator', () async {
    var path = 'test/ff_app_test/doc/raw';
    await newFfApp(firestoreDocApi: true).onCommand(rawSetRequest(path));
    expect((await firebaseContext.firestore.doc(path).get()).data, {
      'admin': true,
    });
  });
}
