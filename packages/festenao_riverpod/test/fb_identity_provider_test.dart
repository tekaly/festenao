import 'package:festenao_riverpod/festenao_riverpod.dart';
import 'package:idb_shim/sdb.dart';
import 'package:riverpod/riverpod.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_auth.dart';
import 'package:tkcms_common/tkcms_firestore.dart';

/// An app with admin credentials (the admin sdk): no current user ever.
class _AdminApp implements FirebaseApp {
  @override
  bool get hasAdminCredentials => true;

  @override
  FirebaseAppOptions get options => FirebaseAppOptions(projectId: 'my-admin');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _AdminAuth implements FirebaseAuth {
  @override
  final FirebaseApp app = _AdminApp();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('festenaoFbIdentityProvider', () {
    test('user', () async {
      var firebaseContext = await initFirebaseServicesLocalSdb(
        sdbFactory: newSdbFactoryMemory(),
        projectId: 'festenao-riverpod-identity-test',
      ).init();
      var container = ProviderContainer(
        overrides: [...festenaoFirebaseContextOverrides(firebaseContext)],
      );
      addTearDown(() async {
        container.dispose();
        await firebaseContext.close();
      });
      container.listen(festenaoFbIdentityProvider, (previous, next) {});

      expect(await container.read(festenaoFbIdentityProvider.future), isNull);
      var credential = await firebaseContext.auth
          .signInOrUpWithEmailAndPassword(
            email: 'alice@example.com',
            password: 'test1234',
          );
      TkCmsFbIdentity? identity;
      for (var i = 0; i < 500; i++) {
        identity = container.read(festenaoFbIdentityProvider).value;
        if (identity != null) {
          break;
        }
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
      expect(identity!.isUser, isTrue);
      expect(identity.userId, credential.user.uid);
    });

    test('service account', () async {
      var container = ProviderContainer(
        overrides: [
          festenaoFirebaseAuthProvider.overrideWithValue(_AdminAuth()),
        ],
      );
      addTearDown(container.dispose);
      container.listen(festenaoFbIdentityProvider, (previous, next) {});
      var identity = await container.read(festenaoFbIdentityProvider.future);
      expect(identity!.isServiceAccount, isTrue);
      expect(identity.serviceAccountProjectId, 'my-admin');
      expect(identity.userId, isNull);
    });
  });
}
