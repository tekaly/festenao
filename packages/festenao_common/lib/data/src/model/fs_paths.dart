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
