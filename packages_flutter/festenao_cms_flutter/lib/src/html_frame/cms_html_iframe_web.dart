import 'dart:js_interop';

import 'package:festenao_cms_flutter/src/widget/cms_rendered_html_view.dart';
import 'package:web/web.dart' as web;

/// The prefix of the messages the frame script posts for a tapped link.
const _linkMessagePrefix = 'cms-frame-link:';

/// Reports the taps on links to the parent instead of following them; an
/// anchor (`#id`) scrolls (with the `<base>` of the document it would load
/// the real site).
const _frameScript =
    '''
<script>
document.addEventListener('click', function (event) {
  var anchor = event.target && event.target.closest
    ? event.target.closest('a[href]') : null;
  if (!anchor) { return; }
  var href = anchor.getAttribute('href');
  event.preventDefault();
  if (href.charAt(0) === '#') {
    var target = document.getElementById(decodeURIComponent(href.substring(1)));
    if (target) { target.scrollIntoView(); }
    return;
  }
  parent.postMessage('$_linkMessagePrefix' + href, '*');
}, true);
</script>''';

final _headRegExp = RegExp(r'<head(\s[^>]*)?>', caseSensitive: false);

/// [html] with the frame script, first thing in its head.
String _withFrameScript(String html) {
  var head = _headRegExp.firstMatch(html);
  if (head == null) {
    return '$_frameScript$html';
  }
  return html.replaceRange(head.end, head.end, _frameScript);
}

/// Prepares [iframe], not yet in a document, to show [html]: sandboxed,
/// filling its parent, the taps on its links handed to what [onLink] returns
/// at the time of the tap.
///
/// The sandbox lets the page run its scripts, but in an opaque origin: they
/// see nothing of the app (no access to the parent, no storage, no cookies),
/// cannot navigate it, open a popup or submit a form. A script of ours,
/// added to the page, posts the taps on links to the window holding the
/// frame, which only listens to that frame.
///
/// `srcdoc` is set on a fresh element each time, never changed: a change
/// would push an entry in the browser history of the app.
///
/// Returns the function to call once the frame is gone (it stops listening).
void Function() setUpCmsHtmlIFrame(
  web.HTMLIFrameElement iframe,
  String html,
  CmsHtmlLinkCallback? Function() onLink,
) {
  iframe.setAttribute('sandbox', 'allow-scripts');
  iframe.style
    ..border = 'none'
    ..width = '100%'
    ..height = '100%'
    ..display = 'block'
    ..backgroundColor = 'white';
  // The window holding the frame: the app, or a tab it opened.
  var window = iframe.ownerDocument?.defaultView ?? web.window;
  var listener = ((web.MessageEvent event) {
    if (!event.source.strictEquals(iframe.contentWindow).toDart) {
      return;
    }
    var data = event.data;
    if (data.typeofEquals('string')) {
      var message = (data as JSString).toDart;
      if (message.startsWith(_linkMessagePrefix)) {
        onLink()?.call(message.substring(_linkMessagePrefix.length));
      }
    }
  }).toJS;
  window.addEventListener('message', listener);
  iframe.srcdoc = _withFrameScript(html).toJS;
  return () => window.removeEventListener('message', listener);
}
