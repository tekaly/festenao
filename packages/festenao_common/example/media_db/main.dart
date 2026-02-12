// ignore_for_file: avoid_print

import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:festenao_common/data/festenao_media_db.dart';
import 'package:fs_shim/fs_io.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:path/path.dart';
import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

Future<void> main() async {
  var db = FestenaoMediaDb(
    fs: fileSystemIo.sandbox(path: join('.local', 'media_db')),
    sdbFactory: sdbFactoryIo,
  );

  var content = Uint8List.fromList([1, 2, 3]);
  var fileId = await db.addMediaFile(
    bytes: content,
    filename: 'test_with_a_very_long_name_that_does_not_fit.mp4',
  );
  print('fileId: $fileId');
  assert(
    const DeepCollectionEquality().equals(
      await db.readMediaFileBytes(fileId),
      content,
    ),
  );
}
