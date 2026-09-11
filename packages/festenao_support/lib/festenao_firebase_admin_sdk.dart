/// Firebase initialisation through the admin sdk, for the dev tools.
///
/// The admin sdk talks to the real project with full privileges — it reads the
/// auth users (which the rest api cannot) and bypasses the firestore rules —
/// so this is what the support tools use, never an app.
library;

export 'src/firebase_admin_sdk.dart'
    show
        festenaoInitFirebaseAdminSdk,
        festenaoInitFirebaseAdminSdkWithServiceAccount;
