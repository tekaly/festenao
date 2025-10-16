import 'package:festenao_common/festenao_firestore.dart';

/// Initialization options for the Festenao app.
/// no options means app/xxx/project/yyy
class FestenaoAppOptions {
  /// Options for initializing a single project, if applicable.
  FestenaoAppSingleProjectOptions? get singleProject =>
      projects?.anyAs<FestenaoAppSingleProjectOptions?>();

  FestenaoAppMultiProjectsOptions? get multiProjects =>
      projects?.anyAs<FestenaoAppMultiProjectsOptions?>();
  late final FestenaoAppProjectsOptions? projects;

  /// Creates a new [FestenaoAppOptions] instance.
  FestenaoAppOptions({
    FestenaoAppSingleProjectOptions? singleProject,
    FestenaoAppMultiProjectsOptions? multiProjects,
  }) {
    assert(
      singleProject == null || multiProjects == null,
      'Cannot specify both singleProject and multiProjects',
    );
    assert(
      singleProject != null || multiProjects != null,
      'Must specify either singleProject or multiProjects',
    );
    projects = singleProject ?? multiProjects;
  }
}

/// Initialization options for a single Festenao project.
class FestenaoAppSingleProjectOptions implements FestenaoAppProjectsOptions {
  /// The root document path path for the single project, if specified.
  final String singleProjectRootPath;

  /// Creates a new [FestenaoAppSingleProjectOptions] instance.
  const FestenaoAppSingleProjectOptions({required this.singleProjectRootPath});

  @override
  String get projectCollectionPath =>
      firestoreDocPathGetParent(singleProjectRootPath);
}

/// Initialization options for a single Festenao project.
abstract class FestenaoAppProjectsOptions {
  /// The root path for the single project, if specified.
  String get projectCollectionPath;
}

/// Initialization options for a single Festenao project.
class FestenaoAppMultiProjectsOptions implements FestenaoAppProjectsOptions {
  final TkCmsFirestoreDatabaseEntityCollectionRef<TkCmsFsProject>
  projectCollectionRef;

  /// The root path for the single project, if specified.
  @override
  String get projectCollectionPath => projectCollectionRef.path;

  /// Creates a new [FestenaoAppMultiProjectsOptions] instance.
  const FestenaoAppMultiProjectsOptions({required this.projectCollectionRef});
}
