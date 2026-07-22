// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'firebase_app_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current [FirebaseApp] instance.
///
/// Defaults to [FirebaseApp.instance], the most recently initialized app.
/// Override in tests or when a specific app instance must be used.

@ProviderFor(festenaoFirebaseApp)
final festenaoFirebaseAppProvider = FestenaoFirebaseAppProvider._();

/// The current [FirebaseApp] instance.
///
/// Defaults to [FirebaseApp.instance], the most recently initialized app.
/// Override in tests or when a specific app instance must be used.

final class FestenaoFirebaseAppProvider
    extends $FunctionalProvider<FirebaseApp, FirebaseApp, FirebaseApp>
    with $Provider<FirebaseApp> {
  /// The current [FirebaseApp] instance.
  ///
  /// Defaults to [FirebaseApp.instance], the most recently initialized app.
  /// Override in tests or when a specific app instance must be used.
  FestenaoFirebaseAppProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'festenaoFirebaseAppProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$festenaoFirebaseAppHash();

  @$internal
  @override
  $ProviderElement<FirebaseApp> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  FirebaseApp create(Ref ref) {
    return festenaoFirebaseApp(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FirebaseApp value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FirebaseApp>(value),
    );
  }
}

String _$festenaoFirebaseAppHash() =>
    r'9df2337817df85bc1db369f79aeb6b8d4dd36f7a';
