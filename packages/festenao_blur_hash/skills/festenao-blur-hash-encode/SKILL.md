---
name: festenao-blur-hash-encode
description: >-
  Use when computing or decoding a BlurHash placeholder string for an image
  in a festenao/tekaly app with festenao_blur_hash: festenaoBlurHashEncode on
  raw image bytes, the blurHashEncode() extension on a package:image Image
  (FestenaoBlurHashImageExt), and the re-exported BlurHash class
  (BlurHash.encode with numCompX/numCompY, BlurHash.decode, hash, components).
---

# Blur hash bridge (festenao_blur_hash)

`festenao_blur_hash` is the one place where the festenao packages pick their
BlurHash implementation, today `package:blurhash_dart` over `package:image`.
Depend on the bridge, not on `blurhash_dart`, so that switching the
implementation stays a one package change.

## Guidelines

* Dependency (git, not on pub.dev):
  ```yaml
  dependencies:
    festenao_blur_hash:
      git:
        url: https://github.com/tekaly/festenao
        path: packages/festenao_blur_hash
      version: '>=0.1.0'
    image: '>=4.5.4' # only when you decode or build an img.Image yourself
  ```
* Import `package:festenao_blur_hash/blur_hash.dart`. It gives
  `festenaoBlurHashEncode(Uint8List bytes)`, the extension
  `FestenaoBlurHashImageExt` (`image.blurHashEncode()`) on `img.Image`, and
  re-exports only `BlurHash` from `blurhash_dart` (nothing else of it).
* `festenaoBlurHashEncode(bytes)` decodes the bytes with `img.decodeImage`
  (png, jpeg, gif, webp, bmp, tiff...) and encodes the picture; it throws
  when the bytes are not a decodable image, so guard user supplied files
  (decode yourself and check for null when in doubt).
* `image.blurHashEncode()` is the same on an `img.Image` you already hold (a
  resized thumbnail, a generated picture). Both are `async` but CPU bound:
  downscale first (`img.copyResize(image, width: 32)`, a hash needs no
  detail) and run the encoding off the UI isolate (`compute`) for big
  pictures.
* Both use the blurhash_dart defaults (4x3 components). For another size
  call `BlurHash.encode(image, numCompX: , numCompY: ).hash` directly; each
  count is 1 to 9, more components means a longer string and more detail.
* `BlurHash.decode(hash)` gives back a `BlurHash` with `hash`, `numCompX`,
  `numCompY` and `components` (rows of color triplets), throwing on a
  malformed string. Turning it into pixels or a widget is not this
  package's job: use `flutter_blurhash` in Flutter, or add a direct
  `blurhash_dart` dependency for `blurhash_extensions.dart` (`toImage`).
* Compute the hash once, at upload or import time, and store the ~30
  character string next to the media metadata; never at display time.
* Pure Dart, no platform code: works on the VM, Flutter and the web. Tests
  run with `dart test`; a blank `img.Image(width: 10, height: 10)` encodes
  to `L00000fQfQfQfQfQfQfQfQfQfQfQ`.

## Examples

### Hash of an image file

```dart
import 'dart:io';

import 'package:festenao_blur_hash/blur_hash.dart';

Future<String> blurHashOfFile(String path) async {
  var bytes = await File(path).readAsBytes();
  return festenaoBlurHashEncode(bytes);
}
```

### Guarded decode, downscale, then encode

```dart
import 'dart:typed_data';

import 'package:festenao_blur_hash/blur_hash.dart';
import 'package:image/image.dart' as img;

/// Null when [bytes] is not an image.
Future<String?> thumbnailBlurHash(Uint8List bytes) async {
  var image = img.decodeImage(bytes);
  if (image == null) {
    return null;
  }
  // 32 pixels wide is plenty for a 4x3 components hash.
  var small = img.copyResize(image, width: 32);
  return small.blurHashEncode();
}
```

### More components, and reading a hash back

```dart
import 'package:festenao_blur_hash/blur_hash.dart';
import 'package:image/image.dart' as img;

String detailedBlurHash(img.Image image) =>
    BlurHash.encode(image, numCompX: 6, numCompY: 4).hash;

void describe(String hash) {
  var blurHash = BlurHash.decode(hash);
  print('${blurHash.numCompX}x${blurHash.numCompY} components');
  print('${blurHash.components.length} rows');
}
```

### Test

```dart
import 'package:festenao_blur_hash/blur_hash.dart';
import 'package:image/image.dart';
import 'package:test/test.dart';

void main() {
  test('blurHashEncode', () async {
    var image = Image(width: 10, height: 10);
    expect(await image.blurHashEncode(), 'L00000fQfQfQfQfQfQfQfQfQfQfQ');
  });
}
```

## Common mistakes

* Importing `package:blurhash_dart/blurhash_dart.dart` in app code: go
  through the bridge, it is the point of the package.
* Calling `festenaoBlurHashEncode` on bytes that may not be an image (it
  throws on a failed decode).
* Encoding a full resolution photo on the UI isolate.
