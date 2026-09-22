import 'dart:convert';

import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_common_flutter/firestore_explorer_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart';

/// See the file system explorer tests: real timers.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 25; i++) {
    await tester.pump(const Duration(milliseconds: 50));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
}

/// The backup button of the row named [name]: the icons are not in the order
/// the screen shows them, so each one is found by what it sits in.
Finder _rowBackup(String name) => find.descendant(
  of: find.widgetWithText(ListTile, name),
  matching: find.byIcon(Icons.backup_outlined),
);

/// The backup button of the app bar.
Finder _appBarBackup() => find.descendant(
  of: find.byType(AppBar),
  matching: find.byIcon(Icons.backup_outlined),
);

void _testWidgets(
  String description,
  Future<void> Function(WidgetTester) body,
) {
  testWidgets(description, (tester) async {
    await tester.runAsync(() => body(tester));
  });
}

Future<Firestore> _newFirestore() async {
  // ignore: deprecated_member_use
  var firestore = newFirestoreMemory();
  await firestore.doc('config/main').set({
    'name': 'main',
    'when': Timestamp.parse('2024-01-02T03:04:05.000Z'),
  });
  await firestore.doc('config/main/items/one').set({'index': 1});
  return firestore;
}

Future<FileSystemExplorer> _newExplorer() async {
  var fileSystem = newFileSystemMemory();
  await fileSystem.directory('backups').create(recursive: true);
  return FileSystemExplorer(fileSystem: fileSystem, rootPath: 'backups');
}

void main() {
  group('writeFirestoreBackup', () {
    test('writes a json backup that reads back', () async {
      var firestore = await _newFirestore();
      var explorer = await _newExplorer();
      var result = await writeFirestoreBackup(
        firestore: firestore,
        explorer: explorer,
        name: 'config',
        format: FirestoreBackupFormat.json,
        rootPath: 'config',
      );
      expect(result.format, FirestoreBackupFormat.json);
      expect(result.paths, ['config.json']);
      expect(result.count, 2);

      var text = await explorer.readAsString('config.json');
      var data = FirestoreBackup(firestore: firestore).fromJsonText(text);
      expect(data.documents.keys.toSet(), {
        'config/main',
        'config/main/items/one',
      });
      expect(
        data.documents['config/main']!['when'],
        Timestamp.parse('2024-01-02T03:04:05.000Z'),
      );
    });

    test('writes an sdb backup the explorer then opens', () async {
      var firestore = await _newFirestore();
      var explorer = await _newExplorer();
      var result = await writeFirestoreBackup(
        firestore: firestore,
        explorer: explorer,
        name: 'config',
        format: FirestoreBackupFormat.sdb,
        rootPath: 'config',
      );
      expect(result.paths, ['config.db']);
      expect(result.count, 2);

      // It really is a database the explorer lists and opens.
      var entry = (await explorer.entry('config.db'))!;
      expect(entry.isDatabase, isTrue);
      expect(
        await explorer.databaseKind('config.db'),
        FileSystemDatabaseKind.sdb,
      );
      var database = await explorer.openDatabase('config.db');
      var collections = await database.repository.listCollections();
      expect(collections.map((collection) => collection.name).toSet(), {
        'config',
        'config/main/items',
      });
      await database.close();
    });

    test('writes a synced source export and its meta', () async {
      var firestore = await _newFirestore();
      var explorer = await _newExplorer();
      var result = await writeFirestoreBackup(
        firestore: firestore,
        explorer: explorer,
        name: 'source',
        format: FirestoreBackupFormat.syncedSource,
      );
      expect(result.paths, ['source.jsonl', 'source.meta.json']);

      var jsonl = await explorer.readAsString('source.jsonl');
      expect(jsonl, contains('tekaly_export'));
      var meta = jsonDecode(await explorer.readAsString('source.meta.json'));
      expect(meta, isA<Map>());
      expect((meta as Map).containsKey('lastChangeId'), isTrue);
    });

    test('backs the whole instance up when given no root', () async {
      var firestore = await _newFirestore();
      var explorer = await _newExplorer();
      var result = await writeFirestoreBackup(
        firestore: firestore,
        explorer: explorer,
        name: 'all',
        format: FirestoreBackupFormat.json,
      );
      expect(result.count, 2);
      var data = FirestoreBackup(
        firestore: firestore,
      ).fromJsonText(await explorer.readAsString('all.json'));
      expect(data.rootPath, isNull);
    });

    test('writes into a sub directory', () async {
      var firestore = await _newFirestore();
      var explorer = await _newExplorer();
      var result = await writeFirestoreBackup(
        firestore: firestore,
        explorer: explorer,
        name: 'config',
        format: FirestoreBackupFormat.json,
        rootPath: 'config',
        directoryPath: 'daily',
      );
      expect(result.paths, ['daily/config.json']);
      expect(await explorer.entry('daily/config.json'), isNotNull);
    });
  });

  group('the firestore explorer', () {
    _testWidgets('offers no backup without somewhere to write it', (
      tester,
    ) async {
      var firestore = await _newFirestore();
      await tester.pumpWidget(
        MaterialApp(home: FirestoreExplorerScreen(firestore: firestore)),
      );
      await _settle(tester);
      expect(find.byIcon(Icons.backup_outlined), findsNothing);
    });

    _testWidgets('backs a collection up from its row', (tester) async {
      var firestore = await _newFirestore();
      var explorer = await _newExplorer();
      await tester.pumpWidget(
        MaterialApp(
          home: FirestoreExplorerScreen(
            firestore: firestore,
            backupExplorer: explorer,
          ),
        ),
      );
      await _settle(tester);

      // One in the app bar, one on the collection row.
      expect(find.byIcon(Icons.backup_outlined), findsNWidgets(2));
      await tester.tap(_rowBackup('config'));
      await _settle(tester);

      expect(find.text('Back up config'), findsOneWidget);
      await tester.tap(find.text('Json file'));
      await _settle(tester);
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(find.textContaining('Backed up 2 documents'), findsOneWidget);
      expect(await explorer.entry('config.json'), isNotNull);
    });

    _testWidgets('backs everything up from the app bar', (tester) async {
      var firestore = await _newFirestore();
      var explorer = await _newExplorer();
      await tester.pumpWidget(
        MaterialApp(
          home: FirestoreExplorerScreen(
            firestore: firestore,
            backupExplorer: explorer,
          ),
        ),
      );
      await _settle(tester);

      await tester.tap(_appBarBackup());
      await _settle(tester);
      expect(find.text('Back up everything'), findsOneWidget);
      await tester.tap(find.text('Synced source export'));
      await _settle(tester);
      await tester.tap(find.text('Ok'));
      await _settle(tester);

      expect(await explorer.entry('firestore.jsonl'), isNotNull);
      expect(await explorer.entry('firestore.meta.json'), isNotNull);
    });
  });
}
