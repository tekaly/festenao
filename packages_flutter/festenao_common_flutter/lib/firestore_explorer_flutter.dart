/// Browsing and editing firestore with the object editor.
///
/// A [FirestoreExplorerScreen] lists the collections of an instance, or the
/// ones under a document, and opens each document in the object editor — with
/// the firestore types, so a `timestamp` gets a date picker, a `blob` edits as
/// base64, a `geoPoint` as `latitude,longitude` and a `documentReference` as
/// its path.
///
/// It is the generic explorer on a `FirestoreObjectRepository`, so it comes
/// with what the others have: read only, copy and paste between documents,
/// records and files alike.
///
/// ```dart
/// await goToFirestoreExplorerScreen(context, firestore: firestore);
/// ```
///
/// This browses documents as they are. `tekaly_firestore_explorer` browses
/// them as the `cv` models an app declares, walking a `CvFirestoreDocument`
/// through its `CvField`s: use that one when the model is the truth, this one
/// when the raw document is. What the two could share one day is the mapping
/// registry (`documentViewAddCollections`), which is how a backend that cannot
/// list its collections learns their paths — [FirestoreExplorerScreen] takes
/// them as `collectionPaths` for now.
library;

export 'package:festenao_common/data/firestore_backup.dart';

export 'object_editor_flutter.dart';
export 'src/file_system_debug_menu.dart' show festenaoFirestoreExplorerMenuItem;
export 'src/firestore_backup_flutter.dart'
    show
        FirestoreBackupFormat,
        FirestoreBackupFormatExt,
        FirestoreBackupResult,
        promptFirestoreBackup,
        writeFirestoreBackup;
export 'src/firestore_demo.dart' show fillDemoFirestore;
export 'src/firestore_explorer_flutter.dart'
    show
        FirestoreExplorerScreen,
        goToFirestoreDocumentScreen,
        goToFirestoreExplorerScreen;
