import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:tekaly_sdb_synced_media/synced_media_storage.dart';
import 'package:tkcms_common/tkcms_storage.dart';

import '../festenao_firestore.dart';
import 'festenao_media.dart';

/// Database record class for media files in Festenao
/// The uid is the file uid
class FsFestenaoMediaFile extends CvFirestoreDocumentBase {
  /// Media type (mime type)
  final type = CvField<String>('type');

  /// Original filename of the media file, used to determine the file extension and for reference. This field is not used for storage but can be helpful for management and debugging purposes.
  final originalFilename = CvField<String>('filename');

  /// Path to the media file in the file system, stored as a string. This field is used to locate the media file for retrieval and management.
  final filePath = CvField<String>('path');

  /// Timestamp when the media file was created (local)
  final createdTimestamp = CvField<Timestamp>('createdTimestamp');

  /// File size
  final size = CvField<int>('size');

  /// Server change id
  final syncChangeNum = CvField<int>('syncChangeNum');

  /// Timestamp when the media file was created on the server
  final serverCreatedTimestamp = CvField<Timestamp>('createdTimestamp');

  /// Deleted
  final deleted = CvField<bool>('deleted');

  @override
  CvFields get fields => [
    type,
    originalFilename,
    filePath,
    createdTimestamp,
    size,
    syncChangeNum,
    serverCreatedTimestamp,
  ];
}

/// Firebase implementation of `FestenaoMediaSource`, the contents in
/// `<rootDirectory>/<media path>` (see `SyncedMediaSourceStorage`).
class FestenaoMediaSourceFirebase extends SyncedMediaSourceStorage {
  /// Storage context
  final FirebaseStorageContext storageContext;

  /// Constructor for [FestenaoMediaSourceFirebase].
  FestenaoMediaSourceFirebase({
    required this.storageContext,
    super.cacheControl,
    super.urlBuilder,
  }) : super(
         storage: storageContext.storage,
         bucketName: storageContext.bucketName,
         rootPath: storageContext.rootDirectory,
       ) {
    cvAddConstructors([DbFestenaoMediaFile.new]);
  }

  /// Get gs link
  Uri getGsLink({required FestenaoMediaFileRef ref}) =>
      storageFileRef(ref).toLink();

  /// Get download url, throws if the storage gives none.
  Future<String> getDownloadUrl({required FestenaoMediaFileRef ref}) async {
    var url = await getMediaUrl(ref);
    if (url == null) {
      throw UnsupportedError('No download url for $ref');
    }
    return url.toString();
  }
}
