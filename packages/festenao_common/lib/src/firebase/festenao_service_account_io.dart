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

/// The variable naming the firebase project an admin build reaches as the
/// gcloud user, through the application default credentials: only the
/// project id, no service account (`FESTENAO_GCLOUD_PROJECT=my-project`).
///
/// Read as [festenaoServiceAccountEnvKey] is: the process environment first,
/// then the ds env user file.
const festenaoGcloudProjectEnvKey = 'FESTENAO_GCLOUD_PROJECT';

/// The service account file an admin build or tool reads in the directory it
/// is started from: the obfuscated json ([festenaoServiceAccountEncMap],
/// written by [festenaoWriteServiceAccountEncFile]) of the project that
/// folder (a checkout) is about, git ignored.
///
/// Found first by [festenaoFindServiceAccounts], so that a `cd` into the
/// folder of a project and the admin command select its account.
const festenaoServiceAccountLocalEncPath = '.local/service_account_enc.json';

/// The application default credentials file the admin sdk reads: the one of
/// `GOOGLE_APPLICATION_CREDENTIALS`, or else the one
/// `gcloud auth application-default login` writes
/// (`~/.config/gcloud/application_default_credentials.json`, under
/// `%APPDATA%` on windows).
///
/// [environment] replaces the process environment, for tests.
String festenaoApplicationDefaultCredentialsPath({
  Map<String, String>? environment,
}) {
  var env = environment ?? Platform.environment;
  var fromEnv = env['GOOGLE_APPLICATION_CREDENTIALS'];
  if (fromEnv != null && fromEnv.isNotEmpty) {
    return fromEnv;
  }
  if (Platform.isWindows) {
    return join(
      env['APPDATA'] ?? userAppDataPath,
      'gcloud',
      'application_default_credentials.json',
    );
  }
  return join(
    env['HOME'] ?? userHomePath,
    '.config',
    'gcloud',
    'application_default_credentials.json',
  );
}

/// The directory the service account files are written in, one
/// `<project_id>.json` per firebase project:
/// `~/.config/tekartik/festenao/service_accounts` on linux, next to the ds
/// env user file.
String festenaoServiceAccountDirPath() =>
    join(userAppDataPath, 'tekartik', 'festenao', 'service_accounts');

/// Where a service account was found.
enum FestenaoServiceAccountOrigin {
  /// The [festenaoServiceAccountLocalEncPath] file of the current directory.
  local,

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

  /// The service account, as its json reads (decoded when the file or the
  /// variable held its obfuscated json).
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

  /// True when [other] is this account read elsewhere: the same file, or
  /// the same key of the same account.
  bool sameAs(FestenaoServiceAccount other) =>
      (path != null &&
          other.path != null &&
          normalize(path!) == normalize(other.path!)) ||
      (clientEmail == other.clientEmail && privateKeyId == other.privateKeyId);

  /// The project, the account and the source, never the key.
  @override
  String toString() => '$projectId $clientEmail ($source)';
}

/// The service accounts found, and why some could not be read.
class FestenaoServiceAccountsFound {
  /// The ones read: the local file one, then the variable one, then the
  /// files, each account once.
  final List<FestenaoServiceAccount> accounts;

  /// What went wrong, one line each (a missing file, a json without key...).
  final List<String> errors;

  /// The project of [festenaoGcloudProjectEnvKey], reached as the gcloud
  /// user; null when it is not set.
  final String? gcloudProjectId;

  /// The accounts read and the errors met.
  FestenaoServiceAccountsFound({
    required this.accounts,
    required this.errors,
    this.gcloudProjectId,
  });

  /// The one of [festenaoServiceAccountLocalEncPath] in the current
  /// directory, null when there is no such file.
  FestenaoServiceAccount? get fromLocal => accounts
      .where((account) => account.origin == FestenaoServiceAccountOrigin.local)
      .firstOrNull;

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
}) => _envValue(festenaoServiceAccountEnvKey, environment: environment);

/// The project of [festenaoGcloudProjectEnvKey], null when it is not set.
///
/// [environment] replaces both the process environment and the ds env user
/// file, for tests.
String? festenaoGcloudProjectFromEnv({Map<String, String>? environment}) =>
    _envValue(festenaoGcloudProjectEnvKey, environment: environment)?.value;

/// The value of the variable [key], from the process environment or else the
/// ds env user file, and where it was read; null when it is not set.
({String value, String where})? _envValue(
  String key, {
  Map<String, String>? environment,
}) {
  ({String value, String where})? valueOf(String? value, String where) =>
      (value == null || value.trim().isEmpty)
      ? null
      : (value: value.trim(), where: where);
  if (environment != null) {
    return valueOf(environment[key], 'environment');
  }
  return valueOf(Platform.environment[key], 'environment') ??
      valueOf(userEnvironment[key], 'ds env');
}

