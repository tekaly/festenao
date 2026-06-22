import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:fs_shim/fs.dart';

/// Typed access to all festenao-content stores inside a single [SdbDatabase].
class SdfContentSdb {
  /// The file system
  final FileSystem fs;

  /// The database
  final SdbDatabase _db;

  /// The media database
  late final mediaDb = FestenaoMediaSdb(fs: fs, database: _db);

  /// Create a typed access to the content database.
  SdfContentSdb({required this.fs, required this._db});

  /// The database
  SdbDatabase get db => _db;
}
