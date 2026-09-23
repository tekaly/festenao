import 'package:festenao_common/festenao_cms.dart';

import 'demo_cms_data.dart';

/// Serves the demo site at any url: the pages of one in memory [DemoCms],
/// the links of the site following the base url of each request (the
/// hosting url, the function url, a local server).
///
/// What the `cmsdemo` cloud function answers.
class DemoCmsServer {
  /// The pages.
  final Future<DemoCms> cms;

  /// Serves [cms], a new [DemoCms] by default.
  DemoCmsServer({DemoCms? cms})
    : cms = cms != null ? Future.value(cms) : DemoCms.create();

  /// The site at [baseUrl].
  Future<CmsSiteHandler> siteHandler(Uri baseUrl) async {
    var renderer = CmsRenderer(site: demoCmsSite(baseUrl: baseUrl));
    return CmsSiteHandler(
      pages: (await cms).pages,
      renderer: renderer,
      pageOptions: demoCmsPageOptions(renderer),
    );
  }

  /// Serves [request], the site at its base url.
  Future<CmsResponse> handle(CmsSiteRequest request) async =>
      await (await siteHandler(request.baseUrl)).handlePath(request.path);

  /// Close.
  Future<void> close() async {
    await (await cms).database.close();
  }
}

/// The demo site server of the process (the `cmsdemo` function), its pages
/// opened on first use.
final demoCmsServer = DemoCmsServer();
