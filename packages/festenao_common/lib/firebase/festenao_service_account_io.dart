/// The service account of an admin build or tool, found on this machine
/// (io only, not for the web).
///
/// It is looked for in the [festenaoServiceAccountLocalEncPath] file of the
/// current directory (`.local/service_account_enc.json`, the obfuscated json
/// a support tool writes with [festenaoWriteServiceAccountEncFile]), in the
/// [festenaoServiceAccountEnvKey] variable (the json, or a file path), read
/// from the process environment then from the ds env user file, and in the
/// files of [festenaoServiceAccountDirPath]
/// (`~/.config/tekartik/festenao/service_accounts/<project_id>.json` on
/// linux). The `festenao_service_account` command of `festenao_support`
/// writes the latter.
///
/// ```dart
/// var account = await festenaoServiceAccountFromEnv();
/// if (account != null) {
///   var context = await festenaoInitFirebaseAdminSdkWithServiceAccount(
///     serviceAccountMap: account.map,
///   );
/// }
/// ```
library;

export '../src/firebase/festenao_service_account.dart'
    show
        festenaoServiceAccountEncMap,
        festenaoServiceAccountEncType,
        festenaoServiceAccountMapDecode,
        festenaoServiceAccountMapError,
        festenaoServiceAccountMapFromEncMap,
        festenaoServiceAccountMapFromText,
        festenaoServiceAccountMapIsEnc,
        festenaoServiceAccountTextError;
export '../src/firebase/festenao_service_account_io.dart'
    show
        FestenaoServiceAccount,
        FestenaoServiceAccountOrigin,
        FestenaoServiceAccountsFound,
        festenaoApplicationDefaultCredentialsPath,
        festenaoDeleteServiceAccountFile,
        festenaoExpandHomePath,
        festenaoFindServiceAccounts,
        festenaoGcloudProjectEnvKey,
        festenaoGcloudProjectFromEnv,
        festenaoReadServiceAccountFile,
        festenaoServiceAccountDirPath,
        festenaoServiceAccountEnvKey,
        festenaoServiceAccountEnvValue,
        festenaoServiceAccountFromEnv,
        festenaoServiceAccountFromLocal,
        festenaoServiceAccountLocalEncPath,
        festenaoServiceAccountsFromDir,
        festenaoSetServiceAccountDsEnv,
        festenaoWriteServiceAccountEncFile,
        festenaoWriteServiceAccountFile;
