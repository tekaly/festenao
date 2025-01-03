import 'package:festenao_common/data/festenao_db.dart';

const articleKindArtist = 'artist';
const articleKindEvent = 'event';
const articleKindInfo = 'info';
const articleKindLocation = 'location';

const articleTagHidden = 'hidden';
const articleTagCancelled = 'cancelled';
const articleTagInProgress = 'in_progress';
const articleTags = [
  articleTagHidden,
  articleTagCancelled,
  articleTagInProgress
];
const imageKind = 'image';

const articleIdIndex = 'index'; // Typically the root infos page
const articleIdDefault = 'default'; // Typically for image of any article
/// Artist id must allow sorting (i.e. typically lastname_firstname
mixin DbArticleMixin on DbStringRecord implements DbArticle {
  /// Artist/Article/Song/Playlist name
  @override
  final name = CvField<String>('name');

  /// Artist/Article/Song/Playlist author
  @override
  final author = CvField<String>('author');

  String get nameOrId => (name.v?.isNotEmpty ?? false) ? name.v! : '[$id]';

  /// Type (optional)
  @override
  final type = CvField<String>('type');

  /// Subtitle
  @override
  final subtitle = CvField<String>('subtitle');

  /// Markdown content
  @override
  final content = CvField<String>('content');

  @override
  final tags = CvListField<String>('tags');

  @override
  final sort = CvField<String>('sort');

  /// Attributes/Links
  @override
  final attributes =
      CvModelListField<CvAttribute>('attributes', (_) => CvAttribute());

  /// DbImage id
  @override
  final image = CvField<String>('image');

  /// DbImage id
  @override
  final thumbnail = CvField<String>('thumbnail');

  /// DbImage id
  @override
  final squareImage = CvField<String>('squareImage');

  List<CvField> get articleFields => [
        name,
        author,
        type,
        subtitle,
        content,
        tags,
        attributes,
        image,
        thumbnail,
        squareImage,
      ];
}

// Helpers
extension DbArticleHelpers on DbArticle {
  bool hasTag(String tag) => tags.v?.contains(tag) ?? false;

  /// Non empty non blank content
  bool hasContent() => content.valueOrNull?.trim().isNotEmpty ?? false;

  /// Check hidden flag
  bool get hidden => hasTag(articleTagHidden);
}

typedef DbArticleCommon = DbArticle;

abstract class DbArticleCommonBase extends DbStringRecordBase
    with DbArticleMixin {
  @override
  List<CvField> get fields => [
        ...articleFields,
      ];
}

abstract class DbArticle extends DbStringRecord {
  String get articleKind;
  CvField<String> get thumbnail;
  CvField<String> get squareImage;
  CvField<String> get content;
  CvField<String> get image;
  CvField<String> get type;
  CvField<String> get subtitle;
  CvField<String> get name;
  CvField<String> get author;
  CvField<String> get sort;
  CvListField<String> get tags;
  CvModelListField<CvAttribute> get attributes;
}

class _DbArticleCommonModel extends DbArticleCommonBase {
  @override
  String get articleKind => throw UnimplementedError();
}

DbArticleCommon dbArticleCommonModel = _DbArticleCommonModel();
List<String> getArticleKindTags(String articleKind) {
  return _articleKindTagsMap[articleKind] ?? <String>[];
}

final _articleKindTagsMap = {
  articleKindArtist: artistTags,
  articleKindEvent: eventTags,
  articleKindInfo: infoTags
}.map((key, value) =>
    MapEntry<String, List<String>>(key, [...value, ...articleTags]));
final _articleKindTypesMap = {
  articleKindArtist: artistTypes,
  articleKindInfo: infoTypes,
  articleKindEvent: eventTypes,
};

List<String> getArticleKindTypes(String articleKind) {
  return _articleKindTypesMap[articleKind] ?? <String>[];
}
