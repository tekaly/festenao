// ignore_for_file: deprecated_member_use_from_same_package
import 'package:festenao_lyrics/festenao_lyrics.dart';
import 'package:test/test.dart';

void main() {
  test('re-exports tekaly_lyrics_core', () {
    initFestenaoLyricsBuilders();
    var lyrics = parseLyricsText('Hel|lo').lyrics;
    expect(lyrics.lines.v!.single.parts.v!.length, 2);
  });
}
