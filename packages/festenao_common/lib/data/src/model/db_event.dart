import 'package:festenao_common/data/festenao_db.dart';

export 'db_article.dart';

const eventTypes = [
  eventTypeBal,
  eventTypeConcert,
  eventTypeArtist,
  eventTypeCoffee,
  eventTypeStage,
  eventTypeIntimiste,
];
const eventTypeConcert = 'concert';
const eventTypeBal = 'bal';
const eventTypeArtist = 'artist';
const eventTypeCoffee = 'coffee';
const eventTypeStage = 'stage'; // Stage
const eventTypeIntimiste = 'intimiste'; // Stage

const eventTags = [eventTagMarker, eventTagClosed];
const eventTagMarker = 'marker';
const eventTagClosed = 'closed'; // Typically for marker,
// close all following events in the same day by default, unless favorites

/// Artist id must allow sorting (i.e. typically lastname_firstname
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

  /// Ok for only 1
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
