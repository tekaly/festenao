import 'package:festenao_common/data/festenao_db.dart';

/// Article kind for artists.
const articleKindArtist = 'artist';

/// Article kind for events.
const articleKindEvent = 'event';

/// Article kind for info pages.
const articleKindInfo = 'info';

/// Article kind for locations.
const articleKindLocation = 'location';

/// Tag used to mark articles as hidden.
const articleTagHidden = 'hidden';

/// Tag used to mark cancelled events/articles.
const articleTagCancelled = 'cancelled';

/// Tag used to mark items currently in progress.
const articleTagInProgress = 'in_progress';

/// Collection of common article tags applied to different kinds.
const articleTags = [
  articleTagHidden,
  articleTagCancelled,
  articleTagInProgress,
];

/// Kind name for images stored as articles.
const imageKind = 'image';

/// Index article id (typically used for a root infos page).
const articleIdIndex = 'index';

/// Default article id (typically used for default images).
const articleIdDefault = 'default';

/// Mixin providing common article fields used by multiple article types.
mixin DbArticleMixin on DbStringRecord implements DbArticle {
  /// Artist/Article/Song/Playlist name
  @override
  final name = CvField<String>('name');

  /// Artist/Article/Song/Playlist author
  @override
  final author = CvField<String>('author');

  /// The name or the identifier if the name is empty.
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
  final attributes = CvModelListField<CvAttribute>(
    'attributes',
    (_) => CvAttribute(),
  );

  /// DbImage id
  @override
  final image = CvField<String>('image');

  /// DbImage id
  @override
  final thumbnail = CvField<String>('thumbnail');

  /// DbImage id
  @override
  final squareImage = CvField<String>('squareImage');

  /// List of fields for an article.
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
/// Helper extension on [DbArticle].
extension DbArticleHelpers on DbArticle {
  /// Returns true if the article has the given [tag].
  bool hasTag(String tag) => tags.v?.contains(tag) ?? false;

  /// Non empty non blank content
  bool hasContent() => content.valueOrNull?.trim().isNotEmpty ?? false;

  /// Check hidden flag
  bool get hidden => hasTag(articleTagHidden);
}

/// Common alias for article types used across the codebase.
typedef DbArticleCommon = DbArticle;

/// Base class implementing common article fields.
abstract class DbArticleCommonBase extends DbStringRecordBase
    with DbArticleMixin {
  @override
  List<CvField> get fields => [...articleFields];
}

/// Interface describing an article record's public API.
abstract class DbArticle extends DbStringRecord {
  /// The kind of article (artist/event/info/location).
  /// The kind of article (artist/event/info/location).
  String get articleKind;

  /// The thumbnail image id.
  CvField<String> get thumbnail;

  /// The square image id.
  CvField<String> get squareImage;

  /// The markdown content.
  CvField<String> get content;

  /// The main image id.
  CvField<String> get image;

  /// The article type.
  CvField<String> get type;

  /// The subtitle.
  CvField<String> get subtitle;

  /// The article name.
  CvField<String> get name;

  /// The article author.
  CvField<String> get author;

  /// The sort key.
  CvField<String> get sort;

  /// List of tags.
  CvListField<String> get tags;

  /// List of attributes.
  CvModelListField<CvAttribute> get attributes;
}

class _DbArticleCommonModel extends DbArticleCommonBase {
  @override
  String get articleKind => throw UnimplementedError();
}

/// Default model instance for common article fields.
DbArticleCommon dbArticleCommonModel = _DbArticleCommonModel();

/// Returns the list of tags applicable for the given [articleKind].
List<String> getArticleKindTags(String articleKind) {
  return _articleKindTagsMap[articleKind] ?? <String>[];
}

final _articleKindTagsMap =
    {
      articleKindArtist: artistTags,
      articleKindEvent: eventTags,
      articleKindInfo: infoTags,
    }.map(
      (key, value) =>
          MapEntry<String, List<String>>(key, [...value, ...articleTags]),
    );
final _articleKindTypesMap = {
  articleKindArtist: artistTypes,
  articleKindInfo: infoTypes,
  articleKindEvent: eventTypes,
};

/// Returns the allowed types for the given [articleKind].
List<String> getArticleKindTypes(String articleKind) {
  return _articleKindTypesMap[articleKind] ?? <String>[];
}
