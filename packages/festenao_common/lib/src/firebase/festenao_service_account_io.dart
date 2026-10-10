import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart';
import 'package:process_run/shell.dart';

import 'festenao_service_account.dart';

/// The variable holding the service account of an admin build or tool: its
/// json, or the path of a json file (`~/` allowed).
///
/// Read from the process environment first, then from the ds env user file
/// (`ds env var set`, `~/.config/tekartik/process_run/env.yaml` on linux), so
/// it works from a terminal, an IDE launch configuration or neither.
const festenaoServiceAccountEnvKey = 'FESTENAO_SERVICE_ACCOUNT';

/// The directory the service account files are written in, one
/// `<project_id>.json` per firebase project:
/// `~/.config/tekartik/festenao/service_accounts` on linux, next to the ds
/// env user file.
String festenaoServiceAccountDirPath() =>
    join(userAppDataPath, 'tekartik', 'festenao', 'service_accounts');

/// Where a service account was found.
enum FestenaoServiceAccountOrigin {
  /// The [festenaoServiceAccountEnvKey] variable.
  env,

  /// A file of the service account directory.
  file,
}

/// A service account found on this machine.
class FestenaoServiceAccount {
  /// Where it was found.
  final FestenaoServiceAccountOrigin origin;

  /// What the user is told it comes from, never the content.
  final String source;

  /// The service account, as its json reads.
  final Map<String, Object?> map;

  /// The file it was read from, null when the variable holds the json.
  final String? path;

  /// A service account read from [source].
  FestenaoServiceAccount({
    required this.origin,
    required this.source,
    required this.map,
    this.path,
  });

  /// The firebase project.
  String get projectId => map['project_id'] as String;

  /// The account, `firebase-adminsdk-xxx@<project>.iam.gserviceaccount.com`.
  String get clientEmail => map['client_email'] as String;

  /// The id of its key, which tells two keys of one account apart.
  String? get privateKeyId => map['private_key_id'] as String?;

  /// The json, indented as a service account file is.
  String get json => const JsonEncoder.withIndent('  ').convert(map);

  /// The project, the account and the source, never the key.
  @override
  String toString() => '$projectId $clientEmail ($source)';
}

/// The service accounts found, and why some could not be read.
class FestenaoServiceAccountsFound {
  /// The ones read, the variable one first.
  final List<FestenaoServiceAccount> accounts;

  /// What went wrong, one line each (a missing file, a json without key...).
  final List<String> errors;

  /// The accounts read and the errors met.
  FestenaoServiceAccountsFound({required this.accounts, required this.errors});

  /// The one of [festenaoServiceAccountEnvKey], null when it is not set.
  FestenaoServiceAccount? get fromEnv => accounts
      .where((account) => account.origin == FestenaoServiceAccountOrigin.env)
      .firstOrNull;
}

/// [path] with a leading `~` resolved to the home directory.
String festenaoExpandHomePath(String path) {
  if (path == '~') {
    return userHomePath;
  }
  if (path.startsWith('~/') || path.startsWith('~\\')) {
    return join(userHomePath, path.substring(2));
  }
  return path;
}

/// The value of [festenaoServiceAccountEnvKey] and where it was read, null
/// when it is not set.
///
/// [environment] replaces both the process environment and the ds env user
/// file, for tests.
({String value, String where})? festenaoServiceAccountEnvValue({
  Map<String, String>? environment,
}) {
  ({String value, String where})? valueOf(String? value, String where) =>
      (value == null || value.trim().isEmpty)
      ? null
      : (value: value.trim(), where: where);
  if (environment != null) {
    return valueOf(environment[festenaoServiceAccountEnvKey], 'environment');
  }
  return valueOf(
        Platform.environment[festenaoServiceAccountEnvKey],
        'environment',
      ) ??
      valueOf(userEnvironment[festenaoServiceAccountEnvKey], 'ds env');
}

/// Reads the service account file [path], throwing a [StateError] naming the
/// file when it is missing or not a usable service account.
Future<FestenaoServiceAccount> festenaoReadServiceAccountFile(
  String path, {
  FestenaoServiceAccountOrigin origin = FestenaoServiceAccountOrigin.file,
  String? source,
}) async {
  var file = File(festenaoExpandHomePath(path));
  if (!file.existsSync()) {
    throw StateError('${source ?? path}: no file ${file.path}');
  }
  var map = festenaoServiceAccountMapFromText(await file.readAsString());
  var error = festenaoServiceAccountMapError(map);
  if (error != null) {
    throw StateError('${source ?? path}: $error');
  }
  return FestenaoServiceAccount(
    origin: origin,
    source: source ?? file.path,
    map: map!,
    path: file.path,
  );
}

