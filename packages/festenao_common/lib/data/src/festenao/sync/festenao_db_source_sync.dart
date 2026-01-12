import 'package:tekaly_sembast_synced/synced_db_internals.dart';

var _debugFaoSync = false;

/// Debug Fao sync.
bool get debugFaoSync => _debugFaoSync;

/// Debug Fao sync.
@Deprecated('Debug Fao sync')
set debugFaoSync(bool debugFaoSync) => _debugFaoSync = debugFaoSync;

/// Synchronized sync statistics.
typedef FaoSyncStat = SyncedSyncStat;

/// Synchronized sync source record.
typedef FaoSyncSourceRecord = SyncedSyncSourceRecord;

/// Get dirty record source
typedef FestenaoDbSourceSync = SyncedDbSourceSync;
