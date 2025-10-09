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

  /// DbLocation id
  final location = CvField<String>('location');

  /// Day (UTC string)
  final day = CvField<String>('day');

  /// Start time (inclusive)
  final beginTime = CvField<String>('beginTime');

  /// End time (exclusive)
  final endTime = CvField<String>('endTime');

  /// DbArtists ids
  final artists = CvListField<String>('artists');

  @override
  String get articleKind => articleKindEvent;

  /// Returns a unique associated artist id if exactly one can be inferred from attributes.
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

final dbEventModel = DbEvent();
