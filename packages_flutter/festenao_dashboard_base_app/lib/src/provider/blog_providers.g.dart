// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(blogCache)
final blogCacheProvider = BlogCacheProvider._();

final class BlogCacheProvider
    extends
        $FunctionalProvider<
          SdbProjectsContentBlogCache,
          SdbProjectsContentBlogCache,
          SdbProjectsContentBlogCache
        >
    with $Provider<SdbProjectsContentBlogCache> {
  BlogCacheProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'blogCacheProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$blogCacheHash();

  @$internal
  @override
  $ProviderElement<SdbProjectsContentBlogCache> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SdbProjectsContentBlogCache create(Ref ref) {
    return blogCache(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SdbProjectsContentBlogCache value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SdbProjectsContentBlogCache>(value),
    );
  }
}

String _$blogCacheHash() => r'1ca35f71e5ac1504e1dda35b1ef94b7a447e946f';

@ProviderFor(blogContent)
final blogContentProvider = BlogContentFamily._();

final class BlogContentProvider
    extends
        $FunctionalProvider<
          AsyncValue<SdbProjectContentBlog>,
          SdbProjectContentBlog,
          FutureOr<SdbProjectContentBlog>
        >
    with
        $FutureModifier<SdbProjectContentBlog>,
        $FutureProvider<SdbProjectContentBlog> {
  BlogContentProvider._({
    required BlogContentFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'blogContentProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$blogContentHash();

  @override
  String toString() {
    return r'blogContentProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<SdbProjectContentBlog> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<SdbProjectContentBlog> create(Ref ref) {
    final argument = this.argument as (String, String);
    return blogContent(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is BlogContentProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$blogContentHash() => r'cc811cecd08684910223e700860c95b031ab1cb5';

final class BlogContentFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<SdbProjectContentBlog>,
          (String, String)
        > {
  BlogContentFamily._()
    : super(
        retry: null,
        name: r'blogContentProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BlogContentProvider call(String projectId, String dataId) =>
      BlogContentProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'blogContentProvider';
}

@ProviderFor(blogSdb)
final blogSdbProvider = BlogSdbFamily._();

final class BlogSdbProvider
    extends
        $FunctionalProvider<AsyncValue<BlogSdb?>, BlogSdb?, Stream<BlogSdb?>>
    with $FutureModifier<BlogSdb?>, $StreamProvider<BlogSdb?> {
  BlogSdbProvider._({
    required BlogSdbFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'blogSdbProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$blogSdbHash();

  @override
  String toString() {
    return r'blogSdbProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<BlogSdb?> $createElement($ProviderPointer pointer) =>
      $StreamProviderElement(pointer);

  @override
  Stream<BlogSdb?> create(Ref ref) {
    final argument = this.argument as (String, String);
    return blogSdb(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is BlogSdbProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$blogSdbHash() => r'47d2e85f7d6cb89b7ff3c8198eff3fc2489bf09c';

final class BlogSdbFamily extends $Family
    with $FunctionalFamilyOverride<Stream<BlogSdb?>, (String, String)> {
  BlogSdbFamily._()
    : super(
        retry: null,
        name: r'blogSdbProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BlogSdbProvider call(String projectId, String dataId) =>
      BlogSdbProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'blogSdbProvider';
}

@ProviderFor(blogEntries)
final blogEntriesProvider = BlogEntriesFamily._();

final class BlogEntriesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<DbBlog>>,
          List<DbBlog>,
          Stream<List<DbBlog>>
        >
    with $FutureModifier<List<DbBlog>>, $StreamProvider<List<DbBlog>> {
  BlogEntriesProvider._({
    required BlogEntriesFamily super.from,
    required (String, String) super.argument,
  }) : super(
         retry: null,
         name: r'blogEntriesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$blogEntriesHash();

  @override
  String toString() {
    return r'blogEntriesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $StreamProviderElement<List<DbBlog>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<DbBlog>> create(Ref ref) {
    final argument = this.argument as (String, String);
    return blogEntries(ref, argument.$1, argument.$2);
  }

  @override
  bool operator ==(Object other) {
    return other is BlogEntriesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$blogEntriesHash() => r'96ae78e194f6508da4f9bd8797ec4ea764a26e50';

final class BlogEntriesFamily extends $Family
    with $FunctionalFamilyOverride<Stream<List<DbBlog>>, (String, String)> {
  BlogEntriesFamily._()
    : super(
        retry: null,
        name: r'blogEntriesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  BlogEntriesProvider call(String projectId, String dataId) =>
      BlogEntriesProvider._(argument: (projectId, dataId), from: this);

  @override
  String toString() => r'blogEntriesProvider';
}

@ProviderFor(publicUserProjects)
final publicUserProjectsProvider = PublicUserProjectsProvider._();

final class PublicUserProjectsProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SdbUserProject>>,
          List<SdbUserProject>,
          Stream<List<SdbUserProject>>
        >
    with
        $FutureModifier<List<SdbUserProject>>,
        $StreamProvider<List<SdbUserProject>> {
  PublicUserProjectsProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'publicUserProjectsProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$publicUserProjectsHash();

  @$internal
  @override
  $StreamProviderElement<List<SdbUserProject>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<List<SdbUserProject>> create(Ref ref) {
    return publicUserProjects(ref);
  }
}

String _$publicUserProjectsHash() =>
    r'b4d277f1fe970e114da46e9c5a00cc83989fe7d0';
