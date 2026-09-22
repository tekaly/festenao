/// The generated html rendered by the browser itself: a sandboxed iframe on
/// the web, a placeholder elsewhere.
library;

export 'cms_html_frame_common.dart';
export 'cms_html_frame_stub.dart'
    if (dart.library.js_interop) 'cms_html_frame_web.dart';