/// The service account of the json [text] read from [source], plain or
/// obfuscated ([festenaoServiceAccountMapDecode]); a [StateError] naming
/// [source] when it is not a usable one.
Map<String, Object?> _mapFromText(String text, String source) {
  Map<String, Object?>? map;
  try {
    map = festenaoServiceAccountMapDecode(
      festenaoServiceAccountMapFromText(text),
    );
  } on StateError catch (e) {
    throw StateError('$source: ${e.message}');
  }
  var error = festenaoServiceAccountMapError(map);
  if (error != null) {
    throw StateError('$source: $error');
  }
  return map!;
}

/// Reads the service account file [path], plain or obfuscated
/// ([festenaoServiceAccountEncMap]), throwing a [StateError] naming the
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
  var map = _mapFromText(await file.readAsString(), source ?? file.path);
  return FestenaoServiceAccount(
    origin: origin,
    source: source ?? file.path,
    map: map,
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
    return FestenaoServiceAccount(
      origin: FestenaoServiceAccountOrigin.env,
      source: source,
      map: _mapFromText(value, source),
    );
  }
  return festenaoReadServiceAccountFile(
    value,
    origin: FestenaoServiceAccountOrigin.env,
    source: '$source $value',
  );
}

/// The service account of the [festenaoServiceAccountLocalEncPath] file of
/// the current directory (its obfuscated json, or a plain one), null when
/// there is no such file, a [StateError] when it does not read as one.
///
/// [localPath] replaces the file, for tests.
Future<FestenaoServiceAccount?> festenaoServiceAccountFromLocal({
  String? localPath,
}) async {
  var file = File(localPath ?? festenaoServiceAccountLocalEncPath);
  if (!file.existsSync()) {
    return null;
  }
  var path = normalize(file.absolute.path);
  return festenaoReadServiceAccountFile(
    path,
    origin: FestenaoServiceAccountOrigin.local,
    source: path,
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

/// Every service account this machine holds, each once: the one of
/// [festenaoServiceAccountLocalEncPath] in the current directory first, then
/// the one of [festenaoServiceAccountEnvKey], then the files of [dirPath]; a
/// file already found (or holding the same key) is not listed again.
///
/// The project of [festenaoGcloudProjectEnvKey] comes along, an error said
/// when there are no application default credentials to reach it with.
///
/// [environment], [dirPath] and [localPath] replace the variables, the
/// directory and the local file, for tests.
Future<FestenaoServiceAccountsFound> festenaoFindServiceAccounts({
  Map<String, String>? environment,
  String? dirPath,
  String? localPath,
}) async {
  var errors = <String>[];
  var gcloudProjectId = festenaoGcloudProjectFromEnv(environment: environment);
  if (gcloudProjectId != null) {
    var path = festenaoApplicationDefaultCredentialsPath(
      environment: environment,
    );
    if (!File(path).existsSync()) {
      errors.add(
        '\$$festenaoGcloudProjectEnvKey $gcloudProjectId: no gcloud '
        'credentials at $path, run gcloud auth application-default login',
      );
    }
  }
  var accounts = <FestenaoServiceAccount>[];
  void add(FestenaoServiceAccount? account) {
    if (account != null && !accounts.any(account.sameAs)) {
      accounts.add(account);
    }
  }

  try {
    add(await festenaoServiceAccountFromLocal(localPath: localPath));
  } on StateError catch (e) {
    errors.add(e.message);
  }
  try {
    add(await festenaoServiceAccountFromEnv(environment: environment));
  } on StateError catch (e) {
    errors.add(e.message);
  }
  var fromDir = await festenaoServiceAccountsFromDir(
    dirPath: dirPath,
    errors: errors,
  );
  fromDir.forEach(add);
  return FestenaoServiceAccountsFound(
    accounts: accounts,
    errors: errors,
    gcloudProjectId: gcloudProjectId,
  );
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

/// Writes the obfuscated json of [serviceAccount]
/// ([festenaoServiceAccountEncMap], indented) to [path],
/// [festenaoServiceAccountLocalEncPath] of the current directory by default,
/// creating its folder; readable by the user only on posix. Answers the
/// absolute path.
///
/// What a support tool of a project calls with the service account it
/// embeds, so that `festenaodash` (the festenao admin build) started in that
/// folder manages the project:
///
/// ```dart
/// await festenaoWriteServiceAccountEncFile(myProjectServiceAccountMap);
/// ```
///
/// Throws an [ArgumentError] when [serviceAccount] is not a usable service
/// account.
Future<String> festenaoWriteServiceAccountEncFile(
  Map serviceAccount, {
  String path = festenaoServiceAccountLocalEncPath,
  String? password,
}) async {
  var encMap = festenaoServiceAccountEncMap(serviceAccount, password: password);
  var file = File(path);
  await file.parent.create(recursive: true);
  await file.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(encMap)}\n',
  );
  await _chmod('600', file.path);
  return normalize(file.absolute.path);
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
/// process_run (>= 1.4.0) quotes the value when needed, so a json stays a
/// string for the yaml file.
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
    value,
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
