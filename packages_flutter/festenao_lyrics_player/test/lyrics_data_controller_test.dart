import 'package:festenao_lyrics_player/lyrics_player.dart';
import 'package:festenao_lyrics_player/src/lyrics_data_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekaly_lyrics/utils/lyrics_data_located.dart';

void main() {
  test('pause stops the play loop, play resumes where it was', () async {
    var controller = LyricsDataController(
      lyricsData: parseLyricLrc('[00:00.00]Zero\n[00:01.00]One\n'),
    );
    addTearDown(controller.pause);
    var lineOne = controller.getItemStatusStream(
      LocatedLyricsDataItemRef.lineBefore(1),
    );
    controller.play();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    controller.pause();
    // Playing on, the second line would be on after 1 s.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    expect(lineOne.value.on, isFalse);
    controller.play();
    for (var i = 0; i < 300 && !lineOne.value.on; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    expect(lineOne.value.on, isTrue);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
