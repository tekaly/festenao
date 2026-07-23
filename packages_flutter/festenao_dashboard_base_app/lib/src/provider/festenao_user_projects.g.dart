// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'festenao_user_projects.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Users projects, the current (possibly per user) database.

@ProviderFor(rpdUserProjectsDb)
final rpdUserProjectsDbProvider = RpdUserProjectsDbProvider._();

/// Users projects, the current (possibly per user) database.

final class RpdUserProjectsDbProvider
    extends
        $FunctionalProvider<UserProjectsSdb, UserProjectsSdb, UserProjectsSdb>
    with $Provider<UserProjectsSdb> {
  /// Users projects, the current (possibly per user) database.
  RpdUserProjectsDbProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rpdUserProjectsDbProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rpdUserProjectsDbHash();

  @$internal
  @override
  $ProviderElement<UserProjectsSdb> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserProjectsSdb create(Ref ref) {
    return rpdUserProjectsDb(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserProjectsSdb value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserProjectsSdb>(value),
    );
  }
}

String _$rpdUserProjectsDbHash() => r'42b0d0c7fcc07897b5790e5769471fa34665bc7b';

/// User projects

@ProviderFor(rpdUserProjects)
final rpdUserProjectsProvider = RpdUserProjectsFamily._();

/// User projects

final class RpdUserProjectsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SdbUserProject>>,
          List<SdbUserProject>,
          Stream<List<SdbUserProject>>
        >
    with
        $FutureModifier<List<SdbUserProject>>,
        $StreamProvider<List<SdbUserProject>> {
  /// User projects
  RpdUserProjectsProvider._({
    required RpdUserProjectsFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'rpdUserProjectsProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rpdUserProjectsHash();

  @override
  String toString() {
    return r'rpdUserProjectsProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<SdbUserProject>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SdbUserProject>> create(Ref ref) {
    final argument = this.argument as String;
    return rpdUserProjects(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is RpdUserProjectsProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rpdUserProjectsHash() => r'8408405fa7e1803cfa6925e9e115468ef9491370';

/// User projects

final class RpdUserProjectsFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<SdbUserProject>>, String> {
  RpdUserProjectsFamily._()
    : super(
        retry: null,
        name: r'rpdUserProjectsProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// User projects

  RpdUserProjectsProvider call(String userId) =>
      RpdUserProjectsProvider._(argument: userId, from: this);

  @override
  String toString() => r'rpdUserProjectsProvider';
}
