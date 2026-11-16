import 'package:festenao_firebase_auth_firestore_functions_flutter/festenao_firebase_auth_firestore_functions_flutter.dart';
import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/sdb.dart';

void main() {
  test('not flutterfire in a vm test', () {
    expect(firebaseAuthFirestoreFunctionsFlutterSupported, isFalse);
  });

  test('rest: auth, firestore and the functions call of the project', () async {
    var context = await initFirebaseAuthFirestoreFunctionsRest(
      options: const FirebaseOptions(
        apiKey: 'test-api-key',
        appId: '1:123:web:456',
        messagingSenderId: '123',
        projectId: 'demo-festenao-aff',
      ),
      functionsCallRegion: 'europe-west1',
      sdbFactory: newSdbFactoryMemory(),
    );
    expect(context.firebaseApp.options.projectId, 'demo-festenao-aff');
    expect(context.firestore, isNotNull);
    expect(context.functionsCall, isNotNull);
    expect(context.auth.currentUser, isNull);
  });
}
