/// The server only parts of festenao_jaspr (`dart:io`): the document of a
/// static site and markdown files, read at build time.
library;

export 'festenao_jaspr.dart';
export 'src/server/site_document.dart'
    show MarkdownFile, markdownFileHtml, siteDocument;
