// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sdb_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(sdbFactory)
final sdbFactoryProvider = SdbFactoryProvider._();

final class SdbFactoryProvider
    extends $FunctionalProvider<SdbFactory, SdbFactory, SdbFactory>
    with $Provider<SdbFactory> {
  SdbFactoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'sdbFactoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$sdbFactoryHash();

  @$internal
  @override
  $ProviderElement<SdbFactory> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  SdbFactory create(Ref ref) {
    return sdbFactory(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SdbFactory value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SdbFactory>(value),
    );
  }
}

String _$sdbFactoryHash() => r'36ada0b5205e90df078780c27921f5bb87cbc7b2';
