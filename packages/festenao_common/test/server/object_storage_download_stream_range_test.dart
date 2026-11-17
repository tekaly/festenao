import 'package:festenao_common/server/festenao_object_storage_download_stream.dart';
import 'package:test/test.dart';

void main() {
  group('parseRangeHeader', () {
    test('no range', () {
      expect(parseRangeHeader(null, total: 100), isNull);
      expect(parseRangeHeader('items=0-1', total: 100), isNull);
      expect(parseRangeHeader('bytes=5-4', total: 100), isNull);
    });

    test('start and end', () {
      expect(parseRangeHeader('bytes=0-1', total: 100), (start: 0, size: 2));
      expect(parseRangeHeader('bytes=10-19'), (start: 10, size: 10));
    });

    test('open end and suffix', () {
      expect(parseRangeHeader('bytes=10-', total: 100), (start: 10, size: 90));
      expect(parseRangeHeader('bytes=10-'), (start: 10, size: null));
      expect(parseRangeHeader('bytes=-10', total: 100), (start: 90, size: 10));
      expect(parseRangeHeader('bytes=-200', total: 100), (start: 0, size: 100));
    });

    test('an end past the file is the remainder of the file', () {
      // Never more bytes than the file has: the content-length and the
      // content-range sent must match what the body holds.
      expect(parseRangeHeader('bytes=0-999', total: 100), (
        start: 0,
        size: 100,
      ));
      expect(parseRangeHeader('bytes=90-100', total: 100), (
        start: 90,
        size: 10,
      ));
    });
  });
}
