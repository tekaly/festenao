**Location:** Part of `festenao_common` (`lib/data/object_editor.dart`,
`lib/data/object_editor_io.dart`, implementation in `lib/src/data/model/`) and
`festenao_common_flutter` (`lib/object_editor_flutter.dart`, implementation in
`lib/src/object_editor/`).

**Goal**

One generic editor for any json-like object — a json or yaml file, a sembast or
sdb record, a firestore document, a `cv` model — with a console front end and a
flutter one, and with the custom types those backends hold (a timestamp, a
blob, a geo point, a document reference) edited as such rather than as opaque
values.

---

### 1. The pieces

| Concern | Type | Where |
|---|---|---|
| What a value may be | `ObjectValueTypeHandler`, `ObjectTypeRegistry` | `object_type.dart`, `object_type_registry.dart` |
| Where a value sits | `ObjectPath`, `ObjectNode` | `object_path.dart`, `object_node.dart` |
| The tree being edited | `ObjectEditor` | `object_editor.dart` |
| What was edited | `ObjectEditOperation` | `object_edit_operation.dart` |
| json / yaml text | `ObjectTextFormat`, `objectJsonFormat`, `objectYamlFormat` | `object_text_format.dart` |
| Where the object lives | `ObjectSource`, `ObjectCollection`, `ObjectRepository`, `ObjectSourceEditor` | `object_source.dart` |
| Copy and paste | `ObjectClipboard`, `ObjectClipboardData` | `object_clipboard.dart` |
| Backends | `FsObjectSource`, `SembastObjectSource`, `SdbObjectSource`, `FirestoreObjectSource`, `CvObjectSource` | `object_source_*.dart`, `object_cv.dart` |
| Console editor | `objectSourceConsoleEdit`, `objectFileConsoleEditorMain` | `io/object_console_editor.dart` |
| Flutter editor | `ObjectEditorView`, `ObjectEditorScreen`, `ObjectExplorerScreen` | `festenao_common_flutter` |

`lib/data/object_editor.dart` imports on the web. Everything io — the console
menu (`dev_build`) and `fileSystemIo` — is in `lib/data/object_editor_io.dart`.

---

### 2. Types

A registry answers three questions about a value: what it is (`typeOf`), how to
show and edit it (`format`, `toText`, `parseText`), and how it reaches json
(`encode`, `decode`).

The basic json types and the two containers are built in.
`defaultObjectTypeRegistry` adds `DateTime` and `Uint8List`. A backend swaps in
its own:

| Registry | Adds |
|---|---|
| `defaultObjectTypeRegistry` | `dateTime` (`DateTime`), `blob` (`Uint8List`) |
| `sembastObjectTypeRegistry` | `timestamp` (sembast `Timestamp`), `blob` (sembast `Blob`) |
| `sdbObjectTypeRegistry` | the same, sdb reusing the sembast types |
| `firestoreObjectTypeRegistry(firestore)` | `timestamp`, `blob`, `geoPoint`, `documentReference` |

sembast and sdb share one registry, sdb being `idb_shim` over sembast: one
`Timestamp`, one `Blob`, the same records either way.

A custom value reaches json as a one key map, the sembast V2 convention:

```json
{ "when": { "$timestamp": "2024-01-02T03:04:05.000Z" },
  "data": { "$blob": "AQID" } }
```

so a record exported to a file reads back where it came from. A map that
already looks like one of those is escaped, and a type the registry does not
know is left as it is rather than dropped.

**Declaring one** takes a key, a string representation and, when the
convention calls for it, a prefix:

```dart
var durationType = ObjectCustomTypeHandler(
  id: 'duration',                                   // the key, `$duration`
  label: 'Duration',
  matchesValue: (value) => value is Duration,
  newValueBuilder: () => Duration.zero,
  formatValue: (value) => '${(value as Duration).inMilliseconds}',
  parseValue: (text) => Duration(milliseconds: int.parse(text.trim())),
);

var registry = defaultObjectTypeRegistry.withHandlers([durationType]);
```

