import 'package:festenao_audio_player/player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('formatSongDuration', () {
    expect(formatSongDuration(Duration.zero), '0:00');
    expect(formatSongDuration(const Duration(seconds: 60)), '1:00');
    expect(formatSongDuration(const Duration(milliseconds: 900)), '0:00');
    expect(formatSongDuration(const Duration(milliseconds: 1000)), '0:01');
  });
}
