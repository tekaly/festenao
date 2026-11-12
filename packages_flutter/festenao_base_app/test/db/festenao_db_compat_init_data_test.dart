import 'package:festenao_base_app/db/festenao_db_compat.dart';
import 'package:festenao_common/data/festenao_db.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('initData drops an info deleted since the last call', () async {
    var festenaoDb = FestenaoDb.newInMemory();
    var db = await festenaoDb.database;
    await dbInfoStoreRef.record('i1').put(db, DbInfo()..name.v = 'Info 1');
    await dbInfoStoreRef
        .record('p1')
        .put(
          db,
          DbInfo()
            ..name.v = 'Playlist'
            ..type.v = infoTypePlaylist,
        );
    await initData(festenaoDb);
    expect(appInfos.keys, unorderedEquals(['i1', 'p1']));
    expect(appPlayerPlaylists.keys, ['p1']);

    // A newer export without them
    await dbInfoStoreRef.record('i1').delete(db);
    await dbInfoStoreRef.record('p1').delete(db);
    await initData(festenaoDb);
    expect(appInfos, isEmpty);
    expect(appGetInfoById('i1'), isNull);
    expect(appPlayerPlaylists, isEmpty);
    await festenaoDb.close();
  }, timeout: const Timeout(Duration(seconds: 30)));
}
