import 'package:flutter/foundation.dart';
import 'package:idb_shim/sdb.dart';

import 'client.dart';

final _clientsStore = SdbStoreRef<String, SdbModel>('clients');
final _settingsStore = SdbStoreRef<String, SdbModel>('settings');
const _currentClientKey = 'current_client';
const _fieldName = 'name';
const _fieldSecretKey = 'secretKey';
const _fieldCreated = 'created';
const _fieldClientId = 'clientId';

/// The clients of the manager: the [builtInClients] given by the app (not
/// stored, not deletable) and the ones added by the user, kept on the
/// device in a sdb database, plus the current one.
///
/// Call [ready] before reading [clients] and [current], [close] when done.
class StripeManagerClientStore {
  /// The factory of the database (IndexedDB on the web).
  final SdbFactory factory;

  /// The database name.
  final String dbName;

  /// The clients of the app (debug keys).
  final List<StripeManagerClient> builtInClients;

  /// Every client, the built-in ones first.
  final clients = ValueNotifier<List<StripeManagerClient>>(const []);

  /// The current client, null until one is chosen.
  final current = ValueNotifier<StripeManagerClient?>(null);

  /// A store in [dbName] of [factory].
  StripeManagerClientStore({
    required this.factory,
    this.dbName = 'stripe_manager.db',
    this.builtInClients = const [],
  });

  Future<SdbDatabase>? _dbFuture;
  Future<void>? _readyFuture;

  Future<SdbDatabase> get _db => _dbFuture ??= factory.openDatabase(
    dbName,
    options: SdbOpenDatabaseOptions(
      version: 1,
      schema: SdbDatabaseSchema(
        stores: [_clientsStore.schema(), _settingsStore.schema()],
      ),
    ),
  );

  /// Loads the clients and the current one (once).
  Future<void> ready() => _readyFuture ??= _load();

  Future<void> _load() async {
    var db = await _db;
    await _reloadClients(db);
    var currentId = (await _settingsStore
        .record(_currentClientKey)
        .getValue(db))?[_fieldClientId];
    var list = clients.value;
    StripeManagerClient? client;
    if (currentId is String) {
      client = list.where((client) => client.id == currentId).firstOrNull;
    }
    // Never start on a live key unless it was the one chosen.
    current.value = client ?? list.where((c) => !c.isLive).firstOrNull;
  }

  Future<void> _reloadClients(SdbDatabase db) async {
    var records = await _clientsStore.findRecords(db);
    var userClients = [
      for (var record in records)
        if (record.value[_fieldSecretKey] case String secretKey)
          (
            created: (record.value[_fieldCreated] as int?) ?? 0,
            client: StripeManagerClient(
              id: record.key,
              name: (record.value[_fieldName] as String?) ?? record.key,
              secretKey: secretKey,
            ),
          ),
    ]..sort((a, b) => a.created.compareTo(b.created));
    clients.value = List.unmodifiable([
      ...builtInClients,
      ...userClients.map((entry) => entry.client),
    ]);
  }

  /// Adds a client [name] of [secretKey] (checked with
  /// [stripeManagerKeyError], [ArgumentError] otherwise).
  Future<StripeManagerClient> addClient({
    required String name,
    required String secretKey,
  }) async {
    await ready();
    secretKey = secretKey.trim();
    var error = stripeManagerKeyError(secretKey);
    if (error != null) {
      throw ArgumentError(error);
    }
    var now = DateTime.now().microsecondsSinceEpoch;
    var id = 'user_$now';
    var db = await _db;
    await _clientsStore.record(id).put(db, {
      _fieldName: name.trim().isEmpty ? stripeManagerKeyHint(secretKey) : name,
      _fieldSecretKey: secretKey,
      _fieldCreated: now,
    });
    await _reloadClients(db);
    return clients.value.firstWhere((client) => client.id == id);
  }

  /// Deletes the user client [id] ([StateError] for a built-in one); the
  /// current one becomes none when it is the one deleted.
  Future<void> deleteClient(String id) async {
    await ready();
    if (builtInClients.any((client) => client.id == id)) {
      throw StateError('A built-in client cannot be deleted');
    }
    var db = await _db;
    await _clientsStore.record(id).delete(db);
    await _reloadClients(db);
    if (current.value?.id == id) {
      await selectClient(null);
    }
  }

  /// Makes [id] the current client (none when null).
  Future<void> selectClient(String? id) async {
    await ready();
    var client = id == null
        ? null
        : clients.value.where((client) => client.id == id).firstOrNull;
    if (id != null && client == null) {
      throw ArgumentError.value(id, 'id', 'Unknown client');
    }
    var db = await _db;
    if (client == null) {
      await _settingsStore.record(_currentClientKey).delete(db);
    } else {
      await _settingsStore.record(_currentClientKey).put(db, {
        _fieldClientId: client.id,
      });
    }
    current.value = client;
  }

  /// Closes the database.
  Future<void> close() async {
    var dbFuture = _dbFuture;
    _dbFuture = null;
    if (dbFuture != null) {
      await (await dbFuture).close();
    }
  }
}
