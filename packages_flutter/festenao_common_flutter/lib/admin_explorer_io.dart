/// The io side of an admin build (linux, macos, windows): the service accounts
/// this machine holds, and firebase through the admin sdk.
///
/// [adminCredentialsImportFound] copies the service account of
/// `FESTENAO_SERVICE_ACCOUNT` (the json or a file path, from the environment
/// or the ds env user file) and the files of
/// `~/.config/tekartik/festenao/service_accounts` into the credentials
/// database, so they show with the pasted ones; the `festenao_service_account`
/// command of `festenao_support` writes them.
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
        festenaoServiceAccountEnvKey;
export 'package:festenao_common/firebase/firebase_admin_sdk.dart'
    show festenaoAdminFirebaseAdminSdk;

/// The id the credentials of `FESTENAO_SERVICE_ACCOUNT` are kept under.
const adminCredentialsEnvId = 'found_env';

/// The id the project of `FESTENAO_GCLOUD_PROJECT` is kept under.
const adminCredentialsGcloudEnvId = 'found_gcloud_env';

/// The id the credentials of the service account file of [projectId] are kept
/// under.
String adminCredentialsFileId(String projectId) => 'found_file_$projectId';

/// Copies the service accounts found on this machine
/// ([festenaoFindServiceAccounts]) into [credentialsDb], answering what was
/// found (and what could not be read).
///
/// Each source has an id of its own, rewritten on every call: the variable
/// ([adminCredentialsEnvId]), each file ([adminCredentialsFileId]) and the
/// gcloud project ([adminCredentialsGcloudEnvId]). The gcloud project is
/// selected when it is set (what a launcher passes), else the variable when it
/// is set, else the first one found when nothing is selected yet; the copies
/// stay in the database (unencrypted, it is a local build) until deleted
/// there.
///
/// [environment] and [dirPath] replace the variables and the directory, for
/// tests.
Future<FestenaoServiceAccountsFound> adminCredentialsImportFound(
  AdminCredentialsDb credentialsDb, {
  Map<String, String>? environment,
  String? dirPath,
}) async {
  var found = await festenaoFindServiceAccounts(
    environment: environment,
    dirPath: dirPath,
  );
  String? firstId;
  for (var account in found.accounts) {
    var isEnv = account.origin == FestenaoServiceAccountOrigin.env;
    var id = isEnv
        ? adminCredentialsEnvId
        : adminCredentialsFileId(account.projectId);
    firstId ??= id;
    await credentialsDb.put(
      id,
      label: isEnv
          ? '${account.projectId} (\$$festenaoServiceAccountEnvKey)'
          : '${account.projectId} (file)',
      serviceAccount: account.json,
    );
  }
  var gcloudProjectId = found.gcloudProjectId;
  if (gcloudProjectId != null) {
    await credentialsDb.putGcloud(
      adminCredentialsGcloudEnvId,
      label: '$gcloudProjectId (\$$festenaoGcloudProjectEnvKey)',
      projectId: gcloudProjectId,
    );
    await credentialsDb.setCurrentId(adminCredentialsGcloudEnvId);
  } else if (found.fromEnv != null) {
    await credentialsDb.setCurrentId(adminCredentialsEnvId);
  } else if (firstId != null && await credentialsDb.current() == null) {
    await credentialsDb.setCurrentId(firstId);
  }
  return found;
}
