// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A global provider of [FestenaoAppFlavorContext].
///
/// Must be overridden in the app.

@ProviderFor(festenaoAppFlavorContext)
final festenaoAppFlavorContextProvider = FestenaoAppFlavorContextProvider._();

/// A global provider of [FestenaoAppFlavorContext].
///
/// Must be overridden in the app.

final class FestenaoAppFlavorContextProvider
    extends
        $FunctionalProvider<
          FestenaoAppFlavorContext,
          FestenaoAppFlavorContext,
          FestenaoAppFlavorContext
        >
    with $Provider<FestenaoAppFlavorContext> {
  /// A global provider of [FestenaoAppFlavorContext].
  ///
  /// Must be overridden in the app.
  FestenaoAppFlavorContextProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'festenaoAppFlavorContextProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$festenaoAppFlavorContextHash();

  @$internal
  @override
  $ProviderElement<FestenaoAppFlavorContext> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  FestenaoAppFlavorContext create(Ref ref) {
    return festenaoAppFlavorContext(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(FestenaoAppFlavorContext value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<FestenaoAppFlavorContext>(value),
    );
  }
}

String _$festenaoAppFlavorContextHash() =>
    r'4701d23e0fc1022a02a0ad85558543f80c05cb6a';
