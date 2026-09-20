---
name: festenao-object-storage-picker-ui
description: >-
  Use when a Flutter app must let the user browse an ObjectStorage (Google
  Drive, Firebase Storage, fs, sdb) and pick one or several files: the
  ObjectStoragePicker widget (storage:, parentPath:, allowedMimeTypes:,
  onSelect:, allowMultiSelect:, developerMode:), the
  ObjectStoragePickerOnSelect callback, the full screen
  ObjectStoragePickerScreen that pops a List<ObjectStorageMeta>, the Google
  Drive folder url/id entry flow ObjectStoragePickerFlowScreen.show(...) and
  its FolderHistorySdb history database (addFolderId, getLatestFolderIds), from
  package:festenao_object_storage_picker/festenao_object_storage_picker.dart.
---

# Object storage file picker (festenao_object_storage_picker)

A small Flutter UI on top of the `ObjectStorage` abstraction of
`festenao_common`: a browser widget with a breadcrumb, a full screen wrapper
that returns the selection, and a Google-Drive-flavoured flow screen that asks
for a folder url/id and remembers the last 100 folders in an sdb database.

## Guidelines

* Dependency (not on pub.dev, git only). The picker does **not** re-export the
  storage API, so depend on `festenao_common` too:

  ```yaml
  dependencies:
    festenao_object_storage_picker:
      git:
        url: https://github.com/tekaly/festenao
        path: packages_flutter/festenao_object_storage_picker
    festenao_common:
      git:
        url: https://github.com/tekaly/festenao
        path: packages/festenao_common
  ```

* Imports: `package:festenao_object_storage_picker/festenao_object_storage_picker.dart`
  for `ObjectStoragePicker`, `ObjectStoragePickerOnSelect`,
  `ObjectStoragePickerScreen`, `ObjectStoragePickerFlowScreen` and
  `FolderHistorySdb`; `package:festenao_common/data/object_storage.dart` for
  `ObjectStorage`, `ObjectStorageMeta` and the implementations
  (`ObjectStorageGdrive`, `ObjectStorageFirebase`, `ObjectStorageFs`,
  `ObjectStorageSdb`, `ObjectStorageApiClient`). Never import
  `package:festenao_object_storage_picker/src/...`.
* `ObjectStoragePicker({required ObjectStorage storage, required String
  parentPath, List<String>? allowedMimeTypes, required
  ObjectStoragePickerOnSelect onSelect, bool allowMultiSelect = false, bool
  developerMode = false})` is a `Column`: a breadcrumb bar, an expanded list
  and (in multi-select) a bottom action bar. It needs a **bounded height**, so
  put it in a `Scaffold` body, an `Expanded` or a `SizedBox`, never directly in
  an unbounded `Column`/`ListView`.
* `parentPath` is the root of the browsing session and is what the storage
  means by a path: a posix path for `ObjectStorageFs`/`ObjectStorageSdb`, a
  **folder id** for `ObjectStorageGdrive`. The breadcrumb shows it as `Root`;
  navigating into a folder pushes `item.path` on an internal stack, and the
  back arrow only goes up to `parentPath` — it never leaves it.
* `onSelect` (`void Function(List<ObjectStorageMeta> selected)`) is the only
  output of the widget itself:
  * `allowMultiSelect: false` (default) — tapping a file calls `onSelect` with
    that single item immediately. There is no confirm button.
  * `allowMultiSelect: true` — taps toggle checkboxes and `onSelect` is called
    once, with every checked item, from the bottom `Select` button.
* `allowedMimeTypes` filters **files only**; folders (`meta.isLocation`) are
  always listed. An entry is either an exact type (`application/pdf`) or a
  `type/*` prefix (`image/*`). A `null`/empty list allows everything, but once
  the list is non-empty a file whose `mimeType` is `null` is hidden — a storage
  that does not report mime types will look empty.
* `developerMode: true` adds the raw `path`/id as a subtitle and an
  *open in browser* button per row. That button uses `url_launcher` and assumes
  Google Drive: a path that is not already `http(s)://` is opened as
  `https://drive.google.com/open?id=<path>`. Leave it `false` in production.
