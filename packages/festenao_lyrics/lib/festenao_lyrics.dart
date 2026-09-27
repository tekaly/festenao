/// Moved to `tekaly_lyrics_core` (`tekartikprj/music`,
/// `package:tekaly_lyrics_core/lyrics_core.dart`), which this library
/// re-exports until its users switch.
@Deprecated('Use package:tekaly_lyrics_core/lyrics_core.dart')
library;

import 'package:tekaly_lyrics_core/lyrics_core.dart';

export 'package:tekaly_lyrics_core/lyrics_core.dart';

/// Moved: [initTekalyLyricsBuilders].
@Deprecated('Use initTekalyLyricsBuilders')
void initFestenaoLyricsBuilders() => initTekalyLyricsBuilders();
