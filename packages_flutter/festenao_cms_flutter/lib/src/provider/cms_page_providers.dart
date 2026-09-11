import 'package:festenao_common/festenao_cms.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The page database the cms screens work on.
///
/// Scoped: the host wraps the cms screens in [cmsPageSdbScope] with the
/// `CmsPageSdb` of the content database at hand (a calendar, a project...).
/// Reading it outside such a scope throws, on purpose.
final cmsPageSdbProvider = Provider<CmsPageSdb>(
  (ref) => throw StateError(
    'cmsPageSdbProvider is only readable below a cmsPageSdbScope. '
    'Wrap the cms screens in cmsPageSdbScope(sdb: ..., child: ...).',
  ),
  name: 'cmsPageSdb',
);

/// Every page of the database, by order then title.
final cmsPagesProvider = StreamProvider.autoDispose<List<SdbCmsPage>>(
  (ref) => ref.watch(cmsPageSdbProvider).onPages(),
);

/// One page, null when unknown.
final cmsPageProvider = StreamProvider.autoDispose.family<SdbCmsPage?, String>(
  (ref, pageId) => ref.watch(cmsPageSdbProvider).onPage(pageId),
);

/// Provide [sdb] to the cms screens below [child].
Widget cmsPageSdbScope({required CmsPageSdb sdb, required Widget child}) =>
    ProviderScope(
      overrides: [cmsPageSdbProvider.overrideWithValue(sdb)],
      child: child,
    );
