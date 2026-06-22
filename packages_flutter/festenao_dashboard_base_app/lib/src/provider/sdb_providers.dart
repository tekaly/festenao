// web
// mobile/desktop
import 'package:idb_shim/sdb.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'sdb_providers.g.dart';

// 1. Define a scoped factory provider (throws by default — must be overridden)
@riverpod
SdbFactory sdbFactory(Ref ref) {
  return sdbFactoryMemory;
}
