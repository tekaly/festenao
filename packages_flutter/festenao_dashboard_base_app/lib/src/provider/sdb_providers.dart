// web
// mobile/desktop
import 'package:flutter/foundation.dart';
import 'package:idb_sqflite/sdb_sqflite.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:tekartik_app_flutter_fs/fs.dart';

import 'fs_providers.dart';

part 'sdb_providers.g.dart';

// 1. Define a scoped factory provider
@riverpod
SdbFactory sdbFactory(Ref ref) {
  try {
    final fileSystem = ref.watch(fsProvider).value;
    if (fileSystem != null) {
      return (kIsWeb ? sdbFactoryWeb : sdbFactorySqflite).sandbox(
        path: fileSystem.unsandbox().path,
      );
    }
  } catch (_) {}
  return sdbFactoryMemory;
}
