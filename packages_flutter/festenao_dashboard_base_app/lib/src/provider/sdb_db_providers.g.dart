// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sdb_db_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(contentCache)
final contentCacheProvider = ContentCacheProvider._();

final class ContentCacheProvider
    extends
        $FunctionalProvider<
          SdbProjectsContentCache,
          SdbProjectsContentCache,
          SdbProjectsContentCache
        >
    with $Provider<SdbProjectsContentCache> {
  ContentCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'contentCacheProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$contentCacheHash();

  @$internal
  @override
  $ProviderElement<SdbProjectsContentCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SdbProjectsContentCache create(Ref ref) {
    return contentCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SdbProjectsContentCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SdbProjectsContentCache>(value),
    );
  }
}

String _$contentCacheHash() => r'0e7daf52ec916721d1055d06860db595784c6028';

@ProviderFor(projectContent)
final projectContentProvider = ProjectContentFamily._();

final class ProjectContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<SdbProjectContent>,
          SdbProjectContent,
          FutureOr<SdbProjectContent>
        >
    with
        $FutureModifier<SdbProjectContent>,
        $FutureProvider<SdbProjectContent> {
  ProjectContentProvider._({
    required ProjectContentFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'projectContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$projectContentHash();

  @override
  String toString() {
    return r'projectContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<SdbProjectContent> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SdbProjectContent> create(Ref ref) {
    final argument = this.argument as (String, String);
    return projectContent(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ProjectContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$projectContentHash() => r'3af9cb6838c33f336befc73eb32e0d6f30e7a1da';

final class ProjectContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SdbProjectContent>,
          (String, String)
        > {
  ProjectContentFamily._()
    : super(
        retry: null,
        name: r'projectContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ProjectContentProvider call(String projectId, String dataId) =>
      ProjectContentProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'projectContentProvider';
}

@ProviderFor(sdbProjectContent)
final sdbProjectContentProvider = SdbProjectContentFamily._();

final class SdbProjectContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<SdbProjectContent>,
          SdbProjectContent,
          Stream<SdbProjectContent>
        >
    with
        $FutureModifier<SdbProjectContent>,
        $StreamProvider<SdbProjectContent> {
  SdbProjectContentProvider._({
    required SdbProjectContentFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'sdbProjectContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$sdbProjectContentHash();

  @override
  String toString() {
    return r'sdbProjectContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<SdbProjectContent> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SdbProjectContent> create(Ref ref) {
    final argument = this.argument as (String, String);
    return sdbProjectContent(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is SdbProjectContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$sdbProjectContentHash() => r'abe7acfa11f59a8e9b54360f98b0319bce3681ea';

final class SdbProjectContentFamily extends $Family
    with
        $FunctionalFamilyOverride<Stream<SdbProjectContent>, (String, String)> {
  SdbProjectContentFamily._()
    : super(
        retry: null,
        name: r'sdbProjectContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  SdbProjectContentProvider call(String projectId, String dataId) =>
      SdbProjectContentProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'sdbProjectContentProvider';
}

@ProviderFor(contentSdb)
final contentSdbProvider = ContentSdbFamily._();

final class ContentSdbProvider
    extends
        $FunctionalProvider<
          AsyncValue<SdfContentSdb?>,
          SdfContentSdb?,
          Stream<SdfContentSdb?>
        >
    with $FutureModifier<SdfContentSdb?>, $StreamProvider<SdfContentSdb?> {
  ContentSdbProvider._({
    required ContentSdbFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'contentSdbProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$contentSdbHash();

  @override
  String toString() {
    return r'contentSdbProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<SdfContentSdb?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SdfContentSdb?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return contentSdb(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ContentSdbProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$contentSdbHash() => r'338b4c871ed317bbd29f548f42f850656cca5e04';

final class ContentSdbFamily extends $Family
    with $FunctionalFamilyOverride<Stream<SdfContentSdb?>, (String, String)> {
  ContentSdbFamily._()
    : super(
        retry: null,
        name: r'contentSdbProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ContentSdbProvider call(String projectId, String dataId) =>
      ContentSdbProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'contentSdbProvider';
}

@ProviderFor(artistEntries)
final artistEntriesProvider = ArtistEntriesFamily._();

final class ArtistEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SdfArtist>>,
          List<SdfArtist>,
          Stream<List<SdfArtist>>
        >
    with $FutureModifier<List<SdfArtist>>, $StreamProvider<List<SdfArtist>> {
  ArtistEntriesProvider._({
    required ArtistEntriesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'artistEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$artistEntriesHash();

  @override
  String toString() {
    return r'artistEntriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<SdfArtist>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SdfArtist>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return artistEntries(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ArtistEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$artistEntriesHash() => r'529f21a8118909fcad27619c9ea48d6b14886bf3';

final class ArtistEntriesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<SdfArtist>>, (String, String)> {
  ArtistEntriesFamily._()
    : super(
        retry: null,
        name: r'artistEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ArtistEntriesProvider call(String projectId, String dataId) =>
      ArtistEntriesProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'artistEntriesProvider';
}

@ProviderFor(eventEntries)
final eventEntriesProvider = EventEntriesFamily._();

final class EventEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SdfEvent>>,
          List<SdfEvent>,
          Stream<List<SdfEvent>>
        >
    with $FutureModifier<List<SdfEvent>>, $StreamProvider<List<SdfEvent>> {
  EventEntriesProvider._({
    required EventEntriesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'eventEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$eventEntriesHash();

  @override
  String toString() {
    return r'eventEntriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<SdfEvent>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SdfEvent>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return eventEntries(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is EventEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$eventEntriesHash() => r'989c7f480f48d978365508965b95e46fdd396a5b';

final class EventEntriesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<SdfEvent>>, (String, String)> {
  EventEntriesFamily._()
    : super(
        retry: null,
        name: r'eventEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  EventEntriesProvider call(String projectId, String dataId) =>
      EventEntriesProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'eventEntriesProvider';
}

@ProviderFor(imageEntries)
final imageEntriesProvider = ImageEntriesFamily._();

final class ImageEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SdfImage>>,
          List<SdfImage>,
          Stream<List<SdfImage>>
        >
    with $FutureModifier<List<SdfImage>>, $StreamProvider<List<SdfImage>> {
  ImageEntriesProvider._({
    required ImageEntriesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'imageEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$imageEntriesHash();

  @override
  String toString() {
    return r'imageEntriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<SdfImage>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SdfImage>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return imageEntries(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is ImageEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$imageEntriesHash() => r'ce52a1713e5674b7673a27737348423ce44573c9';

final class ImageEntriesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<SdfImage>>, (String, String)> {
  ImageEntriesFamily._()
    : super(
        retry: null,
        name: r'imageEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ImageEntriesProvider call(String projectId, String dataId) =>
      ImageEntriesProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'imageEntriesProvider';
}

@ProviderFor(imageEntry)
final imageEntryProvider = ImageEntryFamily._();

final class ImageEntryProvider
    extends
        $FunctionalProvider<AsyncValue<SdfImage?>, SdfImage?, Stream<SdfImage?>>
    with $FutureModifier<SdfImage?>, $StreamProvider<SdfImage?> {
  ImageEntryProvider._({
    required ImageEntryFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: null,
         name: r'imageEntryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$imageEntryHash();

  @override
  String toString() {
    return r'imageEntryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<SdfImage?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<SdfImage?> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return imageEntry(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is ImageEntryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$imageEntryHash() => r'8208bb89e4a7feb15010ad4aea098aea3ffd4135';

final class ImageEntryFamily extends $Family
    with
        $FunctionalFamilyOverride<Stream<SdfImage?>, (String, String, String)> {
  ImageEntryFamily._()
    : super(
        retry: null,
        name: r'imageEntryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  ImageEntryProvider call(String projectId, String dataId, String imageId) =>
      ImageEntryProvider._(argument: (projectId, dataId, imageId), from: this);

  @override
  String toString() => r'imageEntryProvider';
}

@ProviderFor(mediaEntries)
final mediaEntriesProvider = MediaEntriesFamily._();

final class MediaEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SdbFestenaoMediaFile>>,
          List<SdbFestenaoMediaFile>,
          Stream<List<SdbFestenaoMediaFile>>
        >
    with
        $FutureModifier<List<SdbFestenaoMediaFile>>,
        $StreamProvider<List<SdbFestenaoMediaFile>> {
  MediaEntriesProvider._({
    required MediaEntriesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'mediaEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaEntriesHash();

  @override
  String toString() {
    return r'mediaEntriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<SdbFestenaoMediaFile>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SdbFestenaoMediaFile>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return mediaEntries(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaEntriesHash() => r'9008078fd8dbc9d41bc71877a7c9492084b850cd';

final class MediaEntriesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<List<SdbFestenaoMediaFile>>,
          (String, String)
        > {
  MediaEntriesFamily._()
    : super(
        retry: null,
        name: r'mediaEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MediaEntriesProvider call(String projectId, String dataId) =>
      MediaEntriesProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'mediaEntriesProvider';
}

@ProviderFor(mediaEntry)
final mediaEntryProvider = MediaEntryFamily._();

final class MediaEntryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SdbFestenaoMediaFile?>,
          SdbFestenaoMediaFile?,
          Stream<SdbFestenaoMediaFile?>
        >
    with
        $FutureModifier<SdbFestenaoMediaFile?>,
        $StreamProvider<SdbFestenaoMediaFile?> {
  MediaEntryProvider._({
    required MediaEntryFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: null,
         name: r'mediaEntryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaEntryHash();

  @override
  String toString() {
    return r'mediaEntryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<SdbFestenaoMediaFile?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SdbFestenaoMediaFile?> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return mediaEntry(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaEntryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaEntryHash() => r'ba80e45f726ba6c0bdf86590dbbfd49b5eb57e36';

final class MediaEntryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<SdbFestenaoMediaFile?>,
          (String, String, String)
        > {
  MediaEntryFamily._()
    : super(
        retry: null,
        name: r'mediaEntryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MediaEntryProvider call(String projectId, String dataId, String mediaId) =>
      MediaEntryProvider._(argument: (projectId, dataId, mediaId), from: this);

  @override
  String toString() => r'mediaEntryProvider';
}

@ProviderFor(mediaStatusFileEntry)
final mediaStatusFileEntryProvider = MediaStatusFileEntryFamily._();

final class MediaStatusFileEntryProvider
    extends
        $FunctionalProvider<
          AsyncValue<SdbFestenaoMediaFileStatus?>,
          SdbFestenaoMediaFileStatus?,
          Stream<SdbFestenaoMediaFileStatus?>
        >
    with
        $FutureModifier<SdbFestenaoMediaFileStatus?>,
        $StreamProvider<SdbFestenaoMediaFileStatus?> {
  MediaStatusFileEntryProvider._({
    required MediaStatusFileEntryFamily super.from,
    required (String, String, String) super.argument,
  }) : super(
         retry: null,
         name: r'mediaStatusFileEntryProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$mediaStatusFileEntryHash();

  @override
  String toString() {
    return r'mediaStatusFileEntryProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<SdbFestenaoMediaFileStatus?> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<SdbFestenaoMediaFileStatus?> create(Ref ref) {
    final argument = this.argument as (String, String, String);
    return mediaStatusFileEntry(ref, argument.$1, argument.$2, argument.$3);
  }

  @override
  bool operator ==(Object other) {
    return other is MediaStatusFileEntryProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$mediaStatusFileEntryHash() =>
    r'1b50768878904b2e9538a3d08fa5670d0b9f8b5e';

final class MediaStatusFileEntryFamily extends $Family
    with
        $FunctionalFamilyOverride<
          Stream<SdbFestenaoMediaFileStatus?>,
          (String, String, String)
        > {
  MediaStatusFileEntryFamily._()
    : super(
        retry: null,
        name: r'mediaStatusFileEntryProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  MediaStatusFileEntryProvider call(
    String projectId,
    String dataId,
    String mediaId,
  ) => MediaStatusFileEntryProvider._(
    argument: (projectId, dataId, mediaId),
    from: this,
  );

  @override
  String toString() => r'mediaStatusFileEntryProvider';
}

@ProviderFor(locationEntries)
final locationEntriesProvider = LocationEntriesFamily._();

final class LocationEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SdfLocation>>,
          List<SdfLocation>,
          Stream<List<SdfLocation>>
        >
    with
        $FutureModifier<List<SdfLocation>>,
        $StreamProvider<List<SdfLocation>> {
  LocationEntriesProvider._({
    required LocationEntriesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'locationEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$locationEntriesHash();

  @override
  String toString() {
    return r'locationEntriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<SdfLocation>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SdfLocation>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return locationEntries(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is LocationEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$locationEntriesHash() => r'7eb4fa6ea612db0b33a0fc9c0dfb75d33b801390';

final class LocationEntriesFamily extends $Family
    with
        $FunctionalFamilyOverride<Stream<List<SdfLocation>>, (String, String)> {
  LocationEntriesFamily._()
    : super(
        retry: null,
        name: r'locationEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  LocationEntriesProvider call(String projectId, String dataId) =>
      LocationEntriesProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'locationEntriesProvider';
}