A `Duration` then reads `{"$duration": "1500"}` in json, edits as `1500` in the
editor, and copies into any other tree that knows the type. `prefix:` takes
another marker than `$` — `'@'` reads and writes the legacy sembast
convention, `{"@Timestamp": ...}` — and a registry decodes every prefix its
types declare.

Writing one out in full, when the text form is not the json form:

```dart
class DurationTypeHandler extends ObjectValueTypeHandler {
  const DurationTypeHandler();
  @override String get id => 'duration';
  @override String get label => 'Duration';
  @override bool matches(Object? value) => value is Duration;
  @override Object? get newValue => Duration.zero;
  @override String format(Object? value) => '$value';
  @override String toText(Object? value) =>
      '${(value as Duration).inMilliseconds}';
  @override Object? parseText(String text) =>
      Duration(milliseconds: int.parse(text.trim()));
  @override Object? encode(Object? value) => (value as Duration).inMilliseconds;
  @override Object? decode(Object? encoded) =>
      Duration(milliseconds: encoded as int);
}

var registry = defaultObjectTypeRegistry.withHandlers([
  const DurationTypeHandler(),
]);
```

---

### 3. Editing

```dart
var editor = ObjectEditor({'name': 'test', 'count': 1});
editor.setValueAt(ObjectPath.root.field('count'), 2);
editor.addField(ObjectPath.root, 'createdAt', typeId: 'dateTime');
editor.addItem(ObjectPath.root.field('tags'), value: 'new');
editor.renameField(ObjectPath.root.field('name'), 'title');
editor.removeAt(ObjectPath.root.field('old'));
```

The tree it was given is deep copied, so nothing changes under the caller until
the edits are written back. `onChanged` fires after each edit — what the
flutter view rebuilds on — and `operations` records them in order, which is
what lets a yaml file be saved in place.

---

### 4. Sources

An `ObjectSource` reads and writes one object; an `ObjectCollection` holds many
by id; an `ObjectRepository` holds collections. `ObjectSourceEditor` is the
load/save cycle both front ends drive.

```dart
var sourceEditor = ObjectSourceEditor(source);
var editor = await sourceEditor.load();
editor.setValueAt(ObjectPath.root.field('name'), 'new name');
await sourceEditor.save();
```

| Source | Collection | Repository |
|---|---|---|
| `FsObjectSource` (json/yaml file, `fs_shim`) | `FsObjectCollection` (a directory) | — |
| `SembastObjectSource` | `SembastObjectCollection` (a store) | `SembastObjectRepository` (non empty stores) |
| `SdbObjectSource` | `SdbObjectCollection` (a store) | `SdbObjectRepository` (the schema stores) |
| `FirestoreObjectSource` | `FirestoreObjectCollection` | `FirestoreObjectRepository` |
| `CvObjectSource` (a `CvModel`, edited as its map) | — | — |
| `MemoryObjectSource` (tests, demos) | — | — |

A file goes through `fs_shim`, so the same code edits a real file on io and an
in memory or indexeddb one on the web — which is how the file editor is tried
out in a browser:

```dart
var source = FsObjectSource(newFileSystemMemory().file('config.yaml'));
```

**yaml is saved in place.** The recorded operations are replayed on the
original text through `yaml_edit`, so the comments, the key order and the
layout of what was not touched survive a save. A path `yaml_edit` refuses falls
back to a full re-encode: the content is right, the layout is lost.

---

### 4b. Read only

Every source, collection and repository takes `isReadOnly`, and a read only one
refuses each write with a `ReadOnlyException` — the same exception whatever the
backend, so a caller handles one:

```dart
var source = SdbObjectSource(
  database: db, store: store, key: 'main', isReadOnly: true,
);
await source.read();            // fine
await source.write({'a': 1});   // throws ReadOnlyException
```

It goes down the tree: a read only `SembastObjectRepository` lists read only
collections, which hand out read only sources. The flutter editors follow it —
the value editors become plain text, the write actions disappear and a padlock
shows in the app bar — so handing out a read only repository is all it takes to
make a viewer.

