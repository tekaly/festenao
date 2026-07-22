import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tekartik_firebase/firebase.dart';

part 'firebase_app_provider.g.dart';

/// The current [FirebaseApp] instance.
///
/// Defaults to [FirebaseApp.instance], the most recently initialized app.
/// Override in tests or when a specific app instance must be used.
@riverpod
FirebaseApp festenaoFirebaseApp(Ref ref) {
  return FirebaseApp.instance;
}
