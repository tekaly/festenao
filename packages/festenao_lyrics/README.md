## festenao_lyrics (deprecated, moved)

The lyrics model and formats moved to `tekaly_lyrics_core`
([`tekartikprj/music`](https://github.com/tekartikprj/music),
`packages/lyrics_core`). This package only re-exports it, deprecated, until its
users switch; then it goes. Do not add it to a new project.

### Switching

1. Replace the dependency:

   ```yaml
   dependencies:
     tekaly_lyrics_core:
       git:
         url: https://github.com/tekartikprj/music
         path: packages/lyrics_core
   ```

2. Replace the import:

   ```dart
   import 'package:tekaly_lyrics_core/lyrics_core.dart';
   ```

   (was `package:festenao_lyrics/festenao_lyrics.dart`). Every name is the
   same, except `initFestenaoLyricsBuilders()`, now
   `initTekalyLyricsBuilders()`.

The Flutter display (`KaraokeLyricsView`, `SongbookLyricsView`) is
`tekaly_lyrics_view` (`packages_flutter/lyrics_view` of the same repository).
