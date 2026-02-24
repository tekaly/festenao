import 'dart:typed_data';

import 'package:festenao_common/data/festenao_media.dart';
import 'package:festenao_common/data/festenao_media_source_firebase.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_firebase_storage_fs/storage_fs.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_storage.dart';

void main() {
  group('festenao_media_source_firebase', () {
    late FestenaoMediaSourceFirebase source;
    late FirebaseApp app;

    setUp(() {
      app = newFirebaseAppLocal();
      // Set up in-memory storage using storage_fs
      var storage = storageServiceMemory.storage(app);

      var storageContext = FirebaseStorageContext(
        storage: storage,
        rootDirectory: 'test_media',
      );

      source = FestenaoMediaSourceFirebase(storageContext: storageContext);
    });
    tearDown(() async {
      await app.delete();
    });

    test('add/read/delete', () async {
      var content = Uint8List.fromList([1, 2, 3, 4, 5]);
      var file = FestenaoMediaFile.from(
        filename: 'test.webp',
        type: 'image/webp',
      );
      var ref = file.ref;

      await source.addMediaFile(bytes: content, file: file);

      var readBytes = await source.readMediaFileBytes(ref);
      expect(readBytes, content);

      await source.deleteMediaFile(ref);

      try {
        await source.readMediaFileBytes(ref);
        fail('Should throw exception when file is deleted');
      } catch (_) {
        // Expected error
      }
    });
  });
}
