# Setup

```
  festenao_lyrics_player:
    git:
      url: https://github.com/tekaly/festenao
      path: packages_flutter/festenao_lyrics_player
```

`karaoke_player.dart` (`KaraokeLyricsView`, `SongbookLyricsView`) moved to
`tekaly_lyrics_view` in `tekartikprj/music`; it is re-exported here,
deprecated, until its users switch. `lyrics_player.dart` (the older
`LyricsDataPlayer` over `tekaly_lyrics`) stays.
