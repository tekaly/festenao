import 'dart:convert';
import 'dart:typed_data';

import 'package:festenao_common/fs/file_system_explorer.dart';
import 'package:sembast/blob.dart';
import 'package:sembast/sembast.dart' as sembast;
import 'package:sembast/timestamp.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

import 'file_system_create_action.dart';

/// A note of the sdb demo database, declared the `cv` sdb way: a record model
/// whose fields carry their own types, a timestamp and a blob included.
class DemoNote extends ScvStringRecordBase {
  /// The title, what the demo index is on.
  final title = CvField<String>('title');

  /// The body of the note.
  final body = CvField<String>('body');

  /// When it was written.
  final createdAt = CvField<SdbTimestamp>('createdAt');

  /// A few bytes, so a blob shows in the editor.
  final attachment = CvField<SdbBlob>('attachment');

  @override
  CvFields get fields => [title, body, createdAt, attachment];
}

/// A tag of the sdb demo database, a second store so the explorer has more
/// than one to list.
class DemoTag extends ScvStringRecordBase {
  /// What the tag is called.
  final name = CvField<String>('name');

  /// How many notes carry it.
  final count = CvField<int>('count');

  @override
  CvFields get fields => [name, count];
}

/// The notes of the sdb demo database.
final demoNoteStore = scvStringStoreFactory.store<DemoNote>('note');

/// The notes by title.
final demoNoteTitleIndex = demoNoteStore.index<String>('title');

/// The tags of the sdb demo database.
final demoTagStore = scvStringStoreFactory.store<DemoTag>('tag');

var _buildersInitialized = false;

/// Registers the demo models with `cv`, which needs to know how to build one
/// before it reads one back.
void initFileSystemDemoBuilders() {
  if (_buildersInitialized) {
    return;
  }
  _buildersInitialized = true;
  cvAddConstructor(DemoNote.new);
  cvAddConstructor(DemoTag.new);
}

/// The schema of the sdb demo database: two stores, one of them indexed.
SdbDatabaseSchema demoSdbDatabaseSchema() => SdbDatabaseSchema(
  stores: [
    demoNoteStore.schema(
      indexes: [demoNoteTitleIndex.schema(keyPath: 'title')],
    ),
    demoTagStore.schema(),
  ],
);

/// A path in [directoryPath] that nothing sits on yet, `demo.json`,
/// `demo_2.json` and so on.
Future<String> fileSystemFreePath(
  FileSystemExplorer explorer, {
  required String directoryPath,
  required String name,
  required String extension,
}) async {
  for (var index = 1; ; index++) {
    var candidate = '$name${index == 1 ? '' : '_$index'}$extension';
    var path = directoryPath.isEmpty ? candidate : '$directoryPath/$candidate';
    if (await explorer.entry(path) == null) {
      return path;
    }
  }
}

/// A demo json document: every basic type, a date and a blob, nested.
const demoJsonContent = '''
{
  "name": "Demo",
  "count": 42,
  "ratio": 0.5,
  "enabled": true,
  "nothing": null,
  "when": {
    "\$dateTime": "2024-01-02T03:04:05.000Z"
  },
  "data": {
    "\$blob": "AQIDBA=="
  },
  "nested": {
    "tags": ["one", "two"],
    "deeper": {"value": 1}
  }
}
''';

/// A demo yaml document, with the comments that a save keeps.
const demoYamlContent = '''
# A demo document. Edit a value and save: this comment, the key order and
# the layout below all survive, because yaml is written back in place.
name: Demo
count: 42
enabled: true
nested:
  tags:
    - one
    - two
  deeper:
    value: 1
''';

/// A demo text file.
const demoTextContent = '''
A demo text file.

The explorer opens this one in the text editor, since .txt reads as text.
A file it cannot read as text opens in the hex editor instead, which shows a
text preview of its own when the bytes happen to be utf8.
''';

/// A demo binary file: a made up header, then bytes that are not text, so the
/// hex editor has both columns worth looking at.
Uint8List demoBinaryContent() => Uint8List.fromList([
  ...utf8.encode('DEMO'),
  0x00,
  0x01,
  0x02,
  0x03,
  0xff,
  0xfe,
  0xfd,
  0xfc,
  ...utf8.encode('readable'),
  0x00,
  0x80,
  0x90,
  0xa0,
]);

