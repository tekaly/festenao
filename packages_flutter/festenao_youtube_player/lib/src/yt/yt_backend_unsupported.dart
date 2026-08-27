import 'yt_player_backend.dart';

/// There is no youtube player backend for this platform.
YtPlayerBackend createYtPlayerBackend({YtPlayerBackendOptions? options}) =>
    throw UnsupportedError('No youtube player backend for this platform');
