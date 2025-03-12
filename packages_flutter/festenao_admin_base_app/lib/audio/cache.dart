import 'package:festenao_audio_player/cache.dart' as cache;

Future<cache.FileCacheDatabase> initAudioCache({
  required String packageName,
}) async {
  return await cache.initCacheDatabase(packageName: packageName);
}
