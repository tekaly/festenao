import 'package:tekaly_sembast_synced/synced_db_internals.dart';

var _debugFaoSync = false;
bool get debugFaoSync => _debugFaoSync;
@Deprecated('Debug Fao sync')
set debugFaoSync(bool debugFaoSync) => _debugFaoSync = debugFaoSync;

typedef FaoSyncStat = SyncedSyncStat;

typedef FaoSyncSourceRecord = SyncedSyncSourceRecord;

/// Get dirty record source
typedef FestenaoDbSourceSync = SyncedDbSourceSync;
