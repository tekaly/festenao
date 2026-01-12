import 'package:path/path.dart';

String _userAccessPath = 'user_access'; // root
/// Returns the root path for user access.
String getUsersAccessPath() => _userAccessPath;

String _infoPath = 'info';
//@Deprecated('do not use')
/// Returns the root path for info.
//@Deprecated('do not use')
String getInfosPath() => _infoPath;

/// Returns the user access path for a given [userId].
//@Deprecated('do not use') compat
String getUserAccessPath(String userId) =>
    url.join(getUsersAccessPath(), userId);
String _exportPath = 'export'; // root
/// Returns the root path for exports.
//@Deprecated('do not use') compat
String getExportsPath() => _exportPath;

/// Returns the export path for a given [exportId].
//@Deprecated('do not use') compat
String getExportPath(String exportId) => url.join(getExportsPath(), exportId);

/// Storage/Firestore path
const appPathPart = 'app';

/// Storage/Firestore path
const projectPathPart = 'project';

/// Firestore path
const firestoreExportPathPart = 'export';

/// Firestore path
const firestoreExportMetaPathPart = 'info';

/// Storage data/export path
const storageDataPathPart = 'data';

/// Storage/Firestore path
// const compatExportPathPart = 'data';
