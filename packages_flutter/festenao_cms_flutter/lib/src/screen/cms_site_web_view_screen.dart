import 'dart:async';

import 'package:festenao_cms_flutter/src/cms_site_browser_controller.dart';
import 'package:festenao_cms_flutter/src/html_frame/cms_html_frame.dart';
import 'package:festenao_cms_flutter/src/widget/cms_html_document.dart';
import 'package:festenao_cms_flutter/src/widget/cms_site_browser_bars.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:flutter/material.dart';

/// The site the pages render to, drawn by the browser itself (css included),
/// in a sandboxed iframe: on the web only, elsewhere it says so.
///
/// It is another view of a [CmsSiteBrowserController]: the history, the
/// drafts toggle and the current page are the ones of the session, shared
/// with the `CmsSiteBrowserScreen` it is usually opened from. The document
/// runs sandboxed, in an opaque origin (it reaches nothing of the app); a
/// tapped link within the site is opened here, a link elsewhere in a new
/// browser tab.
class CmsSiteWebViewScreen extends StatelessWidget {
  /// The session.
  final CmsSiteBrowserController controller;

  /// The font of the url.
  final String? monospaceFontFamily;

  /// Called to edit the page on screen (an edit button shows when set).
  final void Function(BuildContext context, SdbCmsPage page)? onEditPage;

  /// A browser rendering of [controller].
  const CmsSiteWebViewScreen({
    super.key,
    required this.controller,
    this.monospaceFontFamily,
    this.onEditPage,
  });

  void _follow(String href) {
    var url = controller.url.resolve(href);
    var path = controller.pathOfUrl(url);
    if (path == null) {
      cmsOpenExternalUrl(url);
    } else {
      controller.go(path);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: controller,
    builder: (context, _) {
      var page = controller.page;
      var onEditPage = this.onEditPage;
      var response = controller.response;
      var error = controller.error;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            controller.document?.title ?? controller.site.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          actions: [
            if (page != null && onEditPage != null)
              IconButton(
                icon: const Icon(Icons.edit),
                tooltip: 'Edit this page',
                onPressed: () => onEditPage(context, page),
              ),
            if (cmsHtmlFrameSupported)
              IconButton(
                icon: const Icon(Icons.open_in_new),
                tooltip: 'Open in a new tab',
                onPressed: () {
                  if (!cmsSiteOpenInNewTab(controller)) {
                    ScaffoldMessenger.of(context)
                      ..hideCurrentSnackBar()
                      ..showSnackBar(
                        const SnackBar(
                          content: Text('The browser blocked the new tab'),
                        ),
                      );
                  }
                },
              ),
          ],
        ),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CmsSiteAddressBar(
              controller: controller,
              monospaceFontFamily: monospaceFontFamily,
              onNotOnSite: cmsOpenExternalUrl,
            ),
            CmsSiteStatusBar(
              controller: controller,
              leading: const [
                Chip(
                  avatar: Icon(Icons.open_in_browser, size: 18),
                  label: Text('Browser rendering'),
                ),
              ],
            ),
            if (controller.isLoading)
              const LinearProgressIndicator(minHeight: 2)
            else
              const SizedBox(height: 2),
            const Divider(height: 1),
            Expanded(
              child: error != null
                  ? Center(child: Text('Error: $error'))
                  : response == null
                  ? const Center(child: CircularProgressIndicator())
                  : CmsHtmlFrame(
                      html: cmsHtmlForBrowser(response, controller.url),
                      onLink: _follow,
                    ),
            ),
          ],
        ),
      );
    },
  );
}

/// Opens [path] (the current one by default) of the site of [controller] in
/// a new browser tab, drawn by the browser itself; the links within the site
/// are followed in that tab, the others open a tab of their own.
///
/// The tab renders through [controller] (its drafts setting included) but
/// keeps its own place. Returns false when not on the web, or when the
/// browser blocked the tab: call it from a tap.
bool cmsSiteOpenInNewTab(CmsSiteBrowserController controller, {String? path}) {
  var window = cmsOpenHtmlWindow(title: controller.site.name);
  if (window == null) {
    return false;
  }
  Future<void> show(String path) async {
    var url = controller.urlOf(path);
    var response = await controller.fetch(path);
    var html = cmsHtmlForBrowser(response, url);
    window.show(
      html,
      title: response.isHtml
          ? CmsHtmlDocument.parse(response.body).title
          : url.toString(),
      onLink: (href) {
        var target = url.resolve(href);
        var targetPath = controller.pathOfUrl(target);
        if (targetPath == null) {
          cmsOpenExternalUrl(target);
        } else {
          unawaited(show(targetPath));
        }
      },
    );
  }

  unawaited(show(path ?? controller.path));
  return true;
}
