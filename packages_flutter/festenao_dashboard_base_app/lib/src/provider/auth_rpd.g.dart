// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_rpd.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// A boolean that indicates whether RPD authentication is enabled.
/// Defaults to false.

@ProviderFor(rpdHasAuth)
final rpdHasAuthProvider = RpdHasAuthProvider._();

/// A boolean that indicates whether RPD authentication is enabled.
/// Defaults to false.

final class RpdHasAuthProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// A boolean that indicates whether RPD authentication is enabled.
  /// Defaults to false.
  RpdHasAuthProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rpdHasAuthProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rpdHasAuthHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return rpdHasAuth(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$rpdHasAuthHash() => r'8eb7353a31a78b3e06b190df87e926c742f3d0a9';

/// Identity state

@ProviderFor(rpdTkCmsFbIdentityBlocState)
final rpdTkCmsFbIdentityBlocStateProvider =
    RpdTkCmsFbIdentityBlocStateProvider._();

/// Identity state

final class RpdTkCmsFbIdentityBlocStateProvider
    extends
        $FunctionalProvider<
          AsyncValue<TkCmsFbIdentityBlocState>,
          TkCmsFbIdentityBlocState,
          Stream<TkCmsFbIdentityBlocState>
        >
    with
        $FutureModifier<TkCmsFbIdentityBlocState>,
        $StreamProvider<TkCmsFbIdentityBlocState> {
  /// Identity state
  RpdTkCmsFbIdentityBlocStateProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rpdTkCmsFbIdentityBlocStateProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rpdTkCmsFbIdentityBlocStateHash();

  @$internal
  @override
  $StreamProviderElement<TkCmsFbIdentityBlocState> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<TkCmsFbIdentityBlocState> create(Ref ref) {
    return rpdTkCmsFbIdentityBlocState(ref);
  }
}

String _$rpdTkCmsFbIdentityBlocStateHash() =>
    r'94f31cb4005946ac4f42b3bbdb4470e56c6b1f8c';
