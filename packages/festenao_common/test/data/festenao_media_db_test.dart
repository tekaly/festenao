import 'dart:typed_data';

import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';
import 'package:test/test.dart';

Future<void> main() async {
  late final FestenaoMediaDb db;
  setUp(() async {
    db = FestenaoMediaDb(
      fs: newFileSystemMemory(),
      sdbFactory: newSdbFactoryMemory(),
    );
  });
  test('write/read/delete', () async {
    var content = Uint8List.fromList([1, 2, 3]);
    var fileId = await db.addMediaFile(bytes: content, filename: 'test.mp4');
    expect(await db.readMediaFileBytes(fileId), content);
    await db.deleteMediaFile(fileId);
    await expectLater(() => db.readMediaFileBytes(fileId), throwsException);
  });
}
