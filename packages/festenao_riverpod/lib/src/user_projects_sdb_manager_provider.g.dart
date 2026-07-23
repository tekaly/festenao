// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_projects_sdb_manager_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app [UserProjectsSdbManager].
///
/// Must be overridden by the app.

@ProviderFor(festenaoUserProjectsSdbManager)
final festenaoUserProjectsSdbManagerProvider =
    FestenaoUserProjectsSdbManagerProvider._();

/// The app [UserProjectsSdbManager].
///
/// Must be overridden by the app.

final class FestenaoUserProjectsSdbManagerProvider
    extends
        $FunctionalProvider<
          UserProjectsSdbManager,
          UserProjectsSdbManager,
          UserProjectsSdbManager
        >
    with $Provider<UserProjectsSdbManager> {
  /// The app [UserProjectsSdbManager].
  ///
  /// Must be overridden by the app.
  FestenaoUserProjectsSdbManagerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'festenaoUserProjectsSdbManagerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$festenaoUserProjectsSdbManagerHash();

  @$internal
  @override
  $ProviderElement<UserProjectsSdbManager> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  UserProjectsSdbManager create(Ref ref) {
    return festenaoUserProjectsSdbManager(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserProjectsSdbManager value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserProjectsSdbManager>(value),
    );
  }
}

String _$festenaoUserProjectsSdbManagerHash() =>
    r'7875e723ac016d100e2d6f34f83f9db108eb1c5c';
