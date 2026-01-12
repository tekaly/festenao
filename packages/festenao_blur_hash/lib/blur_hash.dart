import 'dart:typed_data';

import 'package:blurhash_dart/blurhash_dart.dart';
import 'package:image/image.dart' as img;

export 'package:blurhash_dart/blurhash_dart.dart' show BlurHash;

/// Encodes an image as a BlurHash string.
Future<String> festenaoBlurHashEncode(Uint8List bytes) async {
  /// Encodes an image as a BlurHash string.
  ///
  /// Takes [bytes] as the raw image data and returns the BlurHash string.
  var image = img.decodeImage(bytes)!;
  return await image.blurHashEncode();
}

/// Extension to add BlurHash encoding functionality to img.Image.
extension FestenaoBlurHashImageExt on img.Image {
  /// Encodes this image as a BlurHash string.
  Future<String> blurHashEncode() async {
    var blurHash = BlurHash.encode(this).hash;
    return blurHash;
  }
}
