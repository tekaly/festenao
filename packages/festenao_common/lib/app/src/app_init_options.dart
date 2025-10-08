/// Initialization options for the Festenao app.
class FestenaoAppInitOptions {
  /// Options for initializing a single project, if applicable.
  final FestenaoAppSingleProjectInitOptions? singleProject;

  /// Creates a new [FestenaoAppInitOptions] instance.
  const FestenaoAppInitOptions({this.singleProject});
}

/// Initialization options for a single Festenao project.
class FestenaoAppSingleProjectInitOptions {
  /// The root path for the single project, if specified.
  final String? singleProjectRootPath;

  /// Creates a new [FestenaoAppSingleProjectInitOptions] instance.
  const FestenaoAppSingleProjectInitOptions({this.singleProjectRootPath});
}
