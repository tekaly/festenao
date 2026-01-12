/// Global app options
class FestenaoDataGlobalsOptions {
  /// Generated app/$sourceId in firestore app/$sourceId in storage
  /// for example 'YnTET4gY9vYUChSQrt4e'
  final String sourceId;

  /// for example 'festenao' (not available)
  final String fbProjectId; // Firestore project id

  /// The root path of the app.
  String get appRootPath => 'app/$sourceId';

  /// Global options
  FestenaoDataGlobalsOptions({
    required this.fbProjectId,
    required this.sourceId,
  });
}
