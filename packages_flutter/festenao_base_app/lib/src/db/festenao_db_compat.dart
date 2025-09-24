// ignore_for_file: public_member_api_docs

import 'package:festenao_common/data/calendar.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_storage.dart';
import 'package:festenao_common/data/festenao_sync.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:tekaly_sembast_synced/synced_db_storage.dart';
import 'package:tekartik_app_flutter_sembast/sembast.dart';
import 'package:tekartik_common_utils/common_utils_import.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:tekartik_firebase_storage_rest/storage_json.dart';

import 'firebase_compat.dart';

FestenaoDb? _festenaoDb;
final assetsDataPath = url.join('assets', 'data');
final assetsDataImagePath = url.join(assetsDataPath, 'img');

set festenaoDb(FestenaoDb festenaoDb) => _festenaoDb = festenaoDb;

FestenaoDb get festenaoDb => _festenaoDb!;
final dbAppInfos = <String, AppInfo>{};
Map<String, AppInfo> get appInfos => dbAppInfos;

final appPlayerPlaylists = <String, AppPlayerPlayList>{};

enum AppArticleKind { event, location, info, artist }

var _appArticleKindPrefix = <AppArticleKind, String>{
  AppArticleKind.artist: articleKindArtist,
  AppArticleKind.event: articleKindEvent,
  AppArticleKind.info: articleKindInfo,
  AppArticleKind.location: articleKindLocation,
};

abstract class AppArticle implements Comparable<AppArticle> {
  String get id;

  AppArticleKind get kind;

  @override
  int compareTo(AppArticle other) => id.compareTo(other.id);

  /// Set from images
  String? thumbnail;

  /// Set from images
  String? mainImageId;

  DbArticle get dbArticle;

  bool hasTag(String tag) => dbArticle.tags.v?.contains(tag) ?? false;

  bool? _hidden;
  bool? _cancelled;
  bool? _inProgress;

  bool get hidden => _hidden ?? hasTag(articleTagHidden);

  bool get cancelled => _cancelled ?? hasTag(articleTagCancelled);

  bool get inProgress => _inProgress ?? hasTag(articleTagInProgress);

  @override
  String toString() => id;
}

class AppInfo extends AppArticle with AppArticleMixin {
  final DbInfo dbInfo;

  AppInfo(this.dbInfo);

  @override
  AppArticleKind get kind => AppArticleKind.info;

  @override
  DbArticle get dbArticle => dbInfo;
}

extension AppArticleExt on AppArticle {
  String? get subtitle => dbArticle.subtitle.v?.trimmedNonEmpty();

  List<CvAttribute>? get attributes => dbArticle.attributes.v;

  String? get name => dbArticle.name.v?.trimmedNonEmpty();

  String? get type => dbArticle.type.v?.trimmedNonEmpty();

  String? get content => dbArticle.content.v?.trimmedNonEmpty();
}

class AppLocation extends AppArticle {
  final DbInfo dbInfo;

  AppLocation(this.dbInfo);

  @override
  String get id => dbInfo.id;

  @override
  AppArticleKind get kind => AppArticleKind.location;

  @override
  DbArticle get dbArticle => dbInfo;
}

class AppEvent extends AppArticle {
  final DbEvent dbEvent;
  AppLocation? location;

  AppArtist? get artist => artists.length == 1 ? artists.first : null;
  final artists = <AppArtist>[];

  AppEvent(this.dbEvent);

  @override
  String get id => dbEvent.id;

  @override
  AppArticleKind get kind => AppArticleKind.event;

  @override
  DbArticle get dbArticle => dbEvent;

  @override
  int compareTo(AppArticle other) {
    var otherAppEvent = other as AppEvent;
    var cmp = dbEvent.day.v!.compareTo(otherAppEvent.dbEvent.day.v!);
    if (cmp != 0) {
      return cmp;
    }
    cmp = dbEvent.beginTime.v!.compareTo(otherAppEvent.dbEvent.beginTime.v!);
    if (cmp != 0) {
      return cmp;
    }
    return super.compareTo(other);
  }

  String? _timeText;

  String get timeText =>
      _timeText ??= CalendarTime(text: dbEvent.beginTime.v!).toString();

