// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_projects_sdb_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The current per user [UserProjectsSdb], null until
/// [festenaoUserProjectsSdbManagerProvider] has one (i.e. until
/// [UserProjectsSdbManager.setCurrentUser] has been called).
///
/// Follows [UserProjectsSdbManager.onCurrentDb].

@ProviderFor(festenaoUserProjectsSdb)
final festenaoUserProjectsSdbProvider = FestenaoUserProjectsSdbProvider._();

/// The current per user [UserProjectsSdb], null until
/// [festenaoUserProjectsSdbManagerProvider] has one (i.e. until
/// [UserProjectsSdbManager.setCurrentUser] has been called).
///
/// Follows [UserProjectsSdbManager.onCurrentDb].

final class FestenaoUserProjectsSdbProvider
    extends
        $FunctionalProvider<
          AsyncValue<UserProjectsSdb?>,
          UserProjectsSdb?,
          Stream<UserProjectsSdb?>
        >
    with $FutureModifier<UserProjectsSdb?>, $StreamProvider<UserProjectsSdb?> {
  /// The current per user [UserProjectsSdb], null until
  /// [festenaoUserProjectsSdbManagerProvider] has one (i.e. until
  /// [UserProjectsSdbManager.setCurrentUser] has been called).
  ///
  /// Follows [UserProjectsSdbManager.onCurrentDb].
  FestenaoUserProjectsSdbProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'festenaoUserProjectsSdbProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$festenaoUserProjectsSdbHash();

  @$internal
  @override
  $StreamProviderElement<UserProjectsSdb?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<UserProjectsSdb?> create(Ref ref) {
    return festenaoUserProjectsSdb(ref);
  }
}

String _$festenaoUserProjectsSdbHash() =>
    r'a2371bac233f4fbd789411438c9fe1ecb3d71335';
