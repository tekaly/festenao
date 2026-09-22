**Location:** `festenao_common_flutter`
(`lib/firestore_explorer_flutter.dart`, implementation in
`lib/src/firestore_explorer_flutter.dart`), on the firestore sources of
`festenao_common` (`lib/data/object_editor.dart`).

**Goal**

Browse and edit firestore with the [object editor](object_editor.md), the
firestore types included.

---

### 1. The screen

```dart
await goToFirestoreExplorerScreen(context, firestore: firestore);
await goToFirestoreDocumentScreen(context, firestore: firestore, path: 'users/1');
```

It lists the collections of an instance — or the ones under a document, with
`documentPath` — and opens each document in the object editor. Being the
generic explorer on a `FirestoreObjectRepository`, it comes with what the
others have: read only, and copy and paste between documents, records and
files alike.

Listing the collections needs `FirestoreService.supportsListCollections`. A
backend that cannot list them (the rest api, a client sdk) shows the paths
given as `collectionPaths`, and the screen offers to name one by hand or to
open a document straight by its path.

One line adds it to a debug menu:

```dart
muiBodyWidget(() {
  festenaoFirestoreExplorerMenuItem(firestore: myFirestore);
});
```

---

### 2. The types

`firestoreObjectTypeRegistry(firestore)` is what a document is edited with:

| Type | In the editor | In json |
|---|---|---|
| `Timestamp` | a text field plus a date picker | `{"$timestamp": "2024-01-02T03:04:05.000Z"}` |
| `Blob` | base64 | `{"$blob": "AQIDBA=="}` |
| `GeoPoint` | `latitude,longitude` | `{"$geoPoint": {"latitude": …, "longitude": …}}` |
| `DocumentReference` | its path | `{"$documentReference": "users/1"}` |

A new reference starts on `firestoreNewReferencePath` rather than null, there
being no empty reference to edit.

Because the json form is shared, a value **crosses backends**: a timestamp
copied out of a firestore document pastes into a sembast record as a sembast
`Timestamp` and into a json file as a `DateTime`, see the copy and paste
section of [the object editor](object_editor.md).

---

### 3. And `tekaly_firestore_explorer`

`tekaly_firestore_explorer` browses documents as the **`cv` models an app
declares**, walking a `CvFirestoreDocument` through its `CvField`s; every value
is edited as text, and a field the model does not declare is invisible.

This one browses documents **as they are**, with the types they hold and no
schema needed.

Use the first when the model is the truth, this one when the raw document is.
What the two could share one day is the mapping registry
(`documentViewAddCollections`, `documentViewAddDocuments`), which is how a
backend that cannot list its collections learns their paths —
`FirestoreExplorerScreen` takes them as `collectionPaths` for now.
