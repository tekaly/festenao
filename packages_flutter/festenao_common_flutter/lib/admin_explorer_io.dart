/// The io side of an admin build (linux, macos, windows): the service accounts
/// this machine holds, and firebase through the admin sdk.
///
/// [adminCredentialsImportFound] copies the service account of
/// `.local/service_account_enc.json` in the directory the app was started
/// from (the obfuscated json a support tool of a project writes, see
/// `festenaoWriteServiceAccountEncFile`), the one of
/// `FESTENAO_SERVICE_ACCOUNT` (the json or a file path, from the environment
/// or the ds env user file) and the files of
/// `~/.config/tekartik/festenao/service_accounts` into the credentials
/// database, so they show with the pasted ones and stay for the next runs;
/// the `festenao_service_account` command of `festenao_support` writes the
/// files. The local one is selected when there is one: `cd` into the folder
/// of a project and start the app (`festenaodash`) to manage that project.
///
/// `FESTENAO_GCLOUD_PROJECT` names a project reached as the gcloud user
/// instead (`gcloud auth application-default login`), no service account
/// needed: it is copied too, and selected.
///
/// ```dart
/// var credentialsDb = await AdminCredentialsDb.open(sdbFactory);
/// var found = await adminCredentialsImportFound(credentialsDb);
/// await goToAdminExplorerScreen(
///   context,
///   credentialsDb: credentialsDb,
///   firebase: festenaoAdminFirebaseAdminSdk,
/// );
/// ```
library;

import 'package:festenao_common/firebase/festenao_service_account_io.dart';

import 'src/admin/admin_credentials.dart';

export 'package:festenao_common/firebase/festenao_service_account_io.dart'
    show
        FestenaoServiceAccount,
        FestenaoServiceAccountOrigin,
        FestenaoServiceAccountsFound,
        festenaoApplicationDefaultCredentialsPath,
        festenaoGcloudProjectEnvKey,
        festenaoServiceAccountDirPath,
        festenaoServiceAccountEnvKey,
        festenaoServiceAccountLocalEncPath;
export 'package:festenao_common/firebase/firebase_admin_sdk.dart'
    show festenaoAdminFirebaseAdminSdk;

/// The id the credentials of `FESTENAO_SERVICE_ACCOUNT` are kept under.
const adminCredentialsEnvId = 'found_env';

/// The id the project of `FESTENAO_GCLOUD_PROJECT` is kept under.
const adminCredentialsGcloudEnvId = 'found_gcloud_env';

/// The id the credentials of the service account file of [projectId] are kept
/// under.
String adminCredentialsFileId(String projectId) => 'found_file_$projectId';

/// The id the credentials of the `.local/service_account_enc.json` file of
/// [projectId] (in the directory the app was started from) are kept under:
/// one per project, so the account of every folder the app was started from
/// stays available.
String adminCredentialsLocalId(String projectId) => 'found_local_$projectId';

/// Copies the service accounts found on this machine
/// ([festenaoFindServiceAccounts]) into [credentialsDb], answering what was
/// found (and what could not be read).
///
/// Each source has an id of its own, rewritten on every call: the local file
/// of its project ([adminCredentialsLocalId]), the variable
/// ([adminCredentialsEnvId]), each file ([adminCredentialsFileId]) and the
/// gcloud project ([adminCredentialsGcloudEnvId]). The local file is
/// selected when there is one (the project of the folder the app was started
/// from), else the gcloud project when it is set (what a launcher passes),
/// else the variable when it is set, else the first one found when nothing is
/// selected yet; the copies stay in the database (unencrypted, it is a local
/// build) until deleted there.
///
/// [environment], [dirPath] and [localPath] replace the variables, the
/// directory and the local file, for tests.
Future<FestenaoServiceAccountsFound> adminCredentialsImportFound(
  AdminCredentialsDb credentialsDb, {
  Map<String, String>? environment,
  String? dirPath,
  String? localPath,
}) async {
  var found = await festenaoFindServiceAccounts(
    environment: environment,
    dirPath: dirPath,
    localPath: localPath,
  );
  String? firstId;
  for (var account in found.accounts) {
    var projectId = account.projectId;
    var (id, label) = switch (account.origin) {
      FestenaoServiceAccountOrigin.local => (
        adminCredentialsLocalId(projectId),
        '$projectId ($festenaoServiceAccountLocalEncPath)',
      ),
      FestenaoServiceAccountOrigin.env => (
        adminCredentialsEnvId,
        '$projectId (\$$festenaoServiceAccountEnvKey)',
      ),
      FestenaoServiceAccountOrigin.file => (
        adminCredentialsFileId(projectId),
        '$projectId (file)',
      ),
    };
    firstId ??= id;
    await credentialsDb.put(id, label: label, serviceAccount: account.json);
  }
  var gcloudProjectId = found.gcloudProjectId;
  if (gcloudProjectId != null) {
    await credentialsDb.putGcloud(
      adminCredentialsGcloudEnvId,
      label: '$gcloudProjectId (\$$festenaoGcloudProjectEnvKey)',
      projectId: gcloudProjectId,
    );
  }
  if (found.fromLocal case var local?) {
    await credentialsDb.setCurrentId(adminCredentialsLocalId(local.projectId));
  } else if (gcloudProjectId != null) {
    await credentialsDb.setCurrentId(adminCredentialsGcloudEnvId);
  } else if (found.fromEnv != null) {
    await credentialsDb.setCurrentId(adminCredentialsEnvId);
  } else if (firstId != null && await credentialsDb.current() == null) {
    await credentialsDb.setCurrentId(firstId);
  }
  return found;
}
