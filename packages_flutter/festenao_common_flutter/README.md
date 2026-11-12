# festenao_common_flutter

The Flutter side of `festenao_common`: the shared widgets and screens of the
festenao apps and their admin builds.

| Library | What |
| --- | --- |
| `common_utils.dart`, `common_utils_flutter.dart`, `common_utils_widget.dart` | barrels of the tekartik utilities an app uses (one import instead of ten) |
| `festenao_flavor.dart`, `share_link.dart`, `dev_menu_flutter.dart` | the build flavor, a share link dialog, the in app test menu |
| `file_system_explorer_flutter.dart` | browse a file system (`fs_shim`, io or web) and open its json, yaml, protobuf, sembast and sdb files |
| `object_editor_flutter.dart`, `firestore_explorer_flutter.dart`, `pb_explorer_flutter.dart` | a record editor like the firestore console one, a firestore explorer, a protobuf viewer |
| `firebase_users_explorer_flutter.dart`, `app_users_flutter.dart`, `app_user_access_flutter.dart` | the users of an auth, the users of an app (last seen, purge), its admins |
| `admin_explorer_flutter.dart`, `admin_explorer_io.dart` | an admin build: every explorer behind service account credentials (io: desktop) |
| `app_status_flutter.dart` | `FestenaoAppStatusGate`: read only and maintenance screens around the navigator |
| `festenao_slug_flutter.dart` | `FestenaoSlugField`, a project url edited and checked against the registry |
| `festenao_quizz_flutter.dart` | the quiz widgets (progress, control bar, podium, validation) |
| `log/log.dart` | the log viewer and playground of `FestenaoLogger` |

## Getting started

Not on pub.dev, a git dependency:

```yaml
dependencies:
  festenao_common_flutter:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_common_flutter
```

Browse a file system (an in memory one here) with the explorer:

```dart
import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:fs_shim/fs_memory.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  var explorer = FileSystemExplorer(
    fileSystem: newFileSystemMemory(),
    rootPath: '/data',
  );
  runApp(MaterialApp(home: FileSystemExplorerScreen(explorer: explorer)));
}
```

Platforms: Android, iOS, the web, macOS, Linux and Windows, except
`admin_explorer_io.dart` (`dart:io`: desktop admin builds).

## What to know

- Explorer and app databases: given the app's own sembast/sdb factory
  (`FileSystemExplorer(sembastDatabaseFactory:, sdbFactory:)`), listing or
  opening a database closes the instance the app has open; keep the default
  factories (a second handle) unless the app closed its databases first.
- The quiz widgets listen to firestore: give them the same database and quiz
  id from build to build (a new one opens new listeners).
- The app status gate keeps the app mounted in read only; in maintenance
  the app below is disposed and starts again from its initial route.
- The texts of the screens are English, the form ones of
  `festenao_base_app` French.

The package skills: `skills/festenao-common-flutter-setup` (barrels,
flavor, dev menu, share links), `skills/festenao-common-flutter-quizz`,
`skills/festenao-common-flutter-log`; festenao_common's README for the
data side.
