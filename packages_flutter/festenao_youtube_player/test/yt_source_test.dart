import 'package:festenao_youtube_player/yt_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseYtSource', () {
    test('watch link', () {
      final source = parseYtSource(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect(source, isA<YtVideoSource>());
      expect((source! as YtVideoSource).videoId, 'dQw4w9WgXcQ');
    });

    test('short link', () {
      final source = parseYtSource('https://youtu.be/dQw4w9WgXcQ?t=42');
      expect((source! as YtVideoSource).videoId, 'dQw4w9WgXcQ');
    });

    test('shorts link', () {
      final source = parseYtSource('youtube.com/shorts/dQw4w9WgXcQ');
      expect((source! as YtVideoSource).videoId, 'dQw4w9WgXcQ');
    });

    test('playlist link', () {
      final source = parseYtSource(
        'https://www.youtube.com/playlist?list=PLFgquLnL59alCl_2TQvOiD5Vgm1',
      );
      final playlist = source! as YtPlaylistSource;
      expect(playlist.playlistId, 'PLFgquLnL59alCl_2TQvOiD5Vgm1');
      expect(playlist.startVideoId, isNull);
      expect(playlist.startIndex, isNull);
    });

    test('watch link inside a playlist keeps both, index is 0 based', () {
      final source = parseYtSource(
        'https://www.youtube.com/watch?v=dQw4w9WgXcQ'
        '&list=PLFgquLnL59alCl_2TQvOiD5Vgm1&index=3',
      );
      final playlist = source! as YtPlaylistSource;
      expect(playlist.playlistId, 'PLFgquLnL59alCl_2TQvOiD5Vgm1');
      expect(playlist.startVideoId, 'dQw4w9WgXcQ');
      expect(playlist.startIndex, 2);
    });

    test('music.youtube.com', () {
      final source = parseYtSource(
        'https://music.youtube.com/watch?v=dQw4w9WgXcQ',
      );
      expect((source! as YtVideoSource).videoId, 'dQw4w9WgXcQ');
    });

    test('bare ids', () {
      expect(
        (parseYtSource('dQw4w9WgXcQ')! as YtVideoSource).videoId,
        'dQw4w9WgXcQ',
      );
      expect(
        (parseYtSource('PLFgquLnL59alCl_2TQvOiD5Vgm1')! as YtPlaylistSource)
            .playlistId,
        'PLFgquLnL59alCl_2TQvOiD5Vgm1',
      );
    });

    test('rejects anything else', () {
      expect(parseYtSource(''), isNull);
      expect(parseYtSource('hello world'), isNull);
      expect(parseYtSource('https://vimeo.com/watch?v=dQw4w9WgXcQ'), isNull);
      expect(parseYtSource('https://www.youtube.com/'), isNull);
    });
  });

  group('start time', () {
    test('parseYtStartTime', () {
      expect(parseYtStartTime('90'), const Duration(seconds: 90));
      expect(parseYtStartTime('90s'), const Duration(seconds: 90));
      expect(parseYtStartTime('1m30s'), const Duration(seconds: 90));
      expect(parseYtStartTime('1h2m3s'), const Duration(seconds: 3723));
      expect(parseYtStartTime('0'), isNull);
      expect(parseYtStartTime('abc'), isNull);
      expect(parseYtStartTime(null), isNull);
    });
    test('in links', () {
      var video =
          parseYtSource('https://youtu.be/dQw4w9WgXcQ?t=42') as YtVideoSource;
      expect(video.start, const Duration(seconds: 42));
      video =
          parseYtSource('https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=1m2s')
              as YtVideoSource;
      expect(video.start, const Duration(seconds: 62));
      video =
          parseYtSource('https://www.youtube.com/embed/dQw4w9WgXcQ?start=10')
              as YtVideoSource;
      expect(video.start, const Duration(seconds: 10));
      var playlist =
          parseYtSource(
                'https://www.youtube.com/watch?v=dQw4w9WgXcQ&list=PLx0sYbCqOb8TBPRdmBHs5Iftvv9TPboYG&t=5',
              )
              as YtPlaylistSource;
      expect(playlist.start, const Duration(seconds: 5));
      expect((parseYtSource('dQw4w9WgXcQ') as YtVideoSource).start, isNull);
    });
  });
}
