import 'dart:typed_data';

import 'package:festenao_common/src/data/storage/object_storage.dart';
import 'package:festenao_common/src/data/storage/object_storage_firebase.dart';
import 'package:tekartik_app_media/mime_type.dart';
import 'package:tekartik_firebase_local/firebase_local.dart';
import 'package:tekartik_firebase_storage_fs/storage_fs.dart';
import 'package:test/test.dart';

abstract class ObjectStorageTestContext {
  ObjectStorage get storage;
  Future<void> dispose();
}

class _ObjectStorageFirebaseTestMemoryContext
    extends ObjectStorageFirebaseTestContext {
  final FirebaseApp _app;

  factory _ObjectStorageFirebaseTestMemoryContext.memory() {
    var app = newFirebaseAppMemory();
    var firebaseStorage = newStorageServiceMemory().storage(app);
    var bucket = firebaseStorage.bucket();
    return _ObjectStorageFirebaseTestMemoryContext(
      app: app,
      storage: ObjectStorageFirebase(storage: firebaseStorage, bucket: bucket),
    );
  }

  _ObjectStorageFirebaseTestMemoryContext({
    required FirebaseApp app,
    required super.storage,
  }) : _app = app;
  @override
  Future<void> dispose() async {
    await _app.delete();
  }
}

class ObjectStorageFirebaseTestContext implements ObjectStorageTestContext {
  @override
  final ObjectStorageFirebase storage;

  ObjectStorageFirebaseTestContext({required this.storage});

  factory ObjectStorageFirebaseTestContext.memory() =>
      _ObjectStorageFirebaseTestMemoryContext.memory();

  @override
  Future<void> dispose() async {}
}

void objectStorageTest(ObjectStorageTestContext Function() newContext) {
  late ObjectStorageTestContext ctx;

  setUp(() {
    ctx = newContext();
  });

  tearDown(() async {
    await ctx.dispose();
  });

  test('upload and download', () async {
    var data = Uint8List.fromList([1, 2, 3, 4, 5]);
    var file = await ctx.storage.upload(
      'test',
      name: 'file.bin',
      data: data,
      mimeType: mimeTypeOctetStream,
    );
    var result = await ctx.storage.download(file.path);
    expect(result, data);
  });

  test('getMeta', () async {
    var data = Uint8List.fromList([10, 20, 30]);
    var meta = await ctx.storage.upload(
      'test',
      name: 'meta.bin',
      data: data,
      mimeType: mimeTypeOctetStream,
    );
    expect(meta.size, data.length);
    expect(meta.isLocation, false);

    var fetched = await ctx.storage.getItem(meta.path);
    expect(fetched.path, meta.path);
    expect(fetched.size, data.length);
  });

  test('list', () async {
    var data = Uint8List.fromList([1, 2, 3]);
    var fileA = await ctx.storage.upload(
      'list_test',
      name: 'a.bin',
      data: data,
      mimeType: mimeTypeOctetStream,
    );
    var fileB = await ctx.storage.upload(
      'list_test',
      name: 'b.bin',
      data: data,
      mimeType: mimeTypeOctetStream,
    );

    var response = await ctx.storage.list('list_test');
    var paths = response.items.map((m) => m.path).toList()..sort();
    expect(paths, [fileA.path, fileB.path]);
  });

  test('delete', () async {
    var data = Uint8List.fromList([1, 2, 3]);
    var file = await ctx.storage.upload(
      'del_test',
      name: 'file.bin',
      data: data,
      mimeType: mimeTypeOctetStream,
    );
    await ctx.storage.delete(file.path);

    expect(() => ctx.storage.download(file.path), throwsA(anything));
  });
}

void main() {
  group('object_storage_firebase_memory', () {
    objectStorageTest(ObjectStorageFirebaseTestContext.memory);
  });
}
