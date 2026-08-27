/// The youtube playlist player: a platform backend that plays one video at a
/// time, plus the link parsing and playlist listing that feed it.
///
/// This is the low level half of the package. It has no ui opinions: it draws
/// the video into whatever box it is given and leaves playlist ordering
/// (shuffle, repeat, next/previous) and controls to the caller.
///
/// For a ready made single video player, use `player.dart` instead.
library;

export 'src/yt/youtube_playlist_page.dart'
    show YoutubePlaylistListing, YoutubePlaylistPage, parseClockDuration;
export 'src/yt/yt_backend_factory.dart' show createYtPlayerBackend;
export 'src/yt/yt_player_backend.dart'
    show
        YtPlaybackState,
        YtPlayerBackend,
        YtPlayerBackendOptions,
        YtResolveException,
        YtResolvedPlaylist;
export 'src/yt/yt_playlist_entry.dart' show YtPlaylistEntry;
export 'src/yt/yt_source.dart'
    show YtPlaylistSource, YtSource, YtVideoSource, parseYtSource;
