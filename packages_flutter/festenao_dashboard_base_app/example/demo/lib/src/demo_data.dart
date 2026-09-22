import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_common_flutter/firestore_explorer_flutter.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_firebase_firestore/firestore.dart';
import 'package:tekartik_firebase_firestore_sembast/firestore_sembast.dart'
    as firestore_memory;

/// Everything the demo runs on, all of it in memory: nothing is written to the
/// disk and nothing survives a restart.
class DemoData {
  /// The firestore instance, seeded by [fillDemoFirestore].
  final Firestore firestore;

  /// The file system, holding the documents and the databases.
  final FileSystem fileSystem;

  /// The explorer of that file system, read write.
  final FileSystemExplorer explorer;

  /// Data on [firestore] and [fileSystem].
  DemoData({
    required this.firestore,
    required this.fileSystem,
    required this.explorer,
  });

  /// Builds it all: a firestore tree, a few documents, a sembast database and
  /// an sdb one, so every explorer has something to show.
  static Future<DemoData> create() async {
    // ignore: deprecated_member_use
    var firestore = firestore_memory.newFirestoreMemory();
    await fillDemoFirestore(firestore);

    var fileSystem = newFileSystemMemory();
    await fileSystem.directory('/demo').create(recursive: true);
    var explorer = FileSystemExplorer(
      fileSystem: fileSystem,
      rootPath: '/demo',
    );

    // The documents, straight from the shared demo content.
    await explorer.writeAsString('config.json', demoJsonContent);
    await explorer.writeAsString('settings.yaml', demoYamlContent);
    await explorer.writeAsString('notes.txt', demoTextContent);
    await explorer.writeAsBytes('picture.bin', demoBinaryContent());
    await explorer.createDirectory('sub');
    await explorer.writeAsString('sub/nested.json', '{"nested": true}\n');

    // The databases, in a directory of their own so the listing has a tree to
    // walk.
    var sembastDatabase = await explorer.createSembastDatabase(
      'data/sembast_demo.db',
      onCreate: fillDemoSembastDatabase,
    );
    await sembastDatabase.close();

    initFileSystemDemoBuilders();
    var sdbDatabase = await explorer.createSdbDatabase(
      'data/sdb_demo.db',
      schema: demoSdbDatabaseSchema(),
      onCreate: fillDemoSdbDatabase,
    );
    await sdbDatabase.close();

    return DemoData(
      firestore: firestore,
      fileSystem: fileSystem,
      explorer: explorer,
    );
  }
}