* `ObjectStoragePickerScreen({String title = 'Select Files', required storage,
  required parentPath, allowedMimeTypes, allowMultiSelect, developerMode})` is
  a `Scaffold` + `AppBar` around the picker whose `onSelect` does
  `Navigator.pop(selected)`. Push it with an explicit type —
  `Navigator.of(context).push<List<ObjectStorageMeta>>(...)` — and handle
  `null` (the user popped with the back button).
* `ObjectStoragePickerFlowScreen` is the Google Drive entry flow: a text field
  that permissively parses a folder id out of what is pasted (`?id=`,
  `/folders/<id>`, `/d/<id>/edit`, the last path segment of any url, or the raw
  trimmed input), the *Recent Folders* history, then the picker screen. Use the
  static `ObjectStoragePickerFlowScreen.show({required BuildContext context,
  required ObjectStorage storage, required FolderHistorySdb sdb,
  List<String>? allowedMimeTypes, bool allowMultiSelect = false, bool
  developerMode = false})`, which returns `Future<List<ObjectStorageMeta>?>`,
  rather than pushing the widget yourself.
* `FolderHistorySdb({required SdbFactory factory, String? name})` opens
  `folder_history_v1.db` (v1, store `folder_history`) lazily through its
  `ready` future; `FolderHistorySdb.inMemory()` uses `sdbFactoryMemory` for
  tests and demos. `addFolderId(String)` upserts by id and trims to the 100
  most recent, `getLatestFolderIds()` returns them newest first, `close()`
  closes the database. Create **one** instance for the app (keep it in a
  provider/singleton) — do not build a new one per screen push, and `close()`
  it only when you are done with it.
* Known limits, do not work around them in the widget: the picker lists one
  page (`ObjectStorageListResponse.nextPageToken` is ignored, pass a storage
  that returns everything or a big `maxResults`), it is read-only (no upload,
  delete, rename or folder creation), and it reloads the folder on every
  navigation with no cache — wrap the storage in `ObjectStorageSdbCached` if
  that hurts.
* Anti-patterns: calling `Navigator.pop` yourself from the `onSelect` of
  `ObjectStoragePickerScreen` (it already pops); passing a Drive **url** as
  `parentPath` for `ObjectStorageGdrive` (pass the id, or let the flow screen
  parse it); assuming `onSelect` fires once in single-select mode (it fires on
  every tap); comparing selections by `path` when the widget's own set uses
  identity of `ObjectStorageMeta` instances.
* Testing: `ObjectStorageSdb.inMemory()` gives a real storage backed by a
  memory sdb and a memory file system — `upload(parentPath, name: ..., data:
  ..., mimeType: ...)` a few files, then `tester.pumpWidget` the picker inside
  a `MaterialApp`/`Scaffold` and `await tester.pumpAndSettle()` before tapping
  a tile.

## Examples

### Pushing the picker screen and reading the selection

```dart
import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_object_storage_picker/festenao_object_storage_picker.dart';
import 'package:flutter/material.dart';

/// Browse [storage] from [parentPath] and return the single picked image,
/// null when the user backed out.
Future<ObjectStorageMeta?> pickOneImage(
  BuildContext context, {
  required ObjectStorage storage,
  required String parentPath,
}) async {
  var selected = await Navigator.of(context).push<List<ObjectStorageMeta>>(
    MaterialPageRoute(
      builder: (context) => ObjectStoragePickerScreen(
        title: 'Pick an image',
        storage: storage,
        parentPath: parentPath,
        // Folders are always shown, this only filters files.
        allowedMimeTypes: const ['image/*'],
      ),
    ),
  );
  // Null when popped without a selection.
  return selected?.firstOrNull;
}

/// Same thing, several files at once: the bottom `Select` button confirms.
Future<List<ObjectStorageMeta>> pickDocuments(
  BuildContext context, {
  required ObjectStorage storage,
  required String parentPath,
}) async {
  var selected = await Navigator.of(context).push<List<ObjectStorageMeta>>(
    MaterialPageRoute(
      builder: (context) => ObjectStoragePickerScreen(
        title: 'Pick documents',
        storage: storage,
        parentPath: parentPath,
        allowedMimeTypes: const ['application/pdf', 'text/*'],
        allowMultiSelect: true,
      ),
    ),
  );
  return selected ?? <ObjectStorageMeta>[];
}
```