/// Fills the demo sembast database: two stores, a timestamp and a blob among
/// the values.
Future<void> fillDemoSembastDatabase(sembast.Database database) async {
  var settings = sembast.stringMapStoreFactory.store('settings');
  var events = sembast.intMapStoreFactory.store('event');
  await settings.record('main').put(database, {
    'name': 'Demo',
    'count': 42,
    'enabled': true,
    'updatedAt': Timestamp.parse('2024-01-02T03:04:05.000Z'),
    'icon': Blob(Uint8List.fromList([1, 2, 3, 4])),
    'nested': {
      'tags': ['one', 'two'],
    },
  });
  await events.add(database, {
    'kind': 'started',
    'at': Timestamp.parse('2024-01-02T03:04:05.000Z'),
  });
  await events.add(database, {
    'kind': 'stopped',
    'at': Timestamp.parse('2024-01-02T04:05:06.000Z'),
  });
}

/// Fills the demo sdb database, through the `cv` record models.
Future<void> fillDemoSdbDatabase(SdbDatabase database) async {
  initFileSystemDemoBuilders();
  await demoNoteStore
      .record('first')
      .put(
        database,
        DemoNote()
          ..title.v = 'First note'
          ..body.v = 'What the sdb explorer shows, record by record.'
          ..createdAt.v = SdbTimestamp.parse('2024-01-02T03:04:05.000Z')
          ..attachment.v = SdbBlob(Uint8List.fromList([1, 2, 3, 4])),
      );
  await demoNoteStore
      .record('second')
      .put(
        database,
        DemoNote()
          ..title.v = 'Second note'
          ..body.v = 'Indexed by title, see the schema.'
          ..createdAt.v = SdbTimestamp.parse('2024-02-03T04:05:06.000Z'),
      );
  await demoTagStore
      .record('demo')
      .put(
        database,
        DemoTag()
          ..name.v = 'demo'
          ..count.v = 2,
      );
}

/// One demo of each kind the explorer handles, for the `+` menu.
///
/// Each one creates a populated example and opens it, so the editors have
/// something to show straight away: a json and a yaml document, a text file, a
/// binary one, a sembast database and an sdb database built from
/// [demoSdbDatabaseSchema].
List<FileSystemCreateAction> festenaoFileSystemDemoActions() => [
  _demoAction(
    label: 'Demo json document',
    name: 'demo',
    extension: '.json',
    write: (explorer, path) => explorer.writeAsString(path, demoJsonContent),
  ),
  _demoAction(
    label: 'Demo yaml document',
    name: 'demo',
    extension: '.yaml',
    write: (explorer, path) => explorer.writeAsString(path, demoYamlContent),
  ),
  _demoAction(
    label: 'Demo text file',
    name: 'demo',
    extension: '.txt',
    write: (explorer, path) => explorer.writeAsString(path, demoTextContent),
  ),
  _demoAction(
    label: 'Demo binary file',
    name: 'demo',
    extension: '.bin',
    write: (explorer, path) => explorer.writeAsBytes(path, demoBinaryContent()),
  ),
  _demoAction(
    label: 'Demo sembast database',
    name: 'demo_sembast',
    extension: '.db',
    write: (explorer, path) async {
      var database = await explorer.createSembastDatabase(
        path,
        onCreate: fillDemoSembastDatabase,
      );
      await database.close();
    },
  ),
  _demoAction(
    label: 'Demo sdb database',
    name: 'demo_sdb',
    extension: '.db',
    write: (explorer, path) async {
      initFileSystemDemoBuilders();
      var database = await explorer.createSdbDatabase(
        path,
        schema: demoSdbDatabaseSchema(),
        onCreate: fillDemoSdbDatabase,
      );
      await database.close();
    },
  ),
];

/// A demo action: it names the file itself, so one tap gives something to look
/// at rather than a prompt.
FileSystemCreateAction _demoAction({
  required String label,
  required String name,
  required String extension,
  required Future<void> Function(FileSystemExplorer explorer, String path)
  write,
}) => FileSystemCreateAction(
  label: label,
  create: (context, explorer, directoryPath) async {
    var path = await fileSystemFreePath(
      explorer,
      directoryPath: directoryPath,
      name: name,
      extension: extension,
    );
    await write(explorer, path);
    return path;
  },
);
