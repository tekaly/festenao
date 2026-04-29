import 'dart:typed_data';

import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_sdb.dart';
import 'package:festenao_common/festenao_sdb.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:test/test.dart';

void main() {
  late FestenaoMediaSdb db;
  late SdbDatabase sdbDb;
  late final fs = db.fs;
  setUp(() async {
    sdbDb = await newSdbFactoryMemory().openDatabase(
      'test',
      options: SdbOpenDatabaseOptions(
        schema: SdbDatabaseSchema(stores: sdbMediaSchemaStores),
      ),
    );
    db = FestenaoMediaSdb(fs: newFileSystemMemory(), database: sdbDb);
  });
  tearDown(() async {
    await sdbDb.close();
  });
  test('write/read/delete/purge', () async {
    var content = Uint8List.fromList([1, 2, 3]);
    var fileId = await db.addMediaFile(
      bytes: content,
      file: FestenaoMediaFile.from(filename: 'test.webp', type: 'image/webp'),
    );
    expect(
      await sdbMediaStatusLocalStore.record(fileId).get(db.database),
      SdbFestenaoMediaFileStatus()
        ..local.v = 1
        ..remote.v = 0
        ..deleted.v = 0,
    );
    expect(await db.readMediaFileBytes(fileId), content);
    var record = (await db.getMediaFileRecord(fileId))!;
    expect(record.id, fileId);
    expect(record.toMap(), {
      'type': 'image/webp',
      'size': content.length,
      'filename': 'test.webp',
      // example  'path': 'e1/65/bf/e165bf35b3fa495a81649535b9cfb444_test.webp',
      'path': record.path.v,
      'createdTimestamp': record.createdTimestamp.v,
    });
    var file = await db.getMediaFile(fileId);
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), content);
    await db.deleteMediaFile(fileId);
    expect(
      await sdbMediaStatusLocalStore.record(fileId).get(db.database),
      SdbFestenaoMediaFileStatus()
        ..local.v = 0
        ..remote.v = 0
        ..deleted.v = 1,
    );
    expect(
      (await sdbMediaStore.record(fileId).get(db.database))!.deleted.v,
      isTrue,
    );
    expect(await file.exists(), isFalse);
    // record still present
    expect(await db.getMediaFileRecord(fileId), isNotNull);
    await db.purgeMediaFile(fileId);
    expect(await db.getMediaFileRecord(fileId), isNull);
  });

  test('getAllRecords', () async {
    var content = Uint8List.fromList([1, 2, 3]);
    await db.addMediaFile(
      bytes: content,
      file: FestenaoMediaFile.from(filename: 'test1.webp', type: 'image/webp'),
    );
    await db.addMediaFile(
      bytes: content,
      file: FestenaoMediaFile.from(filename: 'test2.webp', type: 'image/webp'),
    );
    var records = await db.getAllRecords();
    expect(records, hasLength(2));
  });

  test('file system check', () async {
    var content = Uint8List.fromList([1, 2, 3, 4]);
    var fileId = await db.addMediaFile(
      bytes: content,
      file: FestenaoMediaFile.from(
        filename: 'test_fs.webp',
        type: 'image/webp',
      ),
    );
    // Verify file exists in fs
    var file = await db.getMediaFile(fileId);
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), content);

    // Check if we can find it manually in fs if we knew the path,
    // but path is internal. We can check if *some* file exists.
    // The path is constructed as folder1/folder2/fileId
    // We can inspect the record to get the path.
    var records = await db.getAllRecords();
    var record = records.firstWhere((r) => r.id == fileId);
    expect(await fs.file(fs.path.normalize(record.path.v!)).exists(), isTrue);
  });

  Future<String> addSimpleFile() async {
    var content = Uint8List.fromList([1, 2, 3, 4]);
    var fileId = await db.addMediaFile(
      bytes: content,
      file: FestenaoMediaFile.from(
        filename: 'test_fs.webp',
        type: 'image/webp',
      ),
    );
    return fileId;
  }

  test('markLocalNotPresentDeleted', () async {
    var fileId = await addSimpleFile();
    await db.markRemoteDeleted(fileId);
    expect(
      await sdbMediaStatusLocalStore.record(fileId).get(db.database),
      SdbFestenaoMediaFileStatus()
        ..local.v = 1
        ..remote.v = 0
        ..deleted.v = 1,
    );
  });
}
