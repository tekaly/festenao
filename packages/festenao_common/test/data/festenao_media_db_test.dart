import 'dart:typed_data';

import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  late FestenaoMediaDb db;
  late Database sembastDb;
  late final fs = db.fs;
  setUp(() async {
    sembastDb = await openNewInMemoryDatabase();
    db = FestenaoMediaDb(fs: newFileSystemMemory(), database: sembastDb);
  });
  tearDown(() async {
    await sembastDb.close();
  });
  test('write/read/delete', () async {
    var content = Uint8List.fromList([1, 2, 3]);
    var fileId = await db.addMediaFile(
      bytes: content,
      file: FestenaoMediaFile.from(filename: 'test.webp', type: 'image/webp'),
    );
    expect(await db.readMediaFileBytes(fileId), content);
    var record = (await db.getMediaFileRecord(fileId))!;
    expect(record.id, fileId);
    expect(record.toMap(), {
      'filename': 'test.webp',
      'path': record.path.v,
      'createdTimestamp': record.createdTimestamp.v,
    });
    var file = await db.getMediaFile(fileId);
    expect(await file.exists(), isTrue);
    expect(await file.readAsBytes(), content);
    await db.deleteMediaFile(fileId);
    expect(await file.exists(), isFalse);
    await expectLater(() => db.readMediaFileBytes(fileId), throwsException);
    await expectLater(() => db.getMediaFile(fileId), throwsException);

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
}
