// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_app_rpd.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Return current Firebase app instance

@ProviderFor(rpdFirebaseApp)
final rpdFirebaseAppProvider = RpdFirebaseAppProvider._();

/// Return current Firebase app instance

final class RpdFirebaseAppProvider
    extends $FunctionalProvider<FirebaseApp, FirebaseApp, FirebaseApp>
    with $Provider<FirebaseApp> {
  /// Return current Firebase app instance
  RpdFirebaseAppProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rpdFirebaseAppProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rpdFirebaseAppHash();

  @$internal
  @override
  $ProviderElement<FirebaseApp> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseApp create(Ref ref) {
    return rpdFirebaseApp(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseApp value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseApp>(value),
    );
  }
}

String _$rpdFirebaseAppHash() => r'bf81c0f90db8be1448b57b08ac46934394db2ff8';

/// Return current Firebase app instance

@ProviderFor(rpdFirestore)
final rpdFirestoreProvider = RpdFirestoreProvider._();

/// Return current Firebase app instance

final class RpdFirestoreProvider
    extends $FunctionalProvider<Firestore, Firestore, Firestore>
    with $Provider<Firestore> {
  /// Return current Firebase app instance
  RpdFirestoreProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rpdFirestoreProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rpdFirestoreHash();

  @$internal
  @override
  $ProviderElement<Firestore> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  Firestore create(Ref ref) {
    return rpdFirestore(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Firestore value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Firestore>(value),
    );
  }
}

String _$rpdFirestoreHash() => r'0bdeadc466162fd818f3a4a881698108b2eaa8f5';

/// Return current Firebase auth instance

@ProviderFor(rpdFirebaseAuth)
final rpdFirebaseAuthProvider = RpdFirebaseAuthProvider._();

/// Return current Firebase auth instance

final class RpdFirebaseAuthProvider
    extends $FunctionalProvider<FirebaseAuth, FirebaseAuth, FirebaseAuth>
    with $Provider<FirebaseAuth> {
  /// Return current Firebase auth instance
  RpdFirebaseAuthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rpdFirebaseAuthProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rpdFirebaseAuthHash();

  @$internal
  @override
  $ProviderElement<FirebaseAuth> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseAuth create(Ref ref) {
    return rpdFirebaseAuth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseAuth value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseAuth>(value),
    );
  }
}

String _$rpdFirebaseAuthHash() => r'822fe30d2cd6ebbc0e12fa9ac98a550bf3837b8f';

/// Return current Firebase auth instance

@ProviderFor(rpdFirebaseStorage)
final rpdFirebaseStorageProvider = RpdFirebaseStorageProvider._();

/// Return current Firebase auth instance

final class RpdFirebaseStorageProvider
    extends
        $FunctionalProvider<FirebaseStorage, FirebaseStorage, FirebaseStorage>
    with $Provider<FirebaseStorage> {
  /// Return current Firebase auth instance
  RpdFirebaseStorageProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rpdFirebaseStorageProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rpdFirebaseStorageHash();

  @$internal
  @override
  $ProviderElement<FirebaseStorage> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseStorage create(Ref ref) {
    return rpdFirebaseStorage(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseStorage value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseStorage>(value),
    );
  }
}

String _$rpdFirebaseStorageHash() =>
    r'32c1f4e3554834b96fcfef2eb5766d057f1bff3f';
