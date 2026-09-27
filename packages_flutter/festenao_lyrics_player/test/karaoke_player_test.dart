// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package
import 'package:festenao_lyrics_player/karaoke_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('re-exports tekaly_lyrics_view', () {
    initFestenaoLyricsBuilders();
    var view = KaraokeLyricsView(
      lyrics: parseLyricsText('Hel|lo').lyrics,
      positionMs: () => 0,
    );
    expect(view.lyrics.lines.v!.single.parts.v!.length, 2);
  });
}
