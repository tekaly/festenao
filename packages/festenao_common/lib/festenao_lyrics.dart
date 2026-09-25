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

export 'src/lyrics/lyrics_chord.dart'
    show CvLyricsChordExt, transposeLyricsChord;
export 'src/lyrics/lyrics_clock.dart' show LyricsClock;
export 'src/lyrics/lyrics_import.dart'
    show LyricsFormat, detectLyricsFormat, importLyrics;
export 'src/lyrics/lyrics_lrc.dart'
    show LyricsImport, formatLrcLyrics, parseLrcLyrics;
export 'src/lyrics/lyrics_merge.dart' show mergeLyricsTiming;
export 'src/lyrics/lyrics_model.dart'
    show
        CvLyrics,
        CvLyricsExt,
        CvLyricsLine,
        CvLyricsLineExt,
        CvLyricsPart,
        CvLyricsPartExt,
        initFestenaoLyricsBuilders;
export 'src/lyrics/lyrics_subtitles.dart' show parseSubtitleLyrics;
export 'src/lyrics/lyrics_tap_editor.dart'
    show
        LyricsTapEditor,
        LyricsTimingGranularity,
        LyricsTimingIssue,
        LyricsUnitRef;
export 'src/lyrics/lyrics_text.dart'
    show
        formatLyricsText,
        isLyricsChordName,
        parseLyricsText,
        parseLyricsTextLine;
export 'src/lyrics/lyrics_time.dart' show formatLyricsTime, parseLyricsTime;
export 'src/lyrics/lyrics_timeline.dart'
    show
        LyricsLocation,
        LyricsTimeline,
        LyricsTimelineLine,
        LyricsTimelineOptions,
        LyricsTimelinePage,
        LyricsTimelinePart;
export 'src/lyrics/media_range.dart'
    show MediaRange, computePlayRanges, nextPlayRangeIndex;