Copying still works in a viewer: reading includes taking a copy.

---

### 4c. Copy and paste

`ObjectClipboard` carries one value — the whole tree, a field, a nested map, one
item of a list — between trees, backends and apps.

```dart
editor.copyAt(ObjectPath.root.field('items').item(2));
other.pasteAsItem(ObjectPath.root.field('archive'));
other.pasteAt(ObjectPath.root.field('current'));
other.pasteAsField(ObjectPath.root, 'restored');

await source.copy();            // a whole record, without opening it
await otherSource.paste();
await collection.paste();       // as a new record of a store
```

The value is held in its **json encodable** form, which is what makes it cross
backends: a timestamp copied out of a sembast record pastes into a firestore
document as a firestore timestamp, and into a json file as a `DateTime`. That
last one works because a handler declares the other names of its type:

```dart
@override
Set<String> get decodeAliases => const {'timestamp'};   // on objectTypeDateTime
```

so `{"$timestamp": ...}` and `{"$dateTime": ...}` read as each other.

In flutter, `FlutterObjectClipboard` mirrors it to the clipboard of the system:
copying puts the json text there, and pasting prefers what the system clipboard
holds when it reads as json — so a value also crosses apps.

---

### 5. Console editor

```sh
dart example/edit_json.dart my_file.json
dart example/edit_yaml.dart my_file.yaml
```

A `dev_build` console menu: `ls`, `print`, `cd`, `edit value`, `set type`,
`add field`, `add item`, `rename field`, `remove`, `edit as text`, `open in
$EDITOR`, `status`, `save`, `reload`. The file is created on the first save
when it does not exist yet.

Any source works, not only a file:

```dart
await objectSourceConsoleEdit(
  SdbObjectSource(database: db, store: store, key: 'main'),
);
```

and `objectSourceConsoleMenuContent(sourceEditor)` adds the same items to an
existing dev menu.

---

### 6. Flutter editor

`ObjectEditorView` is the record editor — a row per field with the key, an
editor fitting the type, and a menu to change the type, rename or remove it,
like the firestore console. `ObjectEditorScreen` wraps it with load, save and
reload; `ObjectExplorerScreen` browses a repository down to a record.

```dart
await goToObjectExplorerScreen(context, repository: SdbObjectRepository(db));
await goToObjectEditorScreen(context, source: source);
```

The root has a row of its own, so the whole tree is copied, pasted over and
retyped like any other value; every row offers `Copy`, and a writable one
`Paste here`, plus `Paste as a field` or `Paste as an item` on a container. The
app bar of `ObjectEditorScreen` copies and pastes the whole object, and
`ObjectCollectionScreen` copies a record without opening it and pastes one over
another or into a new one.

A type gets a richer widget through an `ObjectValueEditorRegistry`; anything
without one falls back to a text field parsed by the handler itself, which is
all most custom types need.

```dart
var editors = ObjectValueEditorRegistry(builders: {
  'color': (context, type, value, onChanged) => MyColorPicker(...),
});
```

---

### 7. cv

A `CvModel` is edited as the map it serializes to, so the editor stays generic:
a field the model does not declare is still editable, and a document that is
not a model at all is edited just the same. `cvObjectSchema(model)` gives the
declared fields, which the flutter view offers when adding one:

```dart
var settings = AppSettings()..name.v = 'test';
await goToObjectEditorScreen(
  context,
  source: CvObjectSource(settings),
  schema: cvObjectSchema(settings),
);
```

This complements `tekaly_firestore_explorer`, which edits a
`CvFirestoreDocument` strictly through its declared `CvField`s: use that one
when the model is the truth, this one when the raw document is.

---

### 8. Where this belongs

Nothing here depends on festenao or tkcms — it is incubating in
`festenao_common` and could move to a tekartik package as is, which is what
`app_sdb_ui` (an sdb explorer) and `firebase_ui_firestore` would need to reach
it.