### Embedding the picker in your own screen

```dart
import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_object_storage_picker/festenao_object_storage_picker.dart';
import 'package:flutter/material.dart';

/// The picker is a Column: it must be given a bounded height, here by the
/// Scaffold body and the Expanded.
class AttachmentsScreen extends StatefulWidget {
  /// The storage to browse.
  final ObjectStorage storage;

  /// Root of the browsing session (a posix path, or a gdrive folder id).
  final String parentPath;

  /// Constructor.
  const AttachmentsScreen({
    super.key,
    required this.storage,
    required this.parentPath,
  });

  @override
  State<AttachmentsScreen> createState() => _AttachmentsScreenState();
}

class _AttachmentsScreenState extends State<AttachmentsScreen> {
  final _attachments = <ObjectStorageMeta>[];

  /// Called once with every checked item in multi-select mode.
  void _onSelect(List<ObjectStorageMeta> selected) {
    setState(() {
      _attachments
        ..clear()
        ..addAll(selected);
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Attachments (${_attachments.length})')),
    body: Column(
      children: [
        Expanded(
          child: ObjectStoragePicker(
            storage: widget.storage,
            parentPath: widget.parentPath,
            allowMultiSelect: true,
            onSelect: _onSelect,
          ),
        ),
        for (var attachment in _attachments)
          ListTile(
            dense: true,
            title: Text(attachment.name),
            subtitle: Text(attachment.mimeType ?? 'unknown'),
          ),
      ],
    ),
  );
}
```

### The Google Drive folder flow with its history database

```dart
import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_object_storage_picker/festenao_object_storage_picker.dart';
import 'package:flutter/material.dart';

/// One instance for the app: the sdb is opened lazily on first use.
/// In a real app keep it in a provider/singleton instead of a global.
final folderHistorySdb = FolderHistorySdb.inMemory();

/// Ask for a drive folder (pasted url or raw id, or one of the last 100
/// folders), then pick images in it.
Future<List<ObjectStorageMeta>?> pickFromDrive(
  BuildContext context, {
  required ObjectStorage storage,
}) => ObjectStoragePickerFlowScreen.show(
  context: context,
  storage: storage,
  sdb: folderHistorySdb,
  allowedMimeTypes: const ['image/*'],
  allowMultiSelect: true,
);

/// The history is also usable on its own, e.g. to offer the last folder
/// without showing the flow screen.
Future<String?> lastUsedFolderId() async {
  var ids = await folderHistorySdb.getLatestFolderIds();
  return ids.firstOrNull;
}

/// Record a folder the user reached some other way so it shows up in the
/// flow screen next time.
Future<void> rememberFolder(String folderId) =>
    folderHistorySdb.addFolderId(folderId);
```

### Widget test over an in-memory storage

```dart
import 'dart:convert';

import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_object_storage_picker/festenao_object_storage_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('picks a file', (tester) async {
    // Real storage, memory sdb + memory file system.
    var storage = ObjectStorageSdb.inMemory();
    await storage.upload(
      '/docs',
      name: 'note.txt',
      data: Uint8List.fromList(utf8.encode('hello')),
      mimeType: 'text/plain',
    );

    ObjectStorageMeta? picked;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ObjectStoragePicker(
            storage: storage,
            parentPath: '/docs',
            allowedMimeTypes: const ['text/*'],
            // Single select: fires on every file tap.
            onSelect: (selected) => picked = selected.first,
          ),
        ),
      ),
    );
    // The first frame is the loading spinner.
    await tester.pumpAndSettle();

    await tester.tap(find.text('note.txt'));
    await tester.pump();
    expect(picked!.path, '/docs/note.txt');

    await storage.close();
  });
}
```
