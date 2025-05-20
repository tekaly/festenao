/// Utility functions for the audio player
String formatSongDuration(Duration duration) {
  var minutes = duration.inMinutes;
  var seconds = duration.inSeconds.remainder(60);
  var str = '$minutes:${seconds.toString().padLeft(2, '0')}';
  return str;
}
