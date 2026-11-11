import 'package:festenao_common/data/festenao_db.dart';
import 'package:test/test.dart';

const _timeout = Timeout(Duration(seconds: 30));

void main() {
  test('article sort is written', () {
    for (var article in <DbArticle>[DbArtist(), DbEvent(), DbInfo()]) {
      article
        ..name.v = 'a'
        ..sort.v = '01';
      expect(article.toMap(), {'name': 'a', 'sort': '01'});
    }
  }, timeout: _timeout);
  test('article sort is read', () {
    for (var article in <DbArticle>[DbArtist(), DbEvent(), DbInfo()]) {
      article.fromMap({'name': 'e', 'sort': '02'});
      expect(article.sort.v, '02');
    }
    // Absent, nothing written.
    expect(DbArtist().toMap(), isEmpty);
  }, timeout: _timeout);
}
