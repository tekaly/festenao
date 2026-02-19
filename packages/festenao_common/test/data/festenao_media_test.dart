import 'package:festenao_common/data/festenao_media.dart';
import 'package:test/test.dart';

void main() {
  test('FestenaoMediaFile.from', () async {
    var file = FestenaoMediaFile.from(
      filename: 'my\\file/test.webp',
      type: 'image/webp',
    );
    var path = file.path.v!;
    expect(path, endsWith('_test.webp'));
    var parts = path.split('/');
    expect(parts, hasLength(4));
    expect(parts[0], hasLength(2));
    expect(parts[1], hasLength(2));
    expect(parts[2], hasLength(2));
    expect(parts[3], hasLength(42));
  });
}
