import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/data/festenao_projects_sdb.dart';
import 'package:fs_shim/fs.dart';

void _log(Object? message) {
  // ignore: avoid_print
  print(message);
}

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

/// Helper extension
extension SdfContentPersonSdbExt on SdfContentSdb {
  /// Dump info
  Future<void> dumpInfo() async {
    _log('FS: ${fs.unsandbox()}');
    //print('FS: ${fs.absolutePath(fs.currentDirectory.path)}');
    _log(
      'Database path: ${_db.name} ${await _db.factory.getDatabaseFullPath(_db.name)}',
    );
  }

  /// Delete project data
  Future<void> deleteData() async {
    try {
      await fs.unsandbox().delete();
    } catch (_) {}
    var name = _db.name;
    await _db.close();
    await _db.factory.deleteDatabase(name);
  }
}
