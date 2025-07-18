import 'package:tekartik_html/html_html5lib.dart' as tk_html;
import 'package:tekartik_html/tag.dart';
import 'package:tekartik_yacht/yacht.dart';

var htmlFactory = tk_html.htmlProviderHtml5Lib;

String boilerPlate =
    r'<style amp-boilerplate>body{-webkit-animation:-amp-start 8s steps(1,end) 0s 1 normal both;-moz-animation:-amp-start 8s steps(1,end) 0s 1 normal both;-ms-animation:-amp-start 8s steps(1,end) 0s 1 normal both;animation:-amp-start 8s steps(1,end) 0s 1 normal both}@-webkit-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@-moz-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@-ms-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@-o-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}</style><noscript><style amp-boilerplate>body{-webkit-animation:none;-moz-animation:none;-ms-animation:none;animation:none}</style></noscript>';
String boilerPlate1 =
    r'<style amp-boilerplate>body{-webkit-animation:-amp-start 8s steps(1,end) 0s 1 normal both;-moz-animation:-amp-start 8s steps(1,end) 0s 1 normal both;-ms-animation:-amp-start 8s steps(1,end) 0s 1 normal both;animation:-amp-start 8s steps(1,end) 0s 1 normal both}@-webkit-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@-moz-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@-ms-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@-o-keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}@keyframes -amp-start{from{visibility:hidden}to{visibility:visible}}</style>';
String boilerPlate2 =
    r'<noscript><style amp-boilerplate>body{-webkit-animation:none;-moz-animation:none;-ms-animation:none;animation:none}</style></noscript>';
String baseJs =
    r'<script async="" src="https://cdn.ampproject.org/v0.js"></script>';

/// AMP HTML page builder.
///
/// Use [title] and [content] to set the page's main heading and content.
class Page {
  /// The page title, rendered as an <h1> if set.
  String? title;

  /// The main content of the page, rendered in a <div> if set.
  String? content;

  /// Returns the AMP HTML for this page as a [String].
  String toHtmlText() {
    var doc = htmlFactory.createDocument();

    // Doc type
    // <html ⚡>
    var htmlElement = htmlFactory.createElementTag(tagHtml);
    htmlElement.attributes['amp'] = '';

    //doc.append(htmlElement);

    // Head
    // <meta charset="utf-8">
    // <meta name="viewport" content="width=device-width,minimum-scale=1,initial-scale=1">
    var headElement = htmlFactory.createElementTag('head');
    var charsetElement = htmlFactory.createElementTag('meta');
    charsetElement.attributes['charset'] = 'utf-8';
    headElement.append(charsetElement);
    headElement.append(
      htmlFactory.createElementTag('meta')
        ..attributes['name'] = 'viewport'
        ..attributes['content'] =
            'width=device-width,minimum-scale=1,initial-scale=1',
    );

    headElement.append(htmlFactory.createElementHtml(boilerPlate1));
    headElement.append(htmlFactory.createElementHtml(boilerPlate2));
    headElement.append(htmlFactory.createElementHtml(baseJs));

    headElement.append(
      htmlFactory.createElementHtml(
        '<link href="https://fonts.googleapis.com/css?family=Karla:400,700" rel="stylesheet">',
      ),
    );

    htmlElement.append(headElement);

    // Body
    var bodyElement = htmlFactory.createElementTag('body');

    bodyElement.append(
      htmlFactory.createElementTag('div')
        ..innerHtml = '<a href="cms/amp">amp</a',
    );
    //bodyElement.append(spaceElement());

    if (title != null) {
      bodyElement.append(
        htmlFactory.createElementTag('h1')..innerHtml = title!,
      );
    }
    if (content != null) {
      bodyElement.append(
        htmlFactory.createElementTag('div')..innerHtml = content!,
      );
    }

    htmlElement.append(bodyElement);

    return htmlPrintDocument(doc);
  }
}
