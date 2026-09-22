@TestOn('vm')
library;

import 'package:festenao_common/festenao_api.dart';
import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_dartff/functions.dart';
import 'package:festenao_dashboard_app_demo/src/demo_server.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tekartik_http/http_memory.dart';
import 'package:tkcms_common/tkcms_server.dart';

/// Every link within the site, from the index, answered 200; returns the
/// paths visited below [siteUrl].
Future<Set<String>> _crawl(Client client, Uri siteUrl) async {
  var hrefRegExp = RegExp(r'href="([^"]+)"');
  var visited = <String>{};
  var toVisit = [siteUrl, siteUrl.resolve('sitemap.xml')];
  while (toVisit.isNotEmpty) {
    var url = toVisit.removeLast();
    var path = url.path.substring(siteUrl.path.length);
    if (!visited.add(path)) {
      continue;
    }
    var response = await client.get(url);
    expect(response.statusCode, 200, reason: '$url');
    for (var match in hrefRegExp.allMatches(response.body)) {
      var target = url.resolve(match.group(1)!);
      if (target.authority == siteUrl.authority &&
          target.path.startsWith(siteUrl.path)) {
        toVisit.add(target.replace(fragment: ''));
      }
    }
  }
  return visited;
}

void main() {
  var client = httpFactoryMemory.client.newClient();
  tearDownAll(client.close);

  group('bin/server.dart', () {
    late DemoServer server;
    setUpAll(() async {
      server = await DemoServer.serveCms(
        httpServerFactory: httpFactoryMemory.server,
      );
    });
    tearDownAll(() => server.close());

    test('serves the cms site on 8040, every link within it', () async {
      expect(server.uri.port, festenaoFunctionsHttpServerPort);
      expect(server.cmsSiteUrl.path, '/cms/');
      var visited = await _crawl(client, server.cmsSiteUrl);
      expect(visited, containsAll(['', 'page/about', 'page/program']));
      expect(visited, isNot(contains('page/line-up-2027')));

      // The draft is not served, nor is anything else.
      for (var path in ['page/line-up-2027', 'page/nope']) {
        var response = await client.get(server.cmsSiteUrl.resolve(path));
        expect(response.statusCode, 404, reason: path);
      }
      // A change to the pages is served at once.
      var draft = (await server.cms.pages.getPageBySlug('line-up-2027'))!;
      await server.cms.pages.setPublished(draft.id, true);
      var response = await client.get(
        server.cmsSiteUrl.resolve('page/line-up-2027'),
      );
      expect(response.statusCode, 200);
    });
  });

  group('bin/server_ff_app.dart', () {
    late DemoServer server;
    setUpAll(() async {
      server = await DemoServer.serveFfApp(
        httpServerFactory: httpFactoryMemory.server,
      );
    });
    tearDownAll(() => server.close());

    test('serves the festenao functions and the cms site', () async {
      expect(server.ffApp, isNotNull);
      expect(server.cmsSiteUrl.path, '/cmsdev/');
      await _crawl(client, server.cmsSiteUrl);

      var amp = await client.get(server.uri.replace(path: '/ampdev'));
      expect(amp.statusCode, 200);
      expect(amp.headers['content-type'], startsWith('text/html'));

      // The api, through the festenao client.
      var apiService = FestenaoApiService(
        httpClientFactory: httpFactoryMemory.client,
        httpsApiUri: server.uri.replace(path: '/$functionCommandDartV2Dev'),
      );
      await apiService.initClient();
      var timestamp = await apiService.getTimestamp();
      expect(timestamp.timestamp.v, isNotNull);
    });
  });
}
