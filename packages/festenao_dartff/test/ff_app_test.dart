@TestOn('vm')
library;

import 'package:festenao_common/api/festenao_api_fs_entity.dart';
import 'package:festenao_common/data/firestore_doc.dart';
import 'package:festenao_dartff/functions.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
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

  /// The create command of the app (top) entity, as a signed in user sends
  /// it through the callable api.
  ApiRequest createAppRequest(
    String userId,
    String appId, {
    bool compat = false,
  }) => ApiRequest()
    ..command.v = compat
        ? '${tkCmsFsAppCollectionInfo.id}-$festenaoCreateEntityCommand'
        : festenaoEntityCreateCommand(tkCmsFsAppCollectionInfo.id)
    ..userId.v = userId
    ..data.v = {'entityId': appId, 'data': <String, Object?>{}};

  Future<bool> isAdminOfApp(String appId, String userId) async {
    var access = await firebaseContext.firestore
        .doc('access/app/entity_id/$appId/user_access/$userId')
        .get();
    return access.exists && access.data['admin'] == true;
  }

  group('app entity', () {
    test('a user cannot make itself app admin', () async {
      var ffApp = newFfApp();
      for (var (appId, compat) in [
        (ffApp.appFlavorContext.app, false),
        ('other_app', false),
        ('other_app', true),
      ]) {
        await expectLater(
          ffApp.onCommand(
            createAppRequest('app_attacker', appId, compat: compat),
          ),
          throwsA(
            isA<ApiException>().having(
              (e) => e.error?.code.v,
              'code',
              HttpsErrorCode.permissionDenied,
            ),
          ),
          reason: appId,
        );
        expect(await isAdminOfApp(appId, 'app_attacker'), isFalse);
        expect(
          (await firebaseContext.firestore.doc('app/$appId').get()).exists,
          isFalse,
        );
      }
    });

    test('an app admin creates an app entity', () async {
      var ffApp = newFfApp();
      await firebaseContext.firestore
          .doc(
            'access/app/entity_id/${ffApp.appFlavorContext.app}/user_access/'
            'app_admin',
          )
          .set({'admin': true, 'write': true, 'read': true});
      await ffApp.onCommand(createAppRequest('app_admin', 'created_app'));
      expect(await isAdminOfApp('created_app', 'app_admin'), isTrue);
    });

    test('the emulator bootstraps the first app admin', () async {
      var ffApp = newFfApp(firestoreDocApi: true);
      await ffApp.onCommand(createAppRequest('first_admin', 'emulator_app'));
      expect(await isAdminOfApp('emulator_app', 'first_admin'), isTrue);
    });
  });

  test('raw firestore doc api in the emulator', () async {
    var path = 'test/ff_app_test/doc/raw';
    await newFfApp(firestoreDocApi: true).onCommand(rawSetRequest(path));
    expect((await firebaseContext.firestore.doc(path).get()).data, {
      'admin': true,
    });
  });
}
