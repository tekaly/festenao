import 'package:festenao_common/data/gdrive_link.dart';
import 'package:test/test.dart';

void main() {
  _urlTests();
  group('driveIdFromText', () {
    test('bare id', () {
      expect(
        driveIdFromText('1AbCdEfGh_ij-KLMNOP234'),
        '1AbCdEfGh_ij-KLMNOP234',
      );
      expect(driveIdFromText('  1AbCdEfGh_ij-KLMNOP234  '), isNotNull);
    });
    test('folder url', () {
      expect(
        driveIdFromText(
          'https://drive.google.com/drive/folders/1AbCdEfGh_ij-KLMNOP234?usp=sharing',
        ),
        '1AbCdEfGh_ij-KLMNOP234',
      );
      expect(
        driveIdFromText(
          'https://drive.google.com/drive/u/0/folders/1AbCdEfGh_ij-KLMNOP234',
        ),
        '1AbCdEfGh_ij-KLMNOP234',
      );
    });
    test('file url', () {
      expect(
        driveIdFromText(
          'https://drive.google.com/file/d/1AbCdEfGh_ij-KLMNOP234/view?usp=drive_link',
        ),
        '1AbCdEfGh_ij-KLMNOP234',
      );
      expect(
        driveIdFromText(
          'https://drive.google.com/open?id=1AbCdEfGh_ij-KLMNOP234',
        ),
        '1AbCdEfGh_ij-KLMNOP234',
      );
    });
    test('invalid', () {
      expect(driveIdFromText(''), isNull);
      expect(driveIdFromText('hello'), isNull);
      expect(driveIdFromText('https://example.com/folders'), isNull);
      expect(
        driveIdFromText('https://drive.google.com/drive/my-drive'),
        isNull,
      );
    });
  });
}

void _urlTests() {
  group('drive urls', () {
    test('folder, view and download', () {
      expect(
        driveFolderUrl('1lqMxFn2BIFu0lbiydAQiEAEoePEN1cff'),
        'https://drive.google.com/drive/folders/1lqMxFn2BIFu0lbiydAQiEAEoePEN1cff',
      );
      expect(
        driveFileViewUrl('abc'),
        'https://drive.google.com/file/d/abc/view',
      );
      expect(
        driveFileDownloadUrl('abc'),
        'https://drive.google.com/uc?export=download&id=abc',
      );
      // Round trip through the parser.
      expect(
        driveIdFromText(driveFolderUrl('1AbCdEfGh_ij-KLMNOP234')),
        '1AbCdEfGh_ij-KLMNOP234',
      );
      expect(
        driveIdFromText(driveFileViewUrl('1AbCdEfGh_ij-KLMNOP234')),
        '1AbCdEfGh_ij-KLMNOP234',
      );
      expect(
        driveIdFromText(driveFileDownloadUrl('1AbCdEfGh_ij-KLMNOP234')),
        '1AbCdEfGh_ij-KLMNOP234',
      );
    });
  });
}
