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
  late final TkCmsFirestoreDatabaseEntityCollectionRef<TkCmsFsProject>
  projectCollectionRef;

  late final String projectId;

  /// The root document path path for the single project, if specified.
  late final String singleProjectRootPath;

  /// Creates a new [FestenaoAppSingleProjectOptions] instance.
  FestenaoAppSingleProjectOptions({
    // required
    TkCmsFirestoreDatabaseEntityCollectionRef<TkCmsFsProject>?
    projectCollectionRef,
    // required
    String? projectId,
    // Deprecated
    String? singleProjectRootPath,
  }) {
    assert(
      singleProjectRootPath != null ||
          (projectCollectionRef != null && projectId != null),
      'Either singleProjectRootPath or projectCollectionRef/projectId must be provided',
    );
    if (singleProjectRootPath != null) {
      var parentCollection = firestoreDocPathGetParent(singleProjectRootPath);
      var entityType = firestorePathGetId(parentCollection);
      var parentDoc = firestoreCollPathGetParent(parentCollection);
      this.projectCollectionRef =
          projectCollectionRef ??
          fsProjectCollectionInfo
              .copyWith(id: entityType)
              .ref(
                rootDocument: parentDoc == null
                    ? null
                    : CvDocumentReference(parentDoc),
              );
      this.projectId = projectId ?? firestorePathGetId(singleProjectRootPath);
    } else {
      this.projectCollectionRef = projectCollectionRef!;
      this.projectId = projectId!;
    }
    this.singleProjectRootPath =
        singleProjectRootPath ??
        this.projectCollectionRef.collectionRef.doc(this.projectId).path;
  }

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
