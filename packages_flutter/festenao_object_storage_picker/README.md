# festenao_object_storage_picker

A Flutter file picker on top of the `ObjectStorage` abstraction of
`festenao_common` (Google Drive, Firebase Storage, a file system, an sdb
database): browse folders with a breadcrumb, filter by mime type, pick one or
several files.

- `ObjectStoragePicker`: the browser widget (needs a bounded height).
- `ObjectStoragePickerScreen`: the same in a `Scaffold`, popping the
  selection (`List<ObjectStorageMeta>`).
- `ObjectStoragePickerFlowScreen.show(...)`: asks for a Google Drive folder
  (a pasted url or an id, or one of the last 100 opened, kept in a
  `FolderHistorySdb`), then pushes the picker on it.

## Getting started

Not on pub.dev, a git dependency; the storage api comes from
`festenao_common`:

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

```dart
import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_object_storage_picker/festenao_object_storage_picker.dart';
import 'package:material_ui/material_ui.dart';

/// The images picked below [parentPath], empty when the user backed out.
Future<List<ObjectStorageMeta>> pickImages(
  BuildContext context,
  ObjectStorage storage, {
  required String parentPath,
}) async {
  var selected = await Navigator.of(context).push<List<ObjectStorageMeta>>(
    MaterialPageRoute(
      builder: (_) => ObjectStoragePickerScreen(
        storage: storage,
        // A path for fs/sdb/firebase, a folder id for Google Drive.
        parentPath: parentPath,
        allowedMimeTypes: const ['image/*'],
        allowMultiSelect: true,
      ),
    ),
  );
  return selected ?? <ObjectStorageMeta>[];
}
```

`example/main.dart` runs it on an in memory storage (`ObjectStorageSdb.inMemory()`).

Platforms: every Flutter platform (mobile, desktop, web); what reaches the
storage is the storage's business (Drive needs a signed in Google client,
see `ObjectStorageGdrive` in festenao_common).

## What to know

- `parentPath` is the root of the session and what the storage calls a
  path: a posix path for `ObjectStorageFs` / `ObjectStorageSdb`, a **folder
  id** for `ObjectStorageGdrive` (not its url: the flow screen parses urls).
- Folders always show; `allowedMimeTypes` filters files (`image/*`,
  `application/pdf`...).
- Single select: `onSelect` fires on every file tap. Multi select: once,
  from the bottom `Select` button; the selection is kept by path across
  folders.
- Every page of a folder is listed (at most 100 pages); the picker is read
  only and reloads a folder each time it is opened.
- `FolderHistorySdb`: create one per app (it opens its database lazily),
  `close()` it when done; `FolderHistorySdb.inMemory()` in tests.

The package skill `skills/festenao-object-storage-picker-ui/SKILL.md` has
more examples (an embedded picker, the Drive flow, a widget test).