  CalendarDay get day => parseCalendarDayOrNull(dbEvent.day.v!)!;

  CalendarTime get startTime =>
      parseStartCalendarTimeOrThrow(dbEvent.beginTime.v!);

  DateTime get startDayTime => day.toDateTime(startTime);

  @override
  String toString() => 'event(artist: $artist)';
}

mixin AppArticleMixin implements AppArticle {
  @override
  String get id => dbArticle.id;
}

class AppArtist extends AppArticle with AppArticleMixin {
  final DbArtist dbArtist;

  @override
  AppArticleKind get kind => AppArticleKind.artist;

  /// filled
  final events = <AppEvent>[];

  AppArtist({required this.dbArtist});

  AppEvent? get singleEvent => events.length == 1 ? events.first : null;

  @override
  DbArticle get dbArticle => dbArtist;

  @override
  String toString() {
    // TODO: implement toString
    return super.toString();
  }
}

AppArtist? appGetArtistById(String id) {
  return dbAppArtists[id];
}

/// But hidden
List<AppArtist> appGetAllArtist() {
  return dbAppArtists.values.where((element) => !element.hidden).toList()
    ..sort();
}

List<AppEvent> appGetAllEvents() {
  return appEvents.values.where((element) => !element.hidden).toList()..sort();
}

AppEvent? appGetEventById(String id) {
  return appEvents[id];
}

AppInfo? appGetInfoById(String id) {
  return appInfos[id];
}

AppArticle? appGetArticleByKindAndId(AppArticleKind appArticleKind, String id) {
  switch (appArticleKind) {
    case AppArticleKind.artist:
      return appGetArtistById(id);
    case AppArticleKind.event:
      return appGetEventById(id);
    case AppArticleKind.info:
      return appGetInfoById(id);
    case AppArticleKind.location:
      return appGetLocationById(id);
  }
}

String appGetArticlePrefix(AppArticleKind appArticleKind) {
  return _appArticleKindPrefix[appArticleKind]!;
}

AppLocation? appGetLocationById(String id) {
  return appLocations[id];
}

/// By ID Access
@protected
final dbAppArtists = <String, AppArtist>{};

final appLocations = <String, AppLocation>{};

//@Deprecated('No direct access')
final appEvents = <String, AppEvent>{};

/// By ID Access - to deprecate
final dbImages = <String, DbImage>{};

/// Initialized during initData
late List<String> gAppAssetList;
late List<String> gAppAssetDataImgList;

late FestenaoUserDb festenaoUserDb;

class FesteanoAppDbDataContext {
  final DatabaseFactory factory;
  final FestenaoAppSync? appSync;
  final String packageName;

  FesteanoAppDbDataContext({
    required this.factory,
    this.appSync,
    required this.packageName,
  });
}

Future<FesteanoAppDbDataContext> initWithAssetAndStorage({
  required String packageName,
  required String projectId,
  required String storageBucket,
  required String storageRootPath,
  FestenaoDb? useFestenaoDb,
  bool? dev,
}) async {
  dev ??= isTargetDev;
  var factory = initDatabaseFactory(packageName: packageName);
  festenaoDb = useFestenaoDb ?? FestenaoDb(factory);

  if (useFestenaoDb == null) {
    /// Init from asset first
    var appSync = FestenaoAppSyncExport(
      festenaoDb,
      fetchExport: (int changeId) async {
        try {
          var data = await rootBundle.loadString(assetsDataExportPath);
          return data;
        } catch (e, st) {
          if (kDebugMode) {
            print('No data in assets $e $st');
          }
          rethrow;
        }
      },
      fetchExportMeta: () async {
        try {
          var map =
              jsonDecode(await rootBundle.loadString(assetsDataExportMetaPath))
                  as Map;
          return map.cast<String, Object?>();
        } catch (e, st) {
          if (kDebugMode) {
            print('No data in assets $e $st');
          }
          rethrow;
        }
      },
    );
    try {
      await appSync.sync();
    } catch (e, st) {
      // Allow failure if no assets
      if (kDebugMode) {
        print('asset data sync failed $e $st');
      }
    }
  }
  // Always init the globals from the database
  await initData(festenaoDb);
  /*

  if (appPlayerPlaylists.isNotEmpty) {
    await initAudioCache(packageName: packageName);
  }*/

  var api = UnauthenticatedStorageApi(
    client: null,
    storageBucket: storageBucket,
  );
  //var client = httpClientFactory.newClient();

  //var noCache = '&v=${DateTime.now().millisecondsSinceEpoch}';

  // print('storageBucket: $storageBucket');
  await festenaoDb.importDatabaseFromUnauthenticatedStorage(
    importContext: SyncedDbUnauthenticatedStorageApiImportContext(
      storageApi: api,
      rootPath: url.join(storageRootPath, storageDataDirPart),
      metaBasenameSuffix: dev ? '_dev' : '',
    ),
  );

  appDataContext = AppDataContext(
    projectId: projectId,
    rootPath: storageRootPath,
  );

  return FesteanoAppDbDataContext(factory: factory, packageName: packageName);
}

