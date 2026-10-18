import 'package:tekaly_sdb_synced_media/synced_media.dart';

import '../festenao_cv.dart';

/// Abstract source for media files (see `tekaly_sdb_synced_media`).
typedef FestenaoMediaSource = SyncedMediaSource;

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
