/// Browsing the users of a firebase auth.
///
/// A [FirebaseUsersExplorerScreen] lists the users of a `FirebaseAuth` page by
/// page, finds one by uid or email, and shows every field its backend reports
/// ([FirebaseUserScreen]). An admin auth — the admin sdk, the local sdb one —
/// also creates and deletes users.
///
/// What it reaches depends on the backend, see `FirebaseUsersExplorer`: an
/// auth that cannot list its users (`supportsListUsers` false) only finds
/// them.
///
/// ```dart
/// await goToFirebaseUsersExplorerScreen(context, auth: auth);
/// ```
library;

export 'package:festenao_common/firebase/firebase_users_explorer.dart';

export 'src/file_system_debug_menu.dart'
    show festenaoFirebaseUsersExplorerMenuItem;
export 'src/firebase_users_explorer_flutter.dart'
    show
        FirebaseUserCreateDialog,
        FirebaseUserScreen,
        FirebaseUsersExplorerScreen,
        confirmFirebaseUserDelete,
        firebaseUserEntryChips,
        firebaseUserEntryIcon,
        goToFirebaseUserScreen,
        goToFirebaseUsersExplorerScreen;
