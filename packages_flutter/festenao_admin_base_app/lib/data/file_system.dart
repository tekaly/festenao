import 'package:fs_shim/fs.dart';

/// Global fs_shim content initialized in main
FileSystem get globalFs => globalFsOrNull!;

/// Global fs_shim content initialized in main (nullable)
FileSystem? globalFsOrNull;

/// Set global fs_shim content
set globalFs(FileSystem fs) => globalFsOrNull = fs;
