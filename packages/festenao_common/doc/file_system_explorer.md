**Location:** Part of `festenao_common` (`lib/fs/file_system_explorer.dart`,
`lib/fs/file_system_explorer_io.dart`, implementation in `lib/src/fs/`) and
`festenao_common_flutter` (`lib/file_system_explorer_flutter.dart`,
implementation in `lib/src/files_system_explorer_flutter.dart`).

**Goal**

Browse a file system through `fs_shim` and open what is in it: a json or yaml
document goes to the [object editor](object_editor.md), a sembast or sdb
database file goes to the object explorer, a text file to a text editor. Read
only or read write, on the disk, in memory, or in a browser.

---

### 1. The pieces

| Concern | Type | Where |
|---|---|---|
| One file or directory | `FileSystemEntry`, `FileSystemEntryKind` | `file_system_explorer.dart` |
| The tree, and what opens each entry | `FileSystemExplorer` | `file_system_explorer.dart` |
| An open database and what browses it | `FileSystemDatabase`, `FileSystemDatabaseKind` | `file_system_explorer.dart` |
| sembast over `fs_shim` | `getDatabaseFactoryFsShim`, `getSdbFactoryFsShim` | `sembast_fs_shim.dart` |
| The screens | `FileSystemExplorerScreen`, `FileSystemTextFileScreen` | `festenao_common_flutter` |

`lib/fs/file_system_explorer.dart` imports on the web. `fileSystemIo` is in
`lib/fs/file_system_explorer_io.dart`.

---

### 2. The explorer

```dart
var explorer = FileSystemExplorer(
  fileSystem: fileSystemIo,     // or newFileSystemMemory(), or the web one
  rootPath: '.local',
);

for (var entry in await explorer.list()) {
  print('${entry.name} ${entry.kind}');
}
```

`list` answers directories first, then files by name. The kind of an entry
comes from its extension: `.json`, `.yaml`/`.yml`, a database extension
(`.db`, `.sembast`, `.sdb`), a text one, or binary.

Every path an explorer takes is **relative to its root and posix**, and one
that would leave the root throws a `FileSystemExplorerPathException` — so a
read only explorer of a directory really is contained in it. `explorer.sub(path)`
makes an explorer rooted further down.

---

### 3. Read only

A read only explorer refuses every write, hands out read only object sources
and opens its databases in `DatabaseMode.readOnly`. Handing one out is all it
takes to make a view read only, and the flutter screen hides its write actions
accordingly.

```dart
var viewer = explorer.readOnly;
await viewer.delete('config.json'); // throws ReadOnlyException
```

It goes all the way down: the object sources it hands out refuse writes, and
the databases it opens come back as read only repositories, so every screen
below it is a viewer too. Copying still works — reading includes taking a copy.
`ReadOnlyException` is the one the object editor throws as well, so a caller
handles a single exception whatever it is editing.

---

### 4. Documents

A json or yaml document opens as an `ObjectSource`, so the object editor edits
it — including the in place yaml save that keeps the comments:

```dart
var sourceEditor = ObjectSourceEditor(explorer.objectSource('settings.yaml'));
var editor = await sourceEditor.load();
editor.setValueAt(ObjectPath.root.field('count'), 2);
await sourceEditor.save();
```

---

### 5. Databases

`databaseKind` tells a sembast database from an sdb one by what the file
itself holds: an sdb database is a sembast file whose main store carries the
indexeddb schema, under `stores`.

`openDatabase` opens it and gives back the `ObjectRepository` the object
explorer browses. **The caller closes it:**

```dart
var database = await explorer.openDatabase('data.db');
try {
  for (var collection in await database.repository.listCollections()) {
    print('${collection.name}: ${await collection.listIds()}');
  }
} finally {
  await database.close();
}
```

This works in memory and in a browser, not only on the disk, because of the
next piece.

---

### 6. sembast over `fs_shim`

sembast ports itself through its own small `FileSystem` seam — the one
`DatabaseFactoryIo` and the web factory are built on — but ships no `fs_shim`
implementation of it. `sembast_fs_shim.dart` is that implementation:

```dart
var factory = getDatabaseFactoryFsShim(newFileSystemMemory());
var db = await factory.openDatabase('my.db');     // a file of that file system
var sdbFactory = getSdbFactoryFsShim(fileSystem); // sdb is idb_shim over it
```

It is what makes a database file *inside* an `fs_shim` file system openable at
all, which is the whole point of a file explorer that can open databases. The
compaction path — the tmp file plus the rename — is covered by a test, since
that is where a file system adapter usually breaks.

It imports sembast's `src/file_system.dart` and `src/sembast_fs.dart`. Those
are sembast's porting seam rather than incidental internals, but the file
carries a `implementation_imports` ignore and is the one place to fix if
sembast ever publishes them.

---

### 7. Flutter

```dart
await goToFileSystemExplorerScreen(
  context,
  explorer: FileSystemExplorer(fileSystem: fileSystemIo, rootPath: '.local'),
);
```

A row per entry with its icon and size. Tapping one opens what fits it: a
directory lists in turn, a json or yaml document opens in `ObjectEditorScreen`,
a database opens in `ObjectExplorerScreen` (and closes when that screen is
popped), a text file opens in `FileSystemTextFileScreen`.

When the explorer is writable, a `+` button creates a folder or a json, yaml or
text file, and each row has a rename and a delete. When it is not, all of that
is gone and a padlock shows in the app bar.

A json or yaml row also copies and pastes its whole content, through the same
clipboard the object editor uses — so a document copies into a database record
and back, see [the object editor](object_editor.md).

---

### 8. Picking the directory, and the debug menu

`FileSystemRootPickerScreen` picks what the explorer opens on, among the
directories `path_provider` names — documents, support, temporary, downloads,
external storage — plus the current one and a scratch memory file system. A
root the platform has none of is left out rather than shown broken.

The picked directory is **sandboxed**: `festenaoDirectoryExplorer` wraps it with
`fs_shim`'s `sandbox`, so the explorer's paths are rooted there and `..` leads
nowhere. The screen also carries the read only switch, so a directory can be
browsed as a viewer.

One line adds it to the debug menu of an app:

```dart
muiBodyWidget(() {
  festenaoFileSystemExplorerMenuItem(packageName: 'com.example.my_app');
});
```

`festenao_dashboard_base_app` groups that with whatever else every dashboard
app gets, in `dashboardDebugMenuContent()` and the ready made
`DashboardDebugScreen`.
