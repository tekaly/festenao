import 'dart:typed_data';

import '../festenao_cv.dart';
import 'festenao_media.dart';

/// Abstract source for media files.
abstract class FestenaoMediaSource {
  /// Adds a media file to the source.
  Future<void> addMediaFile({
    required FestenaoMediaFile file,
    required Uint8List bytes,
  });

  /// Reads the media file bytes for the given [ref].
  Future<Uint8List> readMediaFileBytes(FestenaoMediaFileRef ref);

  /// Deletes the media file for the given [ref].
  Future<void> deleteMediaFile(FestenaoMediaFileRef ref);
}

/// /meta/info
abstract class FestenaoMediaSourceMetaInfo implements CvModel {
  /// Label, info only
  CvField<String> get label;

  /// Min incremental change id
  CvField<int> get minIncrementalChangeId;

  /// Last incremental change id
  CvField<int> get lastChangeId;

  /// Version, simply increment it to force a full sync
  ///
  /// Set to 1 upon read if not set yet
  CvField<int> get version;
}

/// Record mixin
mixin FestenaoMediaSourceMetaInfoMixin implements FestenaoMediaSourceMetaInfo {
  @override
  final label = CvField<String>('label');

  /// Min incremental change id
  @override
  final minIncrementalChangeId = CvField<int>('minIncrementalChangeId');

  /// Last incremental change id
  @override
  final lastChangeId = CvField<int>('lastChangeId');

  /// Version, simply increment it to force a full sync
  ///
  /// Set to 1 upon read if not set yet
  @override
  final version = CvField<int>('version');

  @override
  List<CvField> get fields => [
    label,
    minIncrementalChangeId,
    lastChangeId,
    version,
  ];
}
