import 'package:festenao_admin_base_app/screen/screen_bloc_import.dart';
import 'package:festenao_admin_base_app/screen/screen_import.dart';
import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';

export 'package:festenao_dashboard_base_app/src/provider/blog_providers.dart'
    show
        SdbProjectContentBlog,
        DbBlog,
        dbBlogStore,
        BlogSdb,
        SdbProjectsContentBlogCache;

// ─── Sdf* model classes ───────────────────────────────────────────────────────
// SDB counterparts of DbArtist / DbEvent / DbImage / DbLocation.
// Prefix "Sdf" = Sdb Festenao.

/// Common article fields shared by [SdfArtist] and [SdfEvent].
mixin SdfArticleMixin on ScvStringRecordBase {
  final name = CvField<String>('name');
  final author = CvField<String>('author');
  final type = CvField<String>('type');
  final subtitle = CvField<String>('subtitle');
  final content = CvField<String>('content');
  final tags = CvListField<String>('tags');
  final sort = CvField<String>('sort');
  final attributes = CvModelListField<CvAttribute>(
    'attributes',
    (_) => CvAttribute(),
  );
  final image = CvField<String>('image');
  final thumbnail = CvField<String>('thumbnail');
  final squareImage = CvField<String>('squareImage');

  List<CvField> get articleFields => [
    name,
    author,
    type,
    subtitle,
    content,
    tags,
    sort,
    attributes,
    image,
    thumbnail,
    squareImage,
  ];
}

/// SDB artist record — mirrors [DbArtist] for the local SDB world.
class SdfArtist extends ScvStringRecordBase with SdfArticleMixin {
  @override
  CvFields get fields => [...articleFields];
}

/// SDB event record — mirrors [DbEvent] for the local SDB world.
class SdfEvent extends ScvStringRecordBase with SdfArticleMixin {
  /// [SdfLocation] id
  final location = CvField<String>('location');

  /// Day (UTC string)
  final day = CvField<String>('day');

  /// Start time (inclusive)
  final beginTime = CvField<String>('beginTime');

  /// End time (exclusive)
  final endTime = CvField<String>('endTime');

  /// [SdfArtist] ids
  final artists = CvListField<String>('artists');

  @override
  CvFields get fields => [
    ...articleFields,
    location,
    day,
    beginTime,
    endTime,
    artists,
  ];
}

/// SDB image record — mirrors [DbImage] for the local SDB world.
class SdfImage extends ScvStringRecordBase {
  final name = CvField<String>('name');
  final blurHash = CvField<String>('blurHash');
  final width = CvField<int>('width');
  final height = CvField<int>('height');
  final copyright = CvField<String>('copyright');
  final mediaId = CvField<String>('mediaId');

  @override
  CvFields get fields => [name, copyright, blurHash, width, height, mediaId];
}

/// SDB location record — mirrors [DbLocation] for the local SDB world.
class SdfLocation extends ScvStringRecordBase {
  final name = CvField<String>('name');
  final attributes = CvModelListField<CvAttribute>(
    'attributes',
    (_) => CvAttribute(),
  );

  @override
  CvFields get fields => [name, attributes];
}

// ─── Stores ───────────────────────────────────────────────────────────────────

final sdfArtistStore = scvStringStoreFactory.store<SdfArtist>('artist');
final sdfEventStore = scvStringStoreFactory.store<SdfEvent>('event');
final sdfImageStore = scvStringStoreFactory.store<SdfImage>('image');
final sdfLocationStore = scvStringStoreFactory.store<SdfLocation>('location');

// ─── Multi-store festenao content SDB ────────────────────────────────────────

var sdfContentOpenOptions = SdbOpenDatabaseOptions(
  version: 2,
  schema: SdbDatabaseSchema(
    stores: [
      sdfArtistStore.schema(),
      sdfEventStore.schema(),
      sdfImageStore.schema(),
      sdfLocationStore.schema(),
      ...syncedSdbMediaSchemaStores,
    ],
  ),
);

var _sdfConstructorsInitialized = false;

void initSdfConstructors() {
  if (_sdfConstructorsInitialized) return;
  _sdfConstructorsInitialized = true;
  cvAddConstructors([
    SdfArtist.new,
    SdfEvent.new,
    SdfImage.new,
    SdfLocation.new,
  ]);
  cvAddConstructor(CvAttribute.new);
}

extension SdbContextSdbExt on SdfContentSdb {
  SdbDatabase get _db => db;
  // Artist
  Stream<List<SdfArtist>> onArtists() => sdfArtistStore.onRecords(_db);
  Future<SdfArtist> addArtist(SdfArtist artist) =>
      sdfArtistStore.add(_db, artist);
  Future<void> deleteArtist(String id) => sdfArtistStore.record(id).delete(_db);

  // Event
  Stream<List<SdfEvent>> onEvents() => sdfEventStore.onRecords(_db);
  Future<SdfEvent> addEvent(SdfEvent event) => sdfEventStore.add(_db, event);
  Future<void> deleteEvent(String id) => sdfEventStore.record(id).delete(_db);

  // Image
  Stream<List<SdfImage>> onImages() => sdfImageStore.onRecords(_db);
  Stream<SdfImage?> onImage(String id) =>
      sdfImageStore.record(id).onRecord(_db);
  Future<SdfImage> addImage(SdfImage image) => sdfImageStore.add(_db, image);
  Future<SdfImage> putImage(String id, SdfImage image) =>
      sdfImageStore.record(id).put(_db, image);
  Future<SdfImage?> getImage(String id) => sdfImageStore.record(id).get(_db);
  Future<void> deleteImage(String id) => sdfImageStore.record(id).delete(_db);

  // Location
  Stream<List<SdfLocation>> onLocations() => sdfLocationStore.onRecords(_db);
  Future<SdfLocation> addLocation(SdfLocation location) =>
      sdfLocationStore.add(_db, location);
  Future<void> deleteLocation(String id) =>
      sdfLocationStore.record(id).delete(_db);
}

extension FestenaoMediaSdbStreamExt on FestenaoMediaSdb {
  Stream<List<SdbFestenaoMediaFile>> onMediaFiles() =>
      sdbMediaStore.onRecords(database);
  Stream<SdbFestenaoMediaFile?> onMediaFile(String id) =>
      sdbMediaStore.record(id).onRecord(database);
  Stream<SdbFestenaoMediaFileStatus?> onMediaStatusFile(String id) =>
      sdbMediaStatusLocalStore.record(id).onRecord(database);
  Future<SdbFestenaoMediaFileStatus?> getMediaStatusFile(String id) =>
      sdbMediaStatusLocalStore.record(id).get(database);
}
