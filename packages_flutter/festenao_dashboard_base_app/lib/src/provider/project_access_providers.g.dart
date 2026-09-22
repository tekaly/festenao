// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_access_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The identity of the signed in user, null when signed out or still unknown.

@ProviderFor(rpdIdentity)
final rpdIdentityProvider = RpdIdentityProvider._();

/// The identity of the signed in user, null when signed out or still unknown.

final class RpdIdentityProvider
    extends
        $FunctionalProvider<
          TkCmsFbIdentity?,
          TkCmsFbIdentity?,
          TkCmsFbIdentity?
        >
    with $Provider<TkCmsFbIdentity?> {
  /// The identity of the signed in user, null when signed out or still unknown.
  RpdIdentityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rpdIdentityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rpdIdentityHash();

  @$internal
  @override
  $ProviderElement<TkCmsFbIdentity?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  TkCmsFbIdentity? create(Ref ref) {
    return rpdIdentity(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(TkCmsFbIdentity? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<TkCmsFbIdentity?>(value),
    );
  }
}

String _$rpdIdentityHash() => r'c8a73ed377de8414956650ba81e0fab832e64546';

/// The projects the signed in identity has access to.
///
/// The list itself comes from the local database, which is what the rest of
/// the app reads. While this provider is watched it also mirrors the firestore
/// access list into that local database, so the screen showing it is the one
/// keeping it fresh — exactly what `ProjectsSdbScreenBloc` did.

@ProviderFor(RpdProjectsAccess)
final rpdProjectsAccessProvider = RpdProjectsAccessProvider._();

/// The projects the signed in identity has access to.
///
/// The list itself comes from the local database, which is what the rest of
/// the app reads. While this provider is watched it also mirrors the firestore
/// access list into that local database, so the screen showing it is the one
/// keeping it fresh — exactly what `ProjectsSdbScreenBloc` did.
final class RpdProjectsAccessProvider
    extends $StreamNotifierProvider<RpdProjectsAccess, ProjectsAccessState> {
  /// The projects the signed in identity has access to.
  ///
  /// The list itself comes from the local database, which is what the rest of
  /// the app reads. While this provider is watched it also mirrors the firestore
  /// access list into that local database, so the screen showing it is the one
  /// keeping it fresh — exactly what `ProjectsSdbScreenBloc` did.
  RpdProjectsAccessProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'rpdProjectsAccessProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$rpdProjectsAccessHash();

  @$internal
  @override
  RpdProjectsAccess create() => RpdProjectsAccess();
}

String _$rpdProjectsAccessHash() => r'37454f7d093d6ad071cae2138b25108901b0389d';

/// The projects the signed in identity has access to.
///
/// The list itself comes from the local database, which is what the rest of
/// the app reads. While this provider is watched it also mirrors the firestore
/// access list into that local database, so the screen showing it is the one
/// keeping it fresh — exactly what `ProjectsSdbScreenBloc` did.

abstract class _$RpdProjectsAccess
    extends $StreamNotifier<ProjectsAccessState> {
  Stream<ProjectsAccessState> build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ProjectsAccessState>, ProjectsAccessState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProjectsAccessState>, ProjectsAccessState>,
              AsyncValue<ProjectsAccessState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

/// The access of the signed in user to one entity, keyed by its firestore id.
///
/// The entity is looked up in the local mirror first
/// ([currentProjectsMirrorDbProvider]) and in firestore when it has no copy of
/// it — which is always the case for an entity that has no mirror at all.

@ProviderFor(RpdProjectAccess)
final rpdProjectAccessProvider = RpdProjectAccessFamily._();

/// The access of the signed in user to one entity, keyed by its firestore id.
///
/// The entity is looked up in the local mirror first
/// ([currentProjectsMirrorDbProvider]) and in firestore when it has no copy of
/// it — which is always the case for an entity that has no mirror at all.
final class RpdProjectAccessProvider
    extends $StreamNotifierProvider<RpdProjectAccess, ProjectAccessState> {
  /// The access of the signed in user to one entity, keyed by its firestore id.
  ///
  /// The entity is looked up in the local mirror first
  /// ([currentProjectsMirrorDbProvider]) and in firestore when it has no copy of
  /// it — which is always the case for an entity that has no mirror at all.
  RpdProjectAccessProvider._({
    required RpdProjectAccessFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'rpdProjectAccessProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$rpdProjectAccessHash();

  @override
  String toString() {
    return r'rpdProjectAccessProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  RpdProjectAccess create() => RpdProjectAccess();

  @override
  bool operator ==(Object other) {
    return other is RpdProjectAccessProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$rpdProjectAccessHash() => r'982060b115cdba687b5f0d45ff7b9f63a2beab8e';

/// The access of the signed in user to one entity, keyed by its firestore id.
///
/// The entity is looked up in the local mirror first
/// ([currentProjectsMirrorDbProvider]) and in firestore when it has no copy of
/// it — which is always the case for an entity that has no mirror at all.

final class RpdProjectAccessFamily extends $Family
    with
        $ClassFamilyOverride<
          RpdProjectAccess,
          AsyncValue<ProjectAccessState>,
          ProjectAccessState,
          Stream<ProjectAccessState>,
          String
        > {
  RpdProjectAccessFamily._()
    : super(
        retry: null,
        name: r'rpdProjectAccessProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The access of the signed in user to one entity, keyed by its firestore id.
  ///
  /// The entity is looked up in the local mirror first
  /// ([currentProjectsMirrorDbProvider]) and in firestore when it has no copy of
  /// it — which is always the case for an entity that has no mirror at all.

  RpdProjectAccessProvider call(String entityId) =>
      RpdProjectAccessProvider._(argument: entityId, from: this);

  @override
  String toString() => r'rpdProjectAccessProvider';
}

/// The access of the signed in user to one entity, keyed by its firestore id.
///
/// The entity is looked up in the local mirror first
/// ([currentProjectsMirrorDbProvider]) and in firestore when it has no copy of
/// it — which is always the case for an entity that has no mirror at all.

abstract class _$RpdProjectAccess extends $StreamNotifier<ProjectAccessState> {
  late final _$args = ref.$arg as String;
  String get entityId => _$args;

  Stream<ProjectAccessState> build(String entityId);
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref =
        this.ref as $Ref<AsyncValue<ProjectAccessState>, ProjectAccessState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<ProjectAccessState>, ProjectAccessState>,
              AsyncValue<ProjectAccessState>,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, () => build(_$args));
  }
}
