import 'package:path/path.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:tekartik_app_text/sanitize.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

/// Media file info in Festenao
class FestenaoMediaFile extends CvModelBase {
  /// Media file
  FestenaoMediaFile();

  /// Media file from info
  factory FestenaoMediaFile.from({
    required String filename,
    String? uid,
    String? type,
    int? size,
  }) {
    filename = buildOriginalFilename(filename);
    uid ??= _uuid.v4().replaceAll('-', '');

    var folder1 = uid.substring(0, 2).toLowerCase();
    var folder2 = uid.substring(2, 4).toLowerCase();
    var folder3 = uid.substring(4, 6).toLowerCase();
    var fixedName = '${uid}_${_sanitizeAndTruncateOriginalFilename(filename)}';

    var path = url.join(folder1, folder2, folder3, fixedName);
    return FestenaoMediaFile()
      ..originalFilename.v = filename
      ..path.v = path
      ..uid.v = uid
      ..type.setValue(type)
      ..size.setValue(size);
  }

  /// Build original file name from a full name or path, only take the base name
  static String buildOriginalFilename(String filename) {
    var originalFilename = filename.split('/').last.split('\\').last;
    if (originalFilename.isEmpty) {
      originalFilename = 'file';
    }
    return originalFilename;
  }

  static String _sanitizeAndTruncateOriginalFilename(String originalFilename) {
    var basename = sanitizeString(
      url.basenameWithoutExtension(originalFilename),
    ).truncate(24);
    var extension = _fileExtension(originalFilename);
    return '$basename.$extension';
  }

  /// no leading .
  static String _fileExtension(String filename) {
    var parts = filename.split('.');
    if (parts.length > 1) {
      return parts.last;
    } else {
      return '';
    }
  }

  /// Required
  final uid = CvField<String>('uid');

  /// Media type (mime type)
  final type = CvField<String>('type');

  /// Original filename of the media file, used to determine the file extension and for reference. This field is not used for storage but can be helpful for management and debugging purposes.
  final originalFilename = CvField<String>('filename');

  /// Path to the media file in the file system, stored as a string. This field is used to locate the media file for retrieval and management.
  /// Path is the sharded
  final path = CvField<String>('path');

  /// Timestamp when the media file was created.
  final createdTimestamp = cvEncodedTimestampField('createdTimestamp');

  /// File size
  final size = CvField<int>('size');
  @override
  CvFields get fields => [
    uid,
    type,
    originalFilename,
    path,
    createdTimestamp,
    size,
  ];
}