/// The service account of [festenaoServiceAccountEnvKey], null when it is not
/// set, a [StateError] when it does not read as one.
Future<FestenaoServiceAccount?> festenaoServiceAccountFromEnv({
  Map<String, String>? environment,
}) async {
  var envValue = festenaoServiceAccountEnvValue(environment: environment);
  if (envValue == null) {
    return null;
  }
  var source = '\$$festenaoServiceAccountEnvKey (${envValue.where})';
  var value = envValue.value;
  if (value.startsWith('{')) {
    var map = festenaoServiceAccountMapFromText(value);
    var error = festenaoServiceAccountMapError(map);
    if (error != null) {
      throw StateError('$source: $error');
    }
    return FestenaoServiceAccount(
      origin: FestenaoServiceAccountOrigin.env,
      source: source,
      map: map!,
    );
  }
  return festenaoReadServiceAccountFile(
    value,
    origin: FestenaoServiceAccountOrigin.env,
    source: '$source $value',
  );
}

/// The service account files of [dirPath] ([festenaoServiceAccountDirPath]
/// by default), by name; the ones that do not read are reported in [errors].
Future<List<FestenaoServiceAccount>> festenaoServiceAccountsFromDir({
  String? dirPath,
  List<String>? errors,
}) async {
  var dir = Directory(dirPath ?? festenaoServiceAccountDirPath());
  if (!dir.existsSync()) {
    return [];
  }
  var paths =
      (await dir.list().toList())
          .whereType<File>()
          .map((file) => file.path)
          .where((path) => extension(path) == '.json')
          .toList()
        ..sort();
  var accounts = <FestenaoServiceAccount>[];
  for (var path in paths) {
    try {
      accounts.add(await festenaoReadServiceAccountFile(path));
    } on StateError catch (e) {
      errors?.add(e.message);
    }
  }
  return accounts;
}

/// Every service account this machine holds: the one of
/// [festenaoServiceAccountEnvKey] first, then the files of [dirPath], a file
/// the variable already points to (or holding the same key) only once.
Future<FestenaoServiceAccountsFound> festenaoFindServiceAccounts({
  Map<String, String>? environment,
  String? dirPath,
}) async {
  var errors = <String>[];
  var accounts = <FestenaoServiceAccount>[];
  try {
    var fromEnv = await festenaoServiceAccountFromEnv(environment: environment);
    if (fromEnv != null) {
      accounts.add(fromEnv);
    }
  } on StateError catch (e) {
    errors.add(e.message);
  }
  var fromDir = await festenaoServiceAccountsFromDir(
    dirPath: dirPath,
    errors: errors,
  );
  for (var account in fromDir) {
    var known = accounts.any(
      (other) =>
          (other.path != null &&
              normalize(other.path!) == normalize(account.path!)) ||
          (other.clientEmail == account.clientEmail &&
              other.privateKeyId == account.privateKeyId),
    );
    if (!known) {
      accounts.add(account);
    }
  }
  return FestenaoServiceAccountsFound(accounts: accounts, errors: errors);
}

/// Writes the service account [map] as `<project_id>.json` in [dirPath]
/// ([festenaoServiceAccountDirPath] by default), readable by the user only
/// on posix, and answers its path.
///
/// Throws an [ArgumentError] when [map] is not a usable service account.
Future<String> festenaoWriteServiceAccountFile(
  Map map, {
  String? dirPath,
}) async {
  var error = festenaoServiceAccountMapError(map);
  if (error != null) {
    throw ArgumentError(error);
  }
  var dir = Directory(dirPath ?? festenaoServiceAccountDirPath());
  await dir.create(recursive: true);
  await _chmod('700', dir.path);
  var file = File(join(dir.path, '${map['project_id']}.json'));
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(map)}\n',
  );
  await _chmod('600', file.path);
  return file.path;
}

/// Deletes the service account file of [projectId] in [dirPath], answering
/// false when there was none.
Future<bool> festenaoDeleteServiceAccountFile(
  String projectId, {
  String? dirPath,
}) async {
  var file = File(
    join(dirPath ?? festenaoServiceAccountDirPath(), '$projectId.json'),
  );
  if (!file.existsSync()) {
    return false;
  }
  await file.delete();
  return true;
}

/// Sets [festenaoServiceAccountEnvKey] in the ds env user file to [value] (a
/// path or the json), as `ds env var set` does, deleting it when null.
///
/// The value is written quoted, so a json stays a string for the yaml file.
/// [environment] may name another user file
/// (`TEKARTIK_PROCESS_RUN_USER_ENV_FILE_PATH`), for tests. Nothing is printed:
/// the file holds other secrets.
Future<void> festenaoSetServiceAccountDsEnv(
  String? value, {
  Map<String, String>? environment,
}) async {
  var shell = Shell(verbose: false, environment: environment);
  await shell.shellVarOverride(
    festenaoServiceAccountEnvKey,
    value == null ? null : jsonEncode(value),
    local: false,
  );
}

Future<void> _chmod(String mode, String path) async {
  if (Platform.isWindows) {
    return;
  }
  try {
    await Process.run('chmod', [mode, path]);
  } catch (_) {
    // Best effort, the file is written anyway.
  }
}
