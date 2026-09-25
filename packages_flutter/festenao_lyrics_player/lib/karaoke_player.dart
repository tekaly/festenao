/// The karaoke display of `festenao_common` lyrics ([CvLyrics]): a page (or
/// a scrolling list) of lines, the syllables wiped as they are sung, lead-in
/// dots after a gap ([KaraokeLyricsView]); and their songbook text, the
/// chords above the syllables ([SongbookLyricsView]).
///
/// Re-exports `package:festenao_common/festenao_lyrics.dart` (the model, the
/// formats, the timeline and the clock).
library;

export 'package:festenao_common/festenao_lyrics.dart';

export 'src/karaoke/karaoke_lyrics_view.dart'
    show KaraokeLyricsLayout, KaraokeLyricsStyle, KaraokeLyricsView;
export 'src/karaoke/songbook_lyrics_view.dart' show SongbookLyricsView;
