import 'dart:typed_data';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:image/image.dart' as img;

export 'package:blurhash_dart/blurhash_dart.dart' show BlurHash;

Future<String> festenaoBlurHashEncode(Uint8List bytes) async {
  var image = img.decodeImage(bytes)!;
  return await image.blurHashEncode();
}

extension FestenaoBlurHashImageExt on img.Image {
  Future<String> blurHashEncode() async {
    var blurHash = BlurHash.encode(this).hash;
    return blurHash;
  }
}
