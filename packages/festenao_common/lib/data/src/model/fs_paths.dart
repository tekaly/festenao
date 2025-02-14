import 'package:path/path.dart';

String _userAccessPath = 'user_access'; // root
String getUsersAccessPath() => _userAccessPath;

String _infoPath = 'info';
//@Deprecated('do not use')
String getInfosPath() => _infoPath;
//@Deprecated('do not use') compat
String getUserAccessPath(String userId) =>
    url.join(getUsersAccessPath(), userId);
String _exportPath = 'export'; // root
//@Deprecated('do not use') compat
String getExportsPath() => _exportPath;
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
