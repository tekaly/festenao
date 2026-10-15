import 'package:festenao_common/src/data/storage/object_storage_gdrive.dart';
import 'package:googleapis/drive/v3.dart' as gd;
import 'package:test/test.dart';

void main() {
  group('gdriveObjectStorageMeta', () {
    test('a file, a folder', () {
      var file = gdriveObjectStorageMeta(
        gd.File()
          ..id = 'f1'
          ..name = 'song.mp3'
          ..mimeType = 'audio/mpeg'
          ..size = '123'
          ..modifiedTime = DateTime.utc(2026, 10, 9, 14, 32),
      );
      expect(file.path, 'f1');
      expect(file.size, 123);
      expect(file.modified, DateTime.utc(2026, 10, 9, 14, 32));
      expect(file.isLocation, isFalse);
      var folder = gdriveObjectStorageMeta(
        gd.File()
          ..id = 'd1'
          ..name = 'Album'
          ..mimeType = 'application/vnd.google-apps.folder',
      );
      expect(folder.isLocation, isTrue);
      expect(folder.size, isNull);
    });
    test('a shortcut is its target, under its own name', () {
      var toFile = gdriveObjectStorageMeta(
        gd.File()
          ..id = 's1'
          ..name = 'Hip hop.mp3'
          ..mimeType = gdriveShortcutMimeType
          ..modifiedTime = DateTime.utc(2026, 1, 1)
          ..shortcutDetails = (gd.FileShortcutDetails()
            ..targetId = 't1'
            ..targetMimeType = 'audio/mpeg'),
      );
      expect(toFile.path, 't1');
      // The shortcut's own time is not the target's.
      expect(toFile.modified, isNull);
      expect(toFile.name, 'Hip hop.mp3');
      expect(toFile.mimeType, 'audio/mpeg');
      expect(toFile.isLocation, isFalse);
      var toFolder = gdriveObjectStorageMeta(
        gd.File()
          ..id = 's2'
          ..name = 'Album link'
          ..mimeType = gdriveShortcutMimeType
          ..shortcutDetails = (gd.FileShortcutDetails()
            ..targetId = 't2'
            ..targetMimeType = 'application/vnd.google-apps.folder'),
      );
      expect(toFolder.path, 't2');
      expect(toFolder.isLocation, isTrue);
    });
  });
}
