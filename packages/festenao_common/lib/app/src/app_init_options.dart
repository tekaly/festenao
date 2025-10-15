/// Initialization options for the Festenao app.
class FestenaoAppOptions {
  /// Options for initializing a single project, if applicable.
  final FestenaoAppSingleProjectOptions? singleProject;

  /// Creates a new [FestenaoAppOptions] instance.
  const FestenaoAppOptions({this.singleProject});
}

/// Initialization options for a single Festenao project.
class FestenaoAppSingleProjectOptions {
  /// The root path for the single project, if specified.
  final String? singleProjectRootPath;

  /// Creates a new [FestenaoAppSingleProjectOptions] instance.
  const FestenaoAppSingleProjectOptions({this.singleProjectRootPath});
}
