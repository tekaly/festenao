import 'package:festenao_common/data/src/festenao_sdb.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:idb_shim/sdb.dart';
import 'package:test/test.dart';

const _timeout = Timeout(Duration(seconds: 30));

void main() {
  test('a failed open is reported by ready only', () async {
    var sdbFactory = newSdbFactoryMemory();
    // A newer version of the database exists: opening version 1 fails.
    var newer = await sdbFactory.openDatabase(
      'festenao.db',
      options: SdbOpenDatabaseOptions(version: 5),
    );
    await newer.close();
    var db = FestenaoSdb(
      sdbFactory: sdbFactory,
      dbName: 'festenao.db',
      fs: newFileSystemMemory(),
    );
    // An uncaught error here fails the test, ready being caught.
    await expectLater(db.ready, throwsA(anything));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }, timeout: _timeout);
}
