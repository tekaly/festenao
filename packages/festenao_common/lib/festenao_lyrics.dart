/// Lyrics for karaoke and songbooks: the model ([CvLyrics], every time in
/// media milliseconds), the formats (LRC and enhanced LRC, SRT/WebVTT, the
/// lyrics text format which also reads ChordPro), the effective timing
/// ([LyricsTimeline]: pages, where a position falls, the sung ranges), what
/// a player plays of a song ([computePlayRanges]: clips and skipped gaps), a
/// smooth position for the display ([LyricsClock]) and the logic of the
/// timing editor ([LyricsTapEditor]).
///
/// Pure Dart; the karaoke display is in `festenao_lyrics_player`.
library;

export 'lyrics/lyrics_chord.dart';
export 'lyrics/lyrics_clock.dart';
export 'lyrics/lyrics_import.dart';
export 'lyrics/lyrics_lrc.dart';
export 'lyrics/lyrics_merge.dart';
export 'lyrics/lyrics_model.dart';
export 'lyrics/lyrics_subtitles.dart';
export 'lyrics/lyrics_tap_editor.dart';
export 'lyrics/lyrics_text.dart';
export 'lyrics/lyrics_time.dart';
export 'lyrics/lyrics_timeline.dart';
export 'lyrics/media_range.dart';