/// Init data called from either asset or imported db
Future<void> initData(FestenaoDb festenaoDb) async {
  if (kDebugMode) {
    print('initData');
  }
  var db = await festenaoDb.database;
  var allArtists = await dbArtistStoreRef.find(db);
  var allImages = await dbImageStoreRef.find(db);
  var allEvents = await dbEventStoreRef
      .query(
        finder: Finder(
          sortOrders: [
            SortOrder(dbEventModel.day.name),
            SortOrder(dbEventModel.beginTime.name),
          ],
        ),
      )
      .getRecords(db);
  var allInfos = await dbInfoStoreRef.find(db);

  dbAppArtists.clear();
  for (var dbArtist in allArtists) {
    dbAppArtists[dbArtist.id] = AppArtist(dbArtist: dbArtist);
  }

  dbImages.clear();
  for (var dbImage in allImages) {
    dbImages[dbImage.id] = dbImage;
  }

  appEvents.clear();
  for (var dbEvent in allEvents) {
    var appEvent = AppEvent(dbEvent);
    appEvents[appEvent.id] = appEvent;
  }

  appLocations.clear();
  for (var dbInfo in allInfos) {
    var type = dbInfo.type.v;
    if (type == infoTypeLocation) {
      var appLocation = AppLocation(dbInfo);
      appLocations[appLocation.id] = appLocation;
    }
    var appInfo = AppInfo(dbInfo);
    appInfos[appInfo.id] = appInfo;
  }

  /*
  for (var dbArtist in allArtists) {
    // var artist = appGetArtistById(dbArtist.id);
    // Find thumbnail
    // dbArtists[dbArtist.id] = dbArtist;
  }*/
  for (var event in appEvents.values) {
    var dbEvent = event.dbEvent;

    void tryArtistId(String artistId) {
      var artist = appGetArtistById(artistId);
      if (artist != null) {
        event.artists.add(artist);
        artist.events.add(event);
      }
    }

    dbEvent.attributes.v?.forEach((attribute) {
      var info = attribute.getAttributeInfo();

      // Find location
      if (info.locationInfoId != null) {
        event.location ??= appGetLocationById(info.locationInfoId!);
      }

      // Look for same name
      var artistId = info.artistId;
      // find artist
      if (artistId != null) {
        tryArtistId(artistId);
      }
    });

    if (event.artist == null) {
      // Look for same name
      tryArtistId(event.id);
    }
    // Find artist if any
    //var artist = appGetArtistById(dbArtist.id);
    // Find thumbnail
    // dbArtists[dbArtist.id] = dbArtist;
  }

  for (var dbImage in dbImages.values) {
    var id = dbImage.id;
    for (var articleKind in [
      AppArticleKind.artist,
      AppArticleKind.event,
      AppArticleKind.info,
      AppArticleKind.location,
    ]) {
      var appArticlePrefix = appGetArticlePrefix(articleKind);
      var thumbPrefix = '${appArticlePrefix}_${imageTypeThumbnail}_';
      if (id.startsWith(thumbPrefix)) {
        var articleId = id.substring(thumbPrefix.length);
        appGetArticleByKindAndId(articleKind, articleId)?.thumbnail = id;
      } else {
        var mainPrefix = '${appArticlePrefix}_${imageTypeMain}_';
        if (id.startsWith(mainPrefix)) {
          var articleId = id.substring(mainPrefix.length);
          appGetArticleByKindAndId(articleKind, articleId)?.mainImageId = id;
        } else {
          var compatPrefix = '${appArticlePrefix}_';
          if (id.startsWith(compatPrefix)) {
            var articleId = id.substring(compatPrefix.length);
            appGetArticleByKindAndId(articleKind, articleId)?.mainImageId = id;
          }
        }
      }
    }
  }

  // Player
  appPlayerPlaylists.clear();
  for (var info in appInfos.values.where((element) => element.isPlaylist)) {
    var playlist = AppPlayerPlayList.fromDbInfo(info: info.dbInfo);
    appPlayerPlaylists[playlist.id] = playlist;
  }

  gAppAssetList = await getAssetList();
  gAppAssetDataImgList = gAppAssetList
      .where((element) => element.startsWith(assetsDataImagePath))
      .map((element) => url.basename(element))
      .toList();
}

