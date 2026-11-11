import 'package:festenao_common/data/firestore_backup.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

void main() {
  test('walks below a document with no data', () async {
    // ignore: deprecated_member_use
    var firestore = newFirestoreMemory();
    // app/test and app/test/project/p2 have no data of their own, only sub
    // collections (an app root).
    await firestore.doc('app/test/project/p1').set({'name': 'p1'});
    await firestore.doc('app/test/project/p2/data/info').set({'name': 'i'});
    await firestore.doc('app/other').set({'name': 'other'});
    var backup = FirestoreBackup(firestore: firestore);
    expect(firestore.service.supportsListMissingDocuments, isTrue);
    var expected = {
      'app/other',
      'app/test/project/p1',
      'app/test/project/p2/data/info',
    };
    expect((await backup.readAll()).documents.keys.toSet(), expected);
    var app = await backup.readCollection('app');
    expect(app.documents.keys.toSet(), expected);
    // The missing documents are not in the backup, a restore does not create
    // them.
    expect(app.documents.containsKey('app/test'), isFalse);
    // The depth still bounds the walk.
    expect((await backup.readCollection('app', maxDepth: 1)).documents.keys, [
      'app/other',
    ]);
    // So does the limit, the missing documents included.
    var limited = await backup.readCollection('app', limit: 1);
    expect(limited.documents.keys.toSet(), {'app/other'});
  }, timeout: const Timeout(Duration(seconds: 30)));
}
