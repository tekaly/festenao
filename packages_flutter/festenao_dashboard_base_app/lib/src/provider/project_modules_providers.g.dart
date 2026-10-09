// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'project_modules_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The modules on in the project [projectId] for the signed in user, from
/// the local projects database: null when every module is on, or while the
/// project is not known yet (so nothing is hidden by mistake).

@ProviderFor(projectModules)
final projectModulesProvider = ProjectModulesFamily._();

/// The modules on in the project [projectId] for the signed in user, from
/// the local projects database: null when every module is on, or while the
/// project is not known yet (so nothing is hidden by mistake).

final class ProjectModulesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<String>?>,
          List<String>?,
          Stream<List<String>?>
        >
    with $FutureModifier<List<String>?>, $StreamProvider<List<String>?> {
  /// The modules on in the project [projectId] for the signed in user, from
  /// the local projects database: null when every module is on, or while the
  /// project is not known yet (so nothing is hidden by mistake).
  ProjectModulesProvider._({
    required ProjectModulesFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'projectModulesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectModulesHash();

  @override
  String toString() {
    return r'projectModulesProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $StreamProviderElement<List<String>?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<String>?> create(Ref ref) {
    final argument = this.argument as String;
    return projectModules(ref, argument);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectModulesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectModulesHash() => r'6e3cf2ff29e6f4b5291c750ca5017c4233d89b52';

/// The modules on in the project [projectId] for the signed in user, from
/// the local projects database: null when every module is on, or while the
/// project is not known yet (so nothing is hidden by mistake).

final class ProjectModulesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<String>?>, String> {
  ProjectModulesFamily._()
    : super(
        retry: null,
        name: r'projectModulesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// The modules on in the project [projectId] for the signed in user, from
  /// the local projects database: null when every module is on, or while the
  /// project is not known yet (so nothing is hidden by mistake).

  ProjectModulesProvider call(String projectId) =>
      ProjectModulesProvider._(argument: projectId, from: this);

  @override
  String toString() => r'projectModulesProvider';
}
