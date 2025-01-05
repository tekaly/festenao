import 'package:festenao_blur_hash/blur_hash.dart';
import 'package:image/image.dart';
import 'package:test/test.dart';

void main() {
  group('FestenaoBlurHashImageExt', () {
    test('blurHashEncode', () async {
      var image = Image(width: 10, height: 10);
      expect(await image.blurHashEncode(), 'L00000fQfQfQfQfQfQfQfQfQfQfQ');
    });
  });
}
