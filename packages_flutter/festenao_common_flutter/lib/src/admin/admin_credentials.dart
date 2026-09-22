import 'dart:convert';

import 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

/// One set of admin credentials: a service account, and what it reaches.
///
/// The service account is kept as the json text it was pasted as, so nothing
/// of it is lost to a round trip through a model.
class AdminCredentials extends ScvStringRecordBase {
  /// What the list displays, the project id when it was left empty.
  final label = CvField<String>('label');

  /// The firebase project the service account belongs to.
  final projectId = CvField<String>('projectId');

  /// The service account json, as it was pasted.
  final serviceAccount = CvField<String>('serviceAccount');

  /// When it was last written.
  final updatedAt = CvField<SdbTimestamp>('updatedAt');

  @override
  CvFields get fields => [label, projectId, serviceAccount, updatedAt];

  /// What the list displays: the label, or the project id when there is none.
  String get displayName {
    var label = this.label.v;
    return (label == null || label.isEmpty)
        ? (projectId.v ?? 'unnamed')
        : label;
  }

  /// The service account as a map, null when the json does not read as one.
  Map<String, Object?>? get serviceAccountMap =>
      adminServiceAccountMap(serviceAccount.v);
}

/// The stored credentials.
final adminCredentialsStore = scvStringStoreFactory.store<AdminCredentials>(
  'credentials',
);

/// The credentials by project id.
final adminCredentialsProjectIdIndex = adminCredentialsStore.index<String>(
  'projectId',
);

/// What the admin app remembers between runs, the selected credentials among
/// it.
final adminSettingsStore = SdbStoreRef<String, SdbModel>('settings');

/// The key the selected credentials are remembered under.
const adminCurrentCredentialsKey = 'currentCredentialsId';

var _buildersInitialized = false;

/// Registers the admin models with `cv`, which needs to know how to build one
/// before it reads one back.
void initAdminCredentialsBuilders() {
  if (_buildersInitialized) {
    return;
  }
  _buildersInitialized = true;
  cvAddConstructor(AdminCredentials.new);
}

/// The schema of the admin database.
SdbDatabaseSchema adminCredentialsDatabaseSchema() => SdbDatabaseSchema(
  stores: [
    adminCredentialsStore.schema(
      indexes: [adminCredentialsProjectIdIndex.schema(keyPath: 'projectId')],
    ),
    adminSettingsStore.schema(),
  ],
);

/// The service account json [text] as a map, null when it is not one.
Map<String, Object?>? adminServiceAccountMap(String? text) {
  if (text == null || text.trim().isEmpty) {
    return null;
  }
  try {
    var decoded = jsonDecode(text);
    return decoded is Map ? decoded.cast<String, Object?>() : null;
  } catch (_) {
    return null;
  }
}

/// The `project_id` of the service account json [text], null when it has none.
String? adminServiceAccountProjectId(String? text) =>
    adminServiceAccountMap(text)?['project_id'] as String?;

/// What is wrong with the service account json [text], null when nothing is.
///
/// It checks the fields a service account is unusable without, so a typo is
/// caught when it is pasted rather than on the first request.
String? adminServiceAccountError(String? text) {
  if (text == null || text.trim().isEmpty) {
    return 'The service account json is empty';
  }
  var map = adminServiceAccountMap(text);
  if (map == null) {
    return 'The service account is not a json object';
  }
  for (var key in ['project_id', 'client_email', 'private_key']) {
    var value = map[key];
    if (value is! String || value.isEmpty) {
      return 'The service account has no $key';
    }
  }
  return null;
}

/// The credentials the admin app holds, in an sdb database of its own.
///
/// It is a plain sdb database, so the explorer opens it like any other — which
/// is how the credentials are inspected when something looks wrong.
class AdminCredentialsDb {
  /// The database.
  final SdbDatabase database;

  /// Db on [database].
  AdminCredentialsDb(this.database);

  /// Opens the credentials database [name] of [factory].
  static Future<AdminCredentialsDb> open(
    SdbFactory factory, {
    String name = 'admin_credentials.db',
  }) async {
    initAdminCredentialsBuilders();
    var database = await factory.openDatabase(
      name,
      options: SdbOpenDatabaseOptions(
        version: 1,
        schema: adminCredentialsDatabaseSchema(),
      ),
    );
    return AdminCredentialsDb(database);
  }

  /// Every set of credentials, by label.
  Future<List<AdminCredentials>> list() async {
    var list = await adminCredentialsStore.findRecords(database);
    list.sort(
      (one, other) => one.displayName.toLowerCase().compareTo(
        other.displayName.toLowerCase(),
      ),
    );
    return list;
  }

  /// The credentials of id [id], null when there are none.
  Future<AdminCredentials?> get(String id) =>
      adminCredentialsStore.record(id).get(database);

  /// Adds a set of credentials, answering the id it took.
  Future<String> add({
    String? label,
    required String serviceAccount,
    String? projectId,
  }) async {
    var id = 'credentials_${DateTime.now().millisecondsSinceEpoch}';
    await put(
      id,
      label: label,
      serviceAccount: serviceAccount,
      projectId: projectId,
    );
    return id;
  }

  /// Writes the credentials of id [id], the project id read from the service
  /// account when none is given.
  Future<void> put(
    String id, {
    String? label,
    required String serviceAccount,
    String? projectId,
  }) async {
    var credentials = AdminCredentials()
      ..label.v = label ?? ''
      ..serviceAccount.v = serviceAccount
      ..projectId.v =
          projectId ?? adminServiceAccountProjectId(serviceAccount) ?? ''
      ..updatedAt.v = SdbTimestamp.now();
    await adminCredentialsStore.record(id).put(database, credentials);
  }

  /// Removes the credentials of id [id], and forgets them when they were the
  /// selected ones.
  Future<void> delete(String id) async {
    await adminCredentialsStore.record(id).delete(database);
    if (await currentId() == id) {
      await setCurrentId(null);
    }
  }

  /// The id of the selected credentials, null when none is.
  Future<String?> currentId() async {
    var record = await adminSettingsStore
        .record(adminCurrentCredentialsKey)
        .getValue(database);
    return record?['value'] as String?;
  }

  /// The selected credentials, null when none is or they are gone.
  Future<AdminCredentials?> current() async {
    var id = await currentId();
    return id == null ? null : get(id);
  }

  /// Selects the credentials of id [id], none when it is null.
  Future<void> setCurrentId(String? id) async {
    var record = adminSettingsStore.record(adminCurrentCredentialsKey);
    if (id == null) {
      await record.delete(database);
    } else {
      await record.put(database, {'value': id});
    }
  }

  /// Closes the database.
  Future<void> close() => database.close();
}
