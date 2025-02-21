dynamic sanitize(dynamic value) {
  if (value is String || value is num || value is bool || value == null) {
    return value;
  }
  if (value is Map) {
    return value.map((key, value) =>
        MapEntry<String, dynamic>(key as String, sanitize(value)));
  }
  if (value is List) {
    return value.map((value) => sanitize(value));
  }
  return value.toString();
}

/*
Map<String, dynamic> cmsArticleMap(CmsArticle article) {
  var map = <String, dynamic>{};
  map['title'] = article.title;
  map['summary'] = article.summary;
  return map;
  // return sanitize(article.toDocumentData().asMap()) as Map<String, dynamic>;
}

class AmpListPage {
  final FileSystem fs;
  List<CmsArticle> articles;

  AmpListPage({required this.fs, required this.articles});
  Future<String?> toHtmlText() async {
    var values = <String, dynamic>{};
    values['title'] = 'All posts';
    values['articles'] =
        articles.map((article) => cmsArticleMap(article)).toList();
    print(values);
    return await renderFile(fs, fs.path.join('deploy', 'amp', 'index.html'),
        values: values);
  }
}
*/
