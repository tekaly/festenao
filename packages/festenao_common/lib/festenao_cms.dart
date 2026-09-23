/// Festenao mini CMS: pages stored in a content database and rendered to
/// static, SEO friendly html with mustache templates.
///
/// Pure Dart. The pages live next to the content they present, in the synced
/// sdb of a project/calendar ([cmsPageStoreSchema] added to its schema, edited
/// with `festenao_cms_flutter`), and a cloud function renders them with a
/// [CmsRenderer], a [CmsSiteHandler] mapping the urls of the site to them.
library;

export 'package:tekartik_app_cv_sdb/app_cv_sdb.dart';

export 'cms/cms_markdown.dart';
export 'cms/cms_page.dart';
export 'cms/cms_renderer.dart';
export 'cms/cms_site_handler.dart';
export 'cms/cms_site_request.dart';
export 'cms/cms_structured_data.dart';
export 'cms/cms_templates.dart';
