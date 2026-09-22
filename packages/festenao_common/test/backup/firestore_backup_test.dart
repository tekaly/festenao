import 'dart:typed_data';

import 'package:festenao_common/data/firestore_backup.dart';
import 'package:idb_shim/sdb.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';
import 'package:test/test.dart';

/// An instance holding a small tree: a collection, a document with every
/// firestore type, and a sub collection under it.
Future<Firestore> _newFirestore() async {
  // ignore: deprecated_member_use
  var firestore = newFirestoreMemory();
  await firestore.doc('config/main').set({
    'name': 'main',
    'when': Timestamp.parse('2024-01-02T03:04:05.000Z'),
    'data': Blob(Uint8List.fromList([1, 2, 3])),
    'where': const GeoPoint(1.5, 2.5),
    'other': firestore.doc('config/second'),
    'nested': {
      'list': [1, 'two'],
    },
  });
  await firestore.doc('config/second').set({'name': 'second'});
  await firestore.doc('config/main/items/one').set({'index': 1});
  await firestore.doc('config/main/items/two').set({'index': 2});
  await firestore.doc('other/thing').set({'name': 'thing'});
  return firestore;
}

void main() {
  group('reading a tree', () {
    test('walks a collection and everything below it', () async {
      var firestore = await _newFirestore();
      var backup = FirestoreBackup(firestore: firestore);
      expect(backup.walksSubCollections, isTrue);

      var data = await backup.readCollection('config');
      expect(data.rootPath, 'config');
      expect(data.documents.keys.toSet(), {
        'config/main',
        'config/second',
        'config/main/items/one',
        'config/main/items/two',
      });
      expect(data.documentCount, 4);
      expect(data.collectionPaths, ['config', 'config/main/items']);
      expect(data.collectionDocuments('config/main/items').keys, [
        'one',
        'two',
      ]);
      // The values keep their firestore types.
      expect(
        data.documents['config/main']!['when'],
        Timestamp.parse('2024-01-02T03:04:05.000Z'),
      );
    });

    test('walks one document and what is under it', () async {
      var firestore = await _newFirestore();
      var data = await FirestoreBackup(
        firestore: firestore,
      ).readDocument('config/main');
      expect(data.documents.keys.toSet(), {
        'config/main',
        'config/main/items/one',
        'config/main/items/two',
      });
    });

    test('walks the whole instance', () async {
      var firestore = await _newFirestore();
      var data = await FirestoreBackup(firestore: firestore).readAll();
      expect(data.rootPath, isNull);
      expect(data.documentCount, 5);
      expect(data.documents.keys, contains('other/thing'));
    });

    test('stops where it is told to', () async {
      var firestore = await _newFirestore();
      var backup = FirestoreBackup(firestore: firestore);
      // One level: the documents of the collection, none of what is below.
      var shallow = await backup.readCollection('config', maxDepth: 1);
      expect(shallow.documents.keys.toSet(), {'config/main', 'config/second'});
      // And a cap on how many documents are read.
      var limited = await backup.readCollection('config', limit: 1);
      expect(limited.collectionDocuments('config').length, 1);
    });
  });

  group('json', () {
    test('round trips a backup, types and all', () async {
      var firestore = await _newFirestore();
      var backup = FirestoreBackup(firestore: firestore);
      var data = await backup.readCollection('config');

      var text = backup.toJsonText(data);
      // The custom types are marked, so the file says what they are.
      expect(text, contains(r'"$timestamp"'));
      expect(text, contains(r'"$blob"'));
      expect(text, contains(r'"$geoPoint"'));
      expect(text, contains(r'"$documentReference"'));
      expect(text, contains('"festenao_firestore_backup": 1'));

      var read = backup.fromJsonText(text);
      expect(read.rootPath, 'config');
      expect(read.documents.keys.toSet(), data.documents.keys.toSet());
      var document = read.documents['config/main']!;
      expect(document['when'], Timestamp.parse('2024-01-02T03:04:05.000Z'));
      expect(document['data'], isA<Blob>());
      expect(document['where'], const GeoPoint(1.5, 2.5));
      expect((document['other'] as DocumentReference).path, 'config/second');
      expect(document['nested'], {
        'list': [1, 'two'],
      });
    });

    test('refuses what is not a backup', () {
      // ignore: deprecated_member_use
      var backup = FirestoreBackup(firestore: newFirestoreMemory());
      expect(() => backup.fromJsonText('{}'), throwsFormatException);
      expect(() => backup.fromJsonText('[]'), throwsFormatException);
      expect(
        () => backup.fromJsonEncodable({
          firestoreBackupFormatKey: 99,
          'documents': <String, Object?>{},
        }),
        throwsFormatException,
      );
    });
  });

  group('restoring', () {
    test('puts a backup into another instance', () async {
      var firestore = await _newFirestore();
      var data = await FirestoreBackup(
        firestore: firestore,
      ).readCollection('config');

      // ignore: deprecated_member_use
      var other = newFirestoreMemory();
      var otherBackup = FirestoreBackup(firestore: other);
      // Through the json, which is what a backup file goes through.
      var restored = otherBackup.fromJsonText(
        FirestoreBackup(firestore: firestore).toJsonText(data),
      );
      expect(await otherBackup.restore(restored), 4);

      var read = await otherBackup.readCollection('config');
      expect(read.documents.keys.toSet(), data.documents.keys.toSet());
      expect(
        (await other.doc('config/main').get()).data['when'],
        Timestamp.parse('2024-01-02T03:04:05.000Z'),
      );
      expect((await other.doc('config/main/items/two').get()).data, {
        'index': 2,
      });
    });
  });

  group('sdb', () {
    test('writes a backup to a database and reads it back', () async {
      var firestore = await _newFirestore();
      var backup = FirestoreBackup(firestore: firestore);
      var data = await backup.readCollection('config');

      var database = await sdbFactoryMemory.openDatabase(
        'backup.db',
        options: SdbOpenDatabaseOptions(
          version: 1,
          schema: firestoreBackupSdbSchema(data),
        ),
      );
      expect(database.storeNames.toSet(), {'config', 'config/main/items'});

      var written = await writeFirestoreBackupToSdb(
        data,
        database,
        typeRegistry: backup.typeRegistry,
      );
      expect(written, 4);

      var read = await readFirestoreBackupFromSdb(
        database,
        typeRegistry: backup.typeRegistry,
        rootPath: 'config',
      );
      expect(read.documents.keys.toSet(), data.documents.keys.toSet());
      expect(
        read.documents['config/main']!['when'],
        Timestamp.parse('2024-01-02T03:04:05.000Z'),
      );
      await database.close();
    });
  });
}
