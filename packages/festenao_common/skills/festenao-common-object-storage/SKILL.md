---
name: festenao-common-object-storage
description: >-
  Use when an app stores or serves files (songs, images, documents) through
  festenao_common's ObjectStorage abstraction: ObjectStorageFs,
  ObjectStorageFirebase, ObjectStorageGdrive, ObjectStorageSdb and
  ObjectStorageSdbCached, ObjectStorageApiClient over the api, the
  list/getItem/upload/download/downloadPart/downloadStream/delete/getDownloadUrl
  methods, and the server side FestenaoObjectStorageHandler answering the
  gdrive/list, gdrive/getItem, gdrive/upload, gdrive/download, gdrive/delete
  and gdrive/getDownloadUrl commands (GdriveApiService).
---

# festenao_common object storage

`ObjectStorage` is one interface over a file store: a directory on a file
system, a firebase storage bucket, a google drive folder, a local sdb
database, or another storage reached through the api of a festenao server.
Paths are posix relative paths inside the store (`songs/intro.mp3`); a
"location" is a folder.

## Guidelines

* Import `package:festenao_common/data/object_storage.dart`: the interface,
  `ObjectStorageMeta` (`name`, `path`, `size`, `mimeType`, `isLocation`),
  `ObjectStorageListResponse` (`items`, `nextPageToken`), every
  implementation and `Uint8List`. Server side add
  `package:festenao_common/server/festeano_server_object_storage_handler.dart`.
* Methods: `list(path, pageToken:, maxResults:)` (one level, page through
  `nextPageToken`), `getItem(path)`, `upload(path, name:, data:, mimeType:)`
  (`path` is the folder, the object lands at `<path>/<name>`, created on
  the way; returns its meta), `download(path)`, `downloadPart(path, start,
  size)`, `downloadStream(path, start:, size:, chunkSize:)` (chunks from
  the download url when the store has one, from `downloadPart` otherwise),
  `delete(path)`, `getDownloadUrl(path)` (null unless the store serves
  files by url: google drive's `webContentLink`, for whoever may read the
  file).
* Implementations: `ObjectStorageFs(fileSystem:, rootPath:)` (`fs_shim`,
  memory or io file system), `ObjectStorageFirebase(storage:, bucket:)`
  (a `FirebaseStorage` bucket), `ObjectStorageGdrive(gdrive:)` (a `GDrive`
  helper of `tekartik_gdrive_api_utils` on a service account or a signed in
  user), `ObjectStorageSdb(factory:, fileSystem:, rootPath:)` (files in a
  local database, offline apps) and `ObjectStorageSdbCached(delegate:,
  cache:)` (an `ObjectStorageSdb` in front of any store, filled on first
  read).
* Over the api: `ObjectStorageApiClient(httpsUri:, httpClientFactory:)`
  is an `ObjectStorage` whose every call is a `gdrive/...` command sent to
  `httpsUri` (the `command` function of a festenao server); the server
  answers with a `FestenaoObjectStorageHandler(options:
  FestenaoObjectStorageHandlerOptions(objectStorage:))` in front of the real
  store, asked from `onCommand` like any `FestenaoApiHandler`. Its commands
  are the `GdriveApiService` constants (`gdrive/list`, `gdrive/getItem`,
  `gdrive/upload`, `gdrive/download`, `gdrive/delete`,
  `gdrive/getDownloadUrl`); `initGdriveApiBuilders()` registers their
  models (import `package:festenao_common/api/gdrive_api_service.dart`).
  The client still needs a signed in user when the server checks one.
* Keep business code on `ObjectStorage`: a song cache, a picker, a sync
  work the same on drive, on firebase storage and on a memory file system,
  which is how they are tested.
* Large files: prefer `downloadStream` (a `Range` request per chunk on a
  url store, `downloadPart` otherwise) to `download`, and mind that
  `upload` takes the whole `Uint8List`.

## Examples

### A file store on a memory file system

```dart
import 'dart:convert';

import 'package:festenao_common/data/object_storage.dart';
import 'package:fs_shim/fs_memory.dart';

Future<void> main() async {
  ObjectStorage storage = ObjectStorageFs(
    fileSystem: newFileSystemMemory(),
    rootPath: '/drive',
  );
  var meta = await storage.upload(
    'songs',
    name: 'intro.txt',
    data: Uint8List.fromList(utf8.encode('hello')),
    mimeType: 'text/plain',
  );
  print('${meta.path} ${meta.size} ${meta.mimeType}'); // songs/intro.txt 5 text/plain

  var listed = await storage.list('songs');
  print(listed.items.map((item) => item.name).toList()); // [intro.txt]

  print(utf8.decode(await storage.download('songs/intro.txt'))); // hello
  var part = <int>[];
  await for (var chunk in storage.downloadStream(
    'songs/intro.txt',
    start: 1,
    size: 3,
    chunkSize: 2,
  )) {
    part.addAll(chunk);
  }
  print(utf8.decode(part)); // ell
  await storage.delete('songs/intro.txt');
}
```

### The same store through the api

```dart
import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_firebase.dart';
import 'package:festenao_common/festenao_flavor.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/server/festeano_server_object_storage_handler.dart';
import 'package:fs_shim/fs_memory.dart';

/// A server serving a file system directory as object storage.
class FilesServerApp extends FestenaoServerApp {
  final ObjectStorage objectStorage;

  FilesServerApp({required super.context, required this.objectStorage})
    : super(app: 'files');

  late final objectStorageHandler = FestenaoObjectStorageHandler(
    options: FestenaoObjectStorageHandlerOptions(objectStorage: objectStorage),
  );

  @override
  Future<ApiResult> onCommand(ApiRequest apiRequest) async {
    return await objectStorageHandler.onCommandOrNull(apiRequest) ??
        await super.onCommand(apiRequest);
  }
}

Future<void> main() async {
  var services = initFirebaseServicesLocalMemory(projectId: 'demo');
  var serverContext = await services.initServer();
  var app = FilesServerApp(
    context: TkCmsServerAppContext(
      firebaseContext: serverContext,
      flavorContext: FlavorContext.dev,
    ),
    objectStorage: ObjectStorageFs(
      fileSystem: newFileSystemMemory(),
      rootPath: '/drive',
    ),
  );
  app.initFunctions();
  var ffServer = await serverContext.functions.serve();

  // The client sees an ObjectStorage, the files live on the server.
  ObjectStorage remote = ObjectStorageApiClient(
    httpsUri: ffServer.uri.replace(path: app.command),
    httpClientFactory: httpClientFactoryMemory,
  );
  await remote.upload(
    'docs',
    name: 'readme.txt',
    data: Uint8List.fromList('hi'.codeUnits),
    mimeType: 'text/plain',
  );
  print((await remote.list('docs')).items.single.path); // docs/readme.txt
  print(await remote.getDownloadUrl('docs/readme.txt')); // null, no url store
  await ffServer.close();
}
```

## Common mistakes

* Passing the full object path to `upload` as `path`: `path` is the folder,
  `name` the file name, or the object ends up one level too deep.
* Reading `meta.size` or `mimeType` as non null: a location has none, and
  some stores do not report them.
* Expecting `getDownloadUrl` from a file system or firebase store: it is
  null there, only google drive serves files by url.
