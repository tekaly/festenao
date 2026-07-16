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
///
/// This mixin defines the core schema for content management entities such as
/// artists, events, and info pages. It inherits from [DbStringRecord], meaning
/// each record has a unique `String` identifier (e.g. `id`).
///
/// ### Fields Overview
/// - [name]: The main display title (e.g., artist name, event name).
/// - [author]: Creator/author of the content.
/// - [type]: Sub-classification of the entity (e.g., category).
/// - [subtitle]: A short tagline or descriptive subtitle.
/// - [content]: The primary body content, formatted in Markdown.
/// - [tags]: List of categorization or status tags (e.g. `hidden`).
/// - [sort]: Custom alphanumeric key used for ordering items.
/// - [attributes]: List of linked [CvAttribute]s (e.g. links to Facebook, maps).
/// - [image]: Primary image ID, referencing a [DbImage].
/// - [thumbnail]: Micro preview image ID, referencing a [DbImage].
/// - [squareImage]: Square-cropped image ID, referencing a [DbImage].
///
/// ### Example Usage
///
/// ```dart
/// var artist = DbArtist()
///   ..id = 'john-doe'
///   ..name.v = 'John Doe'
///   ..subtitle.v = 'Indie Singer-songwriter'
///   ..content.v = '# Biography\nJohn Doe has been performing since 2018...'
///   ..tags.v = [articleTagInProgress]
///   ..image.v = 'img_john_doe_hero';
/// ```
mixin DbArticleMixin on DbStringRecord implements DbArticle {
  /// Artist, Event, Info page, or Playlist title/name.
  @override
  final name = CvField<String>('name');

  /// The creator, artist, or author of the content.
  @override
  final author = CvField<String>('author');

  /// Returns the value of [name] if it is not empty, otherwise falls back to
  /// a bracketed representation of the record [id] (e.g. `[artist-123]`).
  String get nameOrId => (name.v?.isNotEmpty ?? false) ? name.v! : '[$id]';

  /// Optional classification type (e.g., event type like 'concert' or 'bal').
  @override
  final type = CvField<String>('type');

  /// A short tagline or subtitle displayed below the name in lists or details.
  @override
  final subtitle = CvField<String>('subtitle');

  /// The markdown content block containing formatted description, schedule details, or bios.
  @override
  final content = CvField<String>('content');

  /// List of categorization tags. Common statuses include `hidden`, `cancelled`, and `in_progress`.
  @override
  final tags = CvListField<String>('tags');

  /// String sorting key. Used to customize ordering in display lists.
  @override
  final sort = CvField<String>('sort');

  /// Structured links, contacts, or actions associated with this article (e.g., URLs, emails, locations).
  ///
  /// Maps to a list of [CvAttribute] instances.
  @override
  final attributes = CvModelListField<CvAttribute>(
    'attributes',
    (_) => CvAttribute(),
  );

  /// Main media image identifier, references [DbImage.id].
  @override
  final image = CvField<String>('image');

  /// Thumbnail image identifier, references [DbImage.id] (optimized for lists).
  @override
  final thumbnail = CvField<String>('thumbnail');

  /// Square-cut image identifier, references [DbImage.id] (optimized for grid views).
  @override
  final squareImage = CvField<String>('squareImage');

  /// Convenient getter for all standard article fields defined by this mixin.
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
/// Helper extension on [DbArticle] to simplify common operations.
extension DbArticleHelpers on DbArticle {
  /// Checks whether this article contains the specific [tag] in its [tags] field.
  bool hasTag(String tag) => tags.v?.contains(tag) ?? false;

  /// Checks if the markdown [content] is non-null and contains non-whitespace text.
  bool hasContent() => content.valueOrNull?.trim().isNotEmpty ?? false;

  /// Whether the article is marked as hidden (i.e. has the `hidden` tag).
  ///
  /// Hidden articles should not be visible to standard end-users.
  bool get hidden => hasTag(articleTagHidden);
}

/// Common alias for article types used across the codebase.
typedef DbArticleCommon = DbArticle;

/// Base class implementing common article fields.
///
/// Inherit from this class if you want to implement a custom record type
/// that includes all default CMS fields.
abstract class DbArticleCommonBase extends DbStringRecordBase
    with DbArticleMixin {
  @override
  List<CvField> get fields => [...articleFields];
}

/// Interface describing an article record's public API.
///
/// Standardizes access to CMS field values and descriptors across various
/// content models like [DbArtist], [DbEvent], and [DbInfo].
abstract class DbArticle extends DbStringRecord {
  /// The logical grouping kind of the article (e.g. `artist`, `event`, `info`, `location`).
  String get articleKind;

  /// Descriptor/Field for the thumbnail image ID.
  CvField<String> get thumbnail;

  /// Descriptor/Field for the square image ID.
  CvField<String> get squareImage;

  /// Descriptor/Field for the markdown body content.
  CvField<String> get content;

  /// Descriptor/Field for the main visual image ID.
  CvField<String> get image;

  /// Descriptor/Field for the classification type string.
  CvField<String> get type;

  /// Descriptor/Field for the subtitle string.
  CvField<String> get subtitle;

  /// Descriptor/Field for the primary name string.
  CvField<String> get name;

  /// Descriptor/Field for the author string.
  CvField<String> get author;

  /// Descriptor/Field for the sort key string.
  CvField<String> get sort;

  /// Descriptor/Field for the list of tags.
  CvListField<String> get tags;

  /// Descriptor/Field for the list of custom attributes/links.
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