Future<List<String>> getAssetList() async {
  final manifestContent = await rootBundle.loadString('AssetManifest.json');

  final manifestMap = jsonDecode(manifestContent) as Map;
  return manifestMap.keys.cast<String>().toList();
}

extension AppPlayerCvAttributeExtension on CvAttribute {
  Uri? get uri => Uri.tryParse(value.v ?? '');
  bool get isInfo => uri?.scheme == articleKindInfo;

  /// Non-null if this is a song link
  AppPlayerSong? get song => isSong
      ? AppPlayerSong.fromDbInfo(info: appInfos[uri!.path]!.dbInfo)
      : null;

  bool get isSong => isInfo && (appInfos[uri!.path]?.isSong ?? false);
}

extension AppPlayerAppInfoExtension on AppInfo {
  bool get isSong => dbInfo.type.v == infoTypeSong;
  bool get isPlaylist => dbInfo.type.v == infoTypePlaylist;
}

abstract class AppPlayerPlayList {
  factory AppPlayerPlayList.fromDbInfo({required DbInfo info}) =>
      _AppPlayerPlayList(dbInfo: info);

  String? get title;

  //String? get author;
  List<AppPlayerSong> get songs;

  String get id;
}

class _AppPlayerPlayList implements AppPlayerPlayList {
  final DbInfo dbInfo;

  _AppPlayerPlayList({required this.dbInfo});

  @override
  String? get title => dbInfo.name.v;

  List<AppPlayerSong>? _songs;

  @override
  List<AppPlayerSong> get songs => _songs ??= () {
    var songs =
        dbInfo.attributes.v
            ?.where((element) => element.isSong)
            .map((e) => e.song!)
            .toList() ??
        <AppPlayerSong>[];
    for (var i = 0; i < songs.length; i++) {
      songs[i].index = i;
    }
    return songs;
  }();

  @override
  String get id => dbInfo.id;
}

abstract class AppPlayerSong {
  // DbInfo of type song
  factory AppPlayerSong.fromDbInfo({required DbInfo info}) =>
      _AppPlayerSong(dbInfo: info);

  String? get title;
  String? get subtitle;

  String? get author;

  List<String> get urls;

  String get id;

  // Optional index in playlist
  int? index;
}

class _AppPlayerSong implements AppPlayerSong {
  final DbInfo dbInfo;

  @override
  int? index;
  _AppPlayerSong({required this.dbInfo});

  @override
  String? get title => dbInfo.name.v;
  @override
  String? get subtitle => dbInfo.subtitle.v;
  @override
  String? get author => dbInfo.author.v;

  @override
  String get id => dbInfo.id;
  @override
  List<String> get urls =>
      dbInfo.attributes.v
          ?.where(
            (element) =>
                element.type.v == attributeTypeAudio && element.value.v != null,
          )
          .map((e) => e.value.v!)
          .toList() ??
      <String>[];
}

/// If only package name is specified, it is a global application
DatabaseFactory initDatabaseFactory({required String packageName}) {
  return getDatabaseFactory(
    packageName: packageName,
    rootPath: join('.dart_tool', 'tradhiv2022'),
  );
}

bool get isTargetDev => tkCmsFlavorContextFromUri(Uri.base).isDev;
