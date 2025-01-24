import 'package:path/path.dart';

String _userAccessPath = 'user_access'; // root
String getUsersAccessPath() => _userAccessPath;

String _infoPath = 'info';
String getInfosPath() => _infoPath;
String getUserAccessPath(String userId) =>
    url.join(getUsersAccessPath(), userId);
String _exportPath = 'export'; // root
String getExportsPath() => _exportPath;
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
