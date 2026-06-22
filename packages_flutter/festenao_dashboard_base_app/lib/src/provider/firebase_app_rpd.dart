import 'package:festenao_common/festenao_firebase_rest.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
part 'firebase_app_rpd.g.dart';

@riverpod
/// Return current Firebase app instance
FirebaseApp rpdFirebaseApp(Ref ref) {
  return FirebaseApp.instance;
}

@riverpod
/// Return current Firebase app instance
Firestore rpdFirestore(Ref ref) {
  return Firestore.instance;
}

@riverpod
/// Return current Firebase auth instance
FirebaseAuth rpdFirebaseAuth(Ref ref) {
  return FirebaseAuth.instance;
}

@riverpod
/// Return current Firebase auth instance
FirebaseStorage rpdFirebaseStorage(Ref ref) {
  return FirebaseStorage.instance;
}
