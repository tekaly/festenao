import 'dart:typed_data';

import 'package:festenao_common/data/festenao_db.dart';
import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:festenao_common/data/festenao_media_db_synchronizer.dart';
import 'package:festenao_common/data/festenao_media_source.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

const _timeout = Timeout(Duration(seconds: 30));

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

  @override
  Future<Uri?> getMediaUrl(FestenaoMediaFileRef ref) async => null;
}

/// The app file system: a precious file next to the media sandbox.
Future<FileSystem> _newRootFileSystem() async {
  var rootFs = newFileSystemMemory();
  await rootFs.file('app/data.db').create(recursive: true);
  await rootFs.file('app/data.db').writeAsString('precious');
  await rootFs.directory('app/media').create(recursive: true);
  return rootFs;
}

void main() {
  group('synced media record path', () {
    test('cannot write outside of the media file system', () async {
      var rootFs = await _newRootFileSystem();
      var database = await newDatabaseFactoryMemory().openDatabase('m.db');
      var mediaDb = FestenaoMediaDb(
        fs: rootFs.sandbox(path: 'app/media'),
        database: database,
      );
      await mediaDb.ready;
      var path = '../data.db';
      var source = _MemoryMediaSource()
        ..files[path] = Uint8List.fromList([1, 2, 3]);
      // As synced down from another device.
      await dbMediaStoreRef
          .record('u1')
          .put(
            database,
            DbFestenaoMediaFile()
              ..path.v = path
              ..originalFilename.v = 'x.bin',
          );
      var synchronizer = FestenaoMediaDbSynchronizer(
        db: mediaDb,
        source: source,
      );
      await expectLater(
        synchronizer.syncDown(),
        throwsA(isA<FestenaoMediaDbException>()),
      );
      await expectLater(
        mediaDb.writeMediaFileBytes(
          FestenaoMediaFileRef.fromPath(path),
          Uint8List.fromList([1]),
        ),
        throwsA(isA<FestenaoMediaDbException>()),
      );
      await expectLater(
        mediaDb.readMediaFileBytes('u1'),
        throwsA(isA<FestenaoMediaDbException>()),
      );
      expect(await rootFs.file('app/data.db').readAsString(), 'precious');
      await database.close();
    }, timeout: _timeout);

    test('cannot delete outside of the media file system', () async {
      var rootFs = await _newRootFileSystem();
      var database = await newDatabaseFactoryMemory().openDatabase('m.db');
      var mediaDb = FestenaoMediaDb(
        fs: rootFs.sandbox(path: 'app/media'),
        database: database,
      );
      await mediaDb.ready;
      for (var path in ['../data.db', '..', '.', '']) {
        await dbMediaStoreRef
            .record('u1')
            .put(
              database,
              DbFestenaoMediaFile()
                ..path.v = path
                ..originalFilename.v = 'x.bin'
                ..deleted.v = true,
            );
        await FestenaoMediaDbSynchronizer(
          db: mediaDb,
          source: _MemoryMediaSource(),
        ).syncDown();
        await mediaDb.deleteMediaFileBytes(FestenaoMediaFileRef.fromPath(path));
        expect(await rootFs.file('app/data.db').exists(), isTrue);
        expect(await rootFs.directory('app/media').exists(), isTrue);
      }
      await database.close();
    }, timeout: _timeout);

    test('a valid path still goes through', () async {
      var rootFs = await _newRootFileSystem();
      var fs = rootFs.sandbox(path: 'app/media');
      var database = await newDatabaseFactoryMemory().openDatabase('m.db');
      var mediaDb = FestenaoMediaDb(fs: fs, database: database);
      await mediaDb.ready;
      var path = 'project/p1/x.bin';
      var source = _MemoryMediaSource()
        ..files[path] = Uint8List.fromList([1, 2, 3]);
      await dbMediaStoreRef
          .record('u1')
          .put(
            database,
            DbFestenaoMediaFile()
              ..path.v = path
              ..originalFilename.v = 'x.bin',
          );
      await FestenaoMediaDbSynchronizer(db: mediaDb, source: source).syncDown();
      expect(await mediaDb.readMediaFileBytes('u1'), [1, 2, 3]);
      await mediaDb.deleteMediaFile('u1');
      expect(await fs.file(path).exists(), isFalse);
      await database.close();
    }, timeout: _timeout);
  });

  test('a failed database is reported by ready only', () async {
    // An uncaught error here fails the test, ready being caught.
    var mediaDb = FestenaoMediaDb(
      fs: newFileSystemMemory(),
      futureDatabase: Future<Database>.error(StateError('open failed')),
    );
    await expectLater(mediaDb.ready, throwsA(isA<StateError>()));
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }, timeout: _timeout);
}
