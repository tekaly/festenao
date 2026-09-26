/// App wide user access: who is an admin of an app
/// (`app/<appId>/user_access/<userId>`, the tkcms `TkCmsFsUserAccess`).
///
/// A [FestenaoAppUserAccessScreen] lists the users having an access to an
/// app, makes them admin or not, removes their access and adds one (by email
/// with an admin auth, by user id otherwise; the account must exist). For an
/// admin tool: it writes the documents directly (admin sdk, local backend).
///
/// ```dart
/// await goToFestenaoAppUserAccessScreen(
///   context,
///   firestore: firestore,
///   appId: 'my_app-dev',
///   auth: auth,
/// );
/// ```
library;

export 'src/app_user_access_flutter.dart'
    show
        FestenaoAppUserAccessScreen,
        festenaoAppUserAccessCollection,
        goToFestenaoAppUserAccessScreen;
