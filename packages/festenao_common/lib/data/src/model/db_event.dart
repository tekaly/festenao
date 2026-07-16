import 'package:festenao_common/data/festenao_db.dart';

export 'db_article.dart';

/// Known event types.
const eventTypes = [
  eventTypeBal,
  eventTypeConcert,
  eventTypeArtist,
  eventTypeCoffee,
  eventTypeStage,
  eventTypeIntimiste,
];

/// Event type: concert.
const eventTypeConcert = 'concert';

/// Event type: bal.
const eventTypeBal = 'bal';

/// Event type: artist-specific event.
const eventTypeArtist = 'artist';

/// Event type: coffee / casual event.
const eventTypeCoffee = 'coffee';

/// Event type: stage event.
const eventTypeStage = 'stage'; // Stage

/// Event type: intimiste.
const eventTypeIntimiste = 'intimiste'; // Stage

/// Tags used for events.
const eventTags = [eventTagMarker, eventTagClosed];

/// Event tag indicating a map marker.
const eventTagMarker = 'marker';

/// Event tag indicating the event/day is closed.
const eventTagClosed = 'closed'; // Typically for marker,

/// Event record stored as a string-keyed record with common article fields.
///
/// An event represents a scheduled activity (e.g. concert, bal, stage activity) at a specific location
/// and time, optionally associated with one or more artists.
///
/// ### Fields
/// - [location]: Reference identifier matching [DbLocation.id].
/// - [day]: Date of the event in UTC format (e.g., `2026-07-16`).
/// - [beginTime]: Event starting time, usually in ISO-8601 or standard HH:mm format (inclusive).
/// - [endTime]: Event ending time, usually in ISO-8601 or standard HH:mm format (exclusive).
/// - [artists]: List of artist references matching [DbArtist.id].
///
/// ### Example Usage
///
/// #### Instantiating and Writing:
/// ```dart
/// var event = DbEvent()
///   ..id = 'concert-daft-punk'
///   ..name.v = 'Daft Punk Live at Stage A'
///   ..type.v = eventTypeConcert
///   ..location.v = 'stage-a'
///   ..day.v = '2026-07-16'
///   ..beginTime.v = '21:00'
///   ..endTime.v = '23:00'
///   ..artists.v = ['daft-punk'];
///
/// // Write to Sembast database (FestenaoDb)
/// await dbEventStoreRef.record(event.id).put(db, event);
/// ```
///
/// #### Querying Events:
/// ```dart
/// // Fetch all events
/// List<DbEvent> events = await dbEventStoreRef.query().getRecords(db);
///
/// // Find a specific event by ID
/// DbEvent? event = await dbEventStoreRef.record('concert-daft-punk').get(db);
/// ```
class DbEvent extends DbStringRecordBase with DbArticleMixin {
  @override
  List<CvField> get fields => [
    ...articleFields,
    location,
    day,
    beginTime,
    endTime,
    artists,
  ];

  /// The associated location ID, matching a [DbLocation] record key.
  final location = CvField<String>('location');

  /// Day of the event in UTC format (e.g., `YYYY-MM-DD`).
  final day = CvField<String>('day');

  /// Start time (inclusive) of the event (e.g., `HH:mm` or ISO-8601 timestamp).
  final beginTime = CvField<String>('beginTime');

  /// End time (exclusive) of the event (e.g., `HH:mm` or ISO-8601 timestamp).
  final endTime = CvField<String>('endTime');

  /// List of artist IDs, matching [DbArtist] record keys.
  final artists = CvListField<String>('artists');

  @override
  String get articleKind => articleKindEvent;

  /// Returns a unique associated artist ID if exactly one can be inferred from attributes.
  ///
  /// Scans the [attributes] list for URLs matching the `artist:` scheme and returns the
  /// ID if all found matching schemes point to the same artist. Returns `null` if there
  /// are zero, or more than one distinct artist IDs linked.
  String? getUniqueArtistId() {
    var attributes = this.attributes.v;
    if (attributes != null) {
      var artistIds = <String>{};
      for (var attribute in attributes) {
        var value = attribute.value.v;
        if (value != null) {
          var artistId = attrGetArtistId(value);
          if (artistId != null) {
            artistIds.add(artistId);
          }
        }
      }
      if (artistIds.length == 1) {
        return artistIds.first;
      }
    }
    return null;
  }
}

/// Default model instance for [DbEvent].
final dbEventModel = DbEvent();
