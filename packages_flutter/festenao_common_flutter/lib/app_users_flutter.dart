/// The users of an app, for an admin: when each one was last seen, sorted,
/// filtered, searched by email, and their purge ([AppUsersScreen]).
///
/// ```dart
/// await goToAppUsersScreen(
///   context,
///   appUsers: TkCmsAppUsersApi(apiService: apiService),
/// );
/// ```
library;

export 'package:festenao_common/api/festenao_app_user.dart';

export 'src/app_users_screen.dart' show AppUsersScreen, goToAppUsersScreen;
