import 'package:path/path.dart';
import 'package:tekartik_app_media/mime_type.dart';
import 'package:tekartik_app_text/sanitize.dart';
import 'package:tekartik_common_utils/string_utils.dart';
import 'package:uuid/uuid.dart';

export 'package:tekartik_app_media/mime_type.dart';

const _uuid = Uuid();

/// Media source ref
class FestenaoMediaFileRef {
  /// Path (relative)
  final String path;

  /// Constructor
  FestenaoMediaFileRef.fromPath(this.path);

  @override
  String toString() => path;
}

/// Media file info in Festenao
class FestenaoMediaFile {
  /// Media file from info
  factory FestenaoMediaFile.from({
    required String filename,

    /// Type is generated from filename if not provided
    String? type,

    /// Optional size
    int? size,
  }) {
    filename = buildOriginalFilename(filename);
    var uid = _uuid.v4().replaceAll('-', '');

    var folder1 = uid.substring(0, 2).toLowerCase();
    var folder2 = uid.substring(2, 4).toLowerCase();
    var folder3 = uid.substring(4, 6).toLowerCase();
    var fixedName = '${uid}_${_sanitizeAndTruncateOriginalFilename(filename)}';

    type ??= filenameMimeType(filename);
    var path = url.join(folder1, folder2, folder3, fixedName);
    return FestenaoMediaFile(
      path: path,
      uid: uid,
      type: type,
      size: size,
      originalFilename: filename,
    );
  }

  /// Ref
  late final ref = FestenaoMediaFileRef.fromPath(path);

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

  /// Original filename
  final String originalFilename;

  /// Required
  final String uid;

  /// Media type (mime type)
  final String type;

  /// Original filename of the media file, used to determine the file extension and for reference. This field is not used for storage but can be helpful for management and debugging purposes.
  final String path;

  /// File size
  final int? size;

  /// Festenao media file
  FestenaoMediaFile({
    required this.uid,
    required this.originalFilename,
    required this.type,
    required this.path,
    required this.size,
  });
}
