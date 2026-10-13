import 'dart:typed_data';

import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_db_synchronizer.dart';
import 'package:festenao_common/data/festenao_media_source.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

/// Remote media in memory.
class _MemoryMediaSource implements FestenaoMediaSource {
  final files = <String, Uint8List>{};

  @override
  Future<void> addMediaFile({
    required FestenaoMediaFile file,
    required Uint8List bytes,
  }) async {
    files[file.path] = bytes;
  }

  @override
  Future<void> deleteMediaFile(FestenaoMediaFileRef ref) async {
    files.remove(ref.path);
  }

  @override
  Future<Uint8List> readMediaFileBytes(FestenaoMediaFileRef ref) async =>
      files[ref.path]!;
}

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
    expect(await file.exists(), isFalse);
    await expectLater(() => db.readMediaFileBytes(fileId), throwsException);
    await expectLater(() => db.getMediaFile(fileId), throwsException);

    // Kept marked as deleted for the synchronizer.
    expect((await db.getMediaFileRecord(fileId))!.deleted.v, isTrue);
    expect(await db.getAllRecords(), isEmpty);
    expect(await db.fileIdsToUpload(), [fileId]);
  });

  test('sync up and down', () async {
    var source = _MemoryMediaSource();
    var content = Uint8List.fromList([1, 2, 3]);
    var fileId = await db.addMediaFile(
      bytes: content,
      file: FestenaoMediaFile.from(filename: 'test.webp', type: 'image/webp'),
    );
    var synchronizer = FestenaoMediaDbSynchronizer(db: db, source: source);
    await synchronizer.sync();
    var path = (await db.getMediaFileRecord(fileId))!.path.v!;
    expect(source.files[path], content);

    // A synced record without local status (another device) is downloaded
    var otherFs = newFileSystemMemory();
    var otherSembastDb = await openNewInMemoryDatabase();
    var otherDb = FestenaoMediaDb(fs: otherFs, database: otherSembastDb);
    await dbMediaStoreRef
        .record(fileId)
        .put(otherSembastDb, (await db.getMediaFileRecord(fileId))!);
    expect(await otherDb.fileIdsToDownload(), [fileId]);
    var otherSynchronizer = FestenaoMediaDbSynchronizer(
      db: otherDb,
      source: source,
    );
    await otherSynchronizer.sync();
    expect(await otherDb.readMediaFileBytes(fileId), content);
    expect(await otherDb.fileIdsToDownload(), isEmpty);

    // Deleted locally, the remote file is deleted
    await db.deleteMediaFile(fileId);
    await synchronizer.sync();
    expect(source.files, isEmpty);
    expect(await db.fileIdsToUpload(), isEmpty);
    expect(await db.fileIdsToDelete(), isEmpty);

    // The other device deletes its local file
    await dbMediaStoreRef
        .record(fileId)
        .put(otherSembastDb, (await db.getMediaFileRecord(fileId))!);
    expect(await otherDb.fileIdsToDelete(), [fileId]);
    await otherSynchronizer.syncDown();
    expect(await otherFs.file(otherFs.path.normalize(path)).exists(), isFalse);
    expect(await otherDb.fileIdsToDelete(), isEmpty);
    await otherSembastDb.close();
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
