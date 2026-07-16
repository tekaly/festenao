import 'package:festenao_common/data/festenao_db.dart';

/// Represents a location record stored in the Sembast database.
///
/// Locations represent venues, stages, or points of interest for events.
///
/// ### Fields
/// - [name]: The human-readable name of the location (e.g., `'Stage A'`).
/// - [attributes]: List of linked [CvAttribute] elements containing links, coordinates, or contact info.
///
/// ### Example Usage
///
/// #### Instantiating and Writing:
/// ```dart
/// var location = DbLocation()
///   ..id = 'stage-a'
///   ..name.v = 'Main Stage A'
///   ..attributes.v = [
///     CvAttribute()
///       ..name.v = 'Google Maps'
///       ..value.v = 'https://maps.google.com/?q=Main+Stage'
///       ..type.v = attributeTypeMap
///   ];
///
/// // Write to Sembast database (FestenaoDb)
/// await dbInfoStoreRef.record(location.id).put(db, location); // Or the location-specific store ref
/// ```
class DbLocation extends DbStringRecordBase {
  /// The human-friendly name of the location (displayed in the UI).
  final name = CvField<String>('name');

  /// Custom attributes or links associated with the location (e.g. map links, GPS coordinates).
  final attributes = CvModelListField<CvAttribute>(
    'attributes',
    (_) => CvAttribute(),
  );

  @override
  List<CvField> get fields => [name, attributes];
}
