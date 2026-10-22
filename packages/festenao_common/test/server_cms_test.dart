import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

void main() {
  group('CmsSiteRequest', () {
    test('mount', () {
      var request = CmsSiteRequest.fromUrl(
        Uri.parse('http://localhost:8040/cmsdev/p1/content/page/about'),
        mountNames: ['cms', 'cmsdev'],
      );
      expect(request.baseUrl.toString(), 'http://localhost:8040/cmsdev/');
      expect(request.path, 'p1/content/page/about');

      request = CmsSiteRequest.fromUrl(
        Uri.parse('https://cmsdev-abc-ew.a.run.app/p1/content/'),
        mountNames: ['cms', 'cmsdev'],
      );
      expect(request.baseUrl.toString(), 'https://cmsdev-abc-ew.a.run.app/');
      expect(request.path, 'p1/content');
    });

    test('forwarded by the hosting', () {
      var request = CmsSiteRequest.fromUrl(
        Uri.parse('http://cmsdev-abc-ew.a.run.app/cms/p1/content/sitemap.xml'),
        mountNames: ['cms', 'cmsdev'],
        forwardedHost: 'my-app-dev.web.app, proxy.example.com',
        forwardedProto: 'https',
      );
      expect(request.baseUrl.toString(), 'https://my-app-dev.web.app/cms/');
      var site = request.shift(2)!;
      expect(
        site.baseUrl.toString(),
        'https://my-app-dev.web.app/cms/p1/content/',
      );
      expect(site.path, 'sitemap.xml');
      expect(request.shift(5), isNull);
    });

    test('invalid forwarded values are ignored', () {
      var request = CmsSiteRequest.fromUrl(
        Uri.parse('http://localhost:8040/cms/'),
        forwardedHost: 'evil.com/"><script>',
        forwardedProto: 'javascript',
      );
      // No mount names: the first segment stays in the path.
      expect(request.baseUrl.toString(), 'http://localhost:8040/');
      expect(request.segments, ['cms']);
    });
  });

  test('festenaoIsDevApp', () {
    expect(festenaoIsDevApp('festenao-dev'), isTrue);
    expect(festenaoIsDevApp('festenao_dev'), isTrue);
    expect(festenaoIsDevApp('festenao-devx'), isTrue);
    expect(festenaoIsDevApp('festenao'), isFalse);
    expect(festenaoIsDevApp('festenao-prod'), isFalse);
    expect(festenaoIsDevApp('devotion'), isFalse);
  });

  test('festenaoAppRoot', () {
    expect(festenaoAppRoot('buzzerelio-dev'), 'buzzerelio');
    expect(festenaoAppRoot('buzzerelio-prod'), 'buzzerelio');
    expect(festenaoAppRoot('buzzerelio_dev_local'), 'buzzerelio');
    expect(festenaoAppRoot('festenao_test'), 'festenao');
    expect(festenaoAppRoot('festenao'), 'festenao');
    expect(festenaoAppRoot('festenao-devotion'), 'festenao-devotion');
    expect(festenaoAppRoot('my-app-devx'), 'my-app');
  });

  test('festenaoIsDevOrTestApp', () {
    expect(festenaoIsDevOrTestApp('festenao-dev'), isTrue);
    expect(festenaoIsDevOrTestApp('festenao_devx'), isTrue);
    expect(festenaoIsDevOrTestApp('festenao_test'), isTrue);
    expect(festenaoIsDevOrTestApp('festenao_dev_local'), isTrue);
    expect(festenaoIsDevOrTestApp('festenao'), isFalse);
    expect(festenaoIsDevOrTestApp('festenao-prod'), isFalse);
    expect(festenaoIsDevOrTestApp('festenao-prodx'), isFalse);
    expect(festenaoIsDevOrTestApp('festenao-devotion'), isFalse);
  });

  group('server cms', () {
    const app = 'festenao-dev';
    late FirebaseContext firebaseContext;
    late FestenaoServerApp server;
    late Firestore firestore;
    var ref = const FestenaoCmsSiteRef(
      app: app,
      projectId: 'p1',
      dataId: 'content',
    );

    setUpAll(() async {
      initFestenaoFsBuilders();
      firebaseContext = await initFirebaseServicesLocalMemory(
        projectId: 'server-cms',
      ).init();
      firestore = firebaseContext.firestore;
      server = FestenaoServerApp(
        app: app,
        context: TkCmsServerAppContext(
          firebaseContext: firebaseContext,
          flavorContext: FlavorContext.dev,
        ),
      );
      await CvDocumentReference<FsProject>(
        ref.projectDocumentPath,
      ).set(firestore, FsProject()..name.v = 'My festival');
      await festenaoCmsAddProjectPages(
        firestore: firestore,
        ref: ref,
        pages: [
          SdbCmsPage()
            ..title.v = 'About'
            ..body.v = 'Hello **world**'
            ..published.v = true,
          SdbCmsPage()..title.v = 'Draft',
        ],
      );
    });

    tearDownAll(() async {
      await server.cmsContentCache.close();
      await firebaseContext.close();
    });

    Future<CmsResponse> get(String path) => server.handleCmsRequest(
      CmsSiteRequest.fromUrl(
        Uri.parse('https://my-app-dev.web.app/$path'),
        mountNames: server.cmsMountNames,
      ),
    );

    test('function and mount names', () {
      expect(server.cmsCommand, 'cmsdev');
      expect(server.cmsMountNames, ['cms', 'cmsdev']);
    });

    test('index and page', () async {
      var index = await get('cms/p1/content/');
      expect(index.statusCode, 200, reason: index.body);
      expect(index.body, contains('My festival'));
      expect(
        index.body,
        contains('href="https://my-app-dev.web.app/cms/p1/content/page/about"'),
      );
      expect(index.body, isNot(contains('Draft')));

      var page = await get('cms/p1/content/page/about');
      expect(page.statusCode, 200);
      expect(page.body, contains('<strong>world</strong>'));
    });

    test('not found', () async {
      for (var path in [
        'cms/',
        'cms/p1',
        'cms/p1/other/',
        'cms/p2/content/',
        'cms/p1/content/page/draft',
        'cms/p1/content/page/unknown',
      ]) {
        expect((await get(path)).statusCode, 404, reason: path);
      }
    });

    test('a deleted project is not served', () async {
      var deleted = const FestenaoCmsSiteRef(
        app: app,
        projectId: 'deleted',
        dataId: 'content',
      );
      await CvDocumentReference<FsProject>(deleted.projectDocumentPath).set(
        firestore,
        FsProject()
          ..name.v = 'Deleted'
          ..deleted.v = true,
      );
      await festenaoCmsAddProjectPages(
        firestore: firestore,
        ref: deleted,
        pages: [
          SdbCmsPage()
            ..title.v = 'Gone'
            ..published.v = true,
        ],
      );
      expect((await get('cms/deleted/content/')).statusCode, 404);
    });

    test('a change is served at once', () async {
      expect((await get('cms/p1/content/page/news')).statusCode, 404);
      await festenaoCmsAddProjectPages(
        firestore: firestore,
        ref: ref,
        pages: [
          SdbCmsPage()
            ..title.v = 'News'
            ..published.v = true,
        ],
      );
      expect((await get('cms/p1/content/page/news')).statusCode, 200);
    });

    FestenaoServerApp newProdServer() => FestenaoServerApp(
      context: TkCmsServerAppContext(
        firebaseContext: firebaseContext,
        flavorContext: FlavorContext.prod,
      ),
    );

    test('isAppAllowed', () {
      expect(server.isAppAllowed('festenao-dev'), isTrue);
      expect(server.isAppAllowed('festenao_dev'), isTrue);
      expect(server.isAppAllowed('festenao-devx'), isTrue);
      expect(server.isAppAllowed('festenao_test'), isTrue);
      expect(server.isAppAllowed('festenao_dev_local'), isTrue);
      expect(server.isAppAllowed('festenao'), isFalse);
      expect(server.isAppAllowed('festenao-prod'), isFalse);
      expect(server.isAppAllowed('buzzerelio-dev'), isFalse);
      expect(server.isAppAllowed('tkcms_dev'), isFalse);
      expect(server.isAppAllowed(null), isFalse);
      var prodServer = newProdServer();
      expect(prodServer.cmsCommand, 'cms');
      expect(prodServer.isAppAllowed('festenao'), isTrue);
      expect(prodServer.isAppAllowed('festenao-dev'), isFalse);
      expect(prodServer.isAppAllowed('festenao_test'), isFalse);
      expect(prodServer.isAppAllowed('festenao-prod'), isFalse);
      expect(prodServer.isAppAllowed(null), isFalse);
    });

    test('timestamp app check', () async {
      Future<ApiResult> timestamp(FestenaoServerApp server, String? app) =>
          server.onCommand(
            ApiRequest(command: commandTimestamp)..app.setValue(app),
          );
      Future<void> expectRefused(FestenaoServerApp server, String? app) async {
        try {
          await timestamp(server, app);
          fail('$app should be refused');
        } on ApiException catch (e) {
          expect(e.error?.code.v, HttpsErrorCode.permissionDenied);
        }
      }

      var prodServer = newProdServer();
      expect(
        await timestamp(server, 'festenao-dev'),
        isA<ApiGetTimestampResponse>(),
      );
      expect(
        await timestamp(server, 'festenao_test'),
        isA<ApiGetTimestampResponse>(),
      );
      expect(
        await timestamp(prodServer, 'festenao'),
        isA<ApiGetTimestampResponse>(),
      );
      // Dev calling prod, prod calling dev, no app.
      await expectRefused(server, 'festenao');
      await expectRefused(prodServer, 'festenao-dev');
      await expectRefused(server, null);
      await expectRefused(prodServer, null);
    });
  });
}
