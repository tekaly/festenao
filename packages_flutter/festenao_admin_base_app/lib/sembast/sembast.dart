import 'package:sembast/timestamp.dart' show Timestamp;
import 'package:tekartik_app_flutter_sembast/sembast.dart';
import 'package:tkcms_common/tkcms_common.dart';

export 'package:sembast/sembast.dart';
export 'package:tekartik_app_sembast_firestore_type_adapters/type_adapters.dart';

/// Sembast timestamp
typedef DbTimestamp = Timestamp;

/// Sembast transaction
typedef DbTransaction = Transaction;

/// Global sembast database factory
late final DatabaseFactory globalSembastDatabaseFactory;

/// Initialize the local sembast factory
Future<void> initLocalSembastFactory() async {
  globalSembastDatabaseFactory =
      getDatabaseFactory(rootPath: join('.dart_tool', 'festenao_local'));
}
