// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sdb_factory_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app [SdbFactory].
///
/// Defaults to [sdbFactoryWeb] on the web and [sdbFactorySqflite] otherwise,
/// sandboxed under the current [FestenaoAppFlavorContext]'s unique app name
/// sub path. Override to provide an in-memory factory in tests.

@ProviderFor(festenaoSdbFactory)
final festenaoSdbFactoryProvider = FestenaoSdbFactoryProvider._();

/// The app [SdbFactory].
///
/// Defaults to [sdbFactoryWeb] on the web and [sdbFactorySqflite] otherwise,
/// sandboxed under the current [FestenaoAppFlavorContext]'s unique app name
/// sub path. Override to provide an in-memory factory in tests.

final class FestenaoSdbFactoryProvider
    extends $FunctionalProvider<SdbFactory, SdbFactory, SdbFactory>
    with $Provider<SdbFactory> {
  /// The app [SdbFactory].
  ///
  /// Defaults to [sdbFactoryWeb] on the web and [sdbFactorySqflite] otherwise,
  /// sandboxed under the current [FestenaoAppFlavorContext]'s unique app name
  /// sub path. Override to provide an in-memory factory in tests.
  FestenaoSdbFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'festenaoSdbFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$festenaoSdbFactoryHash();

  @$internal
  @override
  $ProviderElement<SdbFactory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SdbFactory create(Ref ref) {
    return festenaoSdbFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SdbFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SdbFactory>(value),
    );
  }
}

String _$festenaoSdbFactoryHash() =>
    r'467012ef4781b278f9d9f8e13c615495ad202c0f';
