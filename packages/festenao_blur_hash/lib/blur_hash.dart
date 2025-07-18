import 'dart:typed_data';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:image/image.dart' as img;

export 'package:blurhash_dart/blurhash_dart.dart' show BlurHash;

Future<String> festenaoBlurHashEncode(Uint8List bytes) async {
  /// Encodes an image as a BlurHash string.
  ///
  /// Takes [bytes] as the raw image data and returns the BlurHash string.
  var image = img.decodeImage(bytes)!;
  return await image.blurHashEncode();
}

extension FestenaoBlurHashImageExt on img.Image {
  /// Encodes this image as a BlurHash string.
  Future<String> blurHashEncode() async {
    var blurHash = BlurHash.encode(this).hash;
    return blurHash;
  }
}
