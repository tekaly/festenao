import 'package:festenao_cms_flutter/festenao_cms_flutter.dart';
import 'package:festenao_common_flutter/file_system_explorer_flutter.dart';
import 'package:festenao_theme/theme.dart';
import 'package:flutter/material.dart';

import 'demo_cms.dart';

/// The cms screens of the demo, wired together with [Navigator] pushes.
///
/// A pushed route is outside the scope of the screen that pushed it, so each
/// one gets its own `cmsPageSdbScope` on the same pages.
extension DemoCmsNavigation on DemoCms {
  Future<void> _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => cmsPageSdbScope(sdb: pages, child: screen),
        ),
      );

  /// The page list: publish toggles, create, open a page.
  Future<void> openPages(BuildContext context) => _push(
    context,
    CmsPagesScreen(
      title: 'CMS pages',
      onOpenPage: openPage,
      onCreatePage: (context) => editPage(context, null),
      onBrowseSite: (context) => browseSite(context),
    ),
  );

  /// A page as the app shows it, with its edit and html buttons.
  Future<void> openPage(BuildContext context, SdbCmsPage page) => _push(
    context,
    CmsPagePreviewScreen(
      pageId: page.id,
      onEditPage: editPage,
      onViewHtml: (context, page) => browseSite(
        context,
        path: CmsSiteBrowserScreen.pagePath(renderer, page),
        // A draft has to be served to be looked at.
        includeDrafts: !page.isPublished,
      ),
    ),
  );

  /// Edits a page, or creates one when [pageId] is null.
  Future<void> editPage(BuildContext context, String? pageId) => _push(
    context,
    CmsPageEditScreen(pageId: pageId, linkableItems: demoCmsLinkableItems),
  );

  /// The site the pages render to, the html navigated like a web site.
  Future<void> browseSite(
    BuildContext context, {
    String path = '',
    bool includeDrafts = false,
    CmsSiteViewMode viewMode = CmsSiteViewMode.rendered,
  }) => _push(
    context,
    CmsSiteBrowserScreen(
      renderer: renderer,
      pageOptions: pageOptions,
      initialPath: path,
      includeDrafts: includeDrafts,
      initialViewMode: viewMode,
      monospaceFontFamily: festenaoMonospaceFontFamily,
      onEditPage: (context, page) => editPage(context, page.id),
    ),
  );

  /// The site as the browser itself draws it, css included (web only): a
  /// session of its own, closed with the screen.
  Future<void> browseSiteInBrowser(BuildContext context) async {
    var controller = CmsSiteBrowserController(
      pages: pages,
      renderer: renderer,
      pageOptions: pageOptions,
    );
    try {
      await Navigator.of(context).push<void>(
        MaterialPageRoute(
          builder: (_) => CmsSiteWebViewScreen(
            controller: controller,
            monospaceFontFamily: festenaoMonospaceFontFamily,
            onEditPage: (context, page) => editPage(context, page.id),
          ),
        ),
      );
    } finally {
      controller.dispose();
    }
  }

  /// The raw records of the cms database, in the object explorer: what the
  /// screens above read and write.
  Future<void> exploreDatabase(BuildContext context) =>
      goToObjectExplorerScreen(
        context,
        repository: SdbObjectRepository(
          database,
          title: 'cms_demo.db (memory)',
        ),
      );
}
