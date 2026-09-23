import 'package:festenao_common/festenao_cms.dart';
import 'package:festenao_common/festenao_server.dart';
import 'package:festenao_common/firebase/firestore_database.dart';
import 'package:test/test.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';

/// The cms function on the express runtimes (here the memory server), as
/// registered by [FestenaoServerApp.initCmsFunction].
void main() {
  late FirebaseContext firebaseContext;
  late FestenaoServerApp server;
  late Uri serverUri;
  late Future<void> Function() closeServer;
  var client = httpClientFactoryMemory.newClient();
  var ref = const FestenaoCmsSiteRef(
    app: 'festenao',
    projectId: 'p1',
    dataId: 'content',
  );

  setUpAll(() async {
    initFestenaoFsBuilders();
    firebaseContext = await initFirebaseServicesLocalMemory(
      projectId: 'server-cms-express',
    ).initServer();
    server = FestenaoServerApp(
      context: TkCmsServerAppContext(
        firebaseContext: firebaseContext,
        flavorContext: FlavorContext.dev,
      ),
    );
    server.initFunctions();
    server.initCmsFunction();
    var ffServer = await firebaseContext.functions.serve();
    serverUri = ffServer.uri;
    closeServer = ffServer.close;

    await CvDocumentReference<FsProject>(
      ref.projectDocumentPath,
    ).set(firebaseContext.firestore, FsProject()..name.v = 'My festival');
    await festenaoCmsAddProjectPages(
      firestore: firebaseContext.firestore,
      ref: ref,
      pages: [
        SdbCmsPage()
          ..title.v = 'About'
          ..published.v = true,
      ],
    );
  });

  tearDownAll(() async {
    client.close();
    await closeServer();
    await server.cmsContentCache.close();
  });

  test('index, page, not found', () async {
    var siteUri = serverUri.replace(path: '/cmsdev/p1/content/');
    var index = await client.get(siteUri);
    expect(index.statusCode, 200, reason: index.body);
    expect(index.headers['content-type'], cmsContentTypeHtml);
    expect(index.body, contains('My festival'));
    // The links keep the function name in front, as the local runner does.
    expect(index.body, contains('href="${siteUri}page/about"'));

    var page = await client.get(siteUri.resolve('page/about'));
    expect(page.statusCode, 200);
    expect(page.body, contains('<h1>About</h1>'));

    var notFound = await client.get(siteUri.resolve('page/unknown'));
    expect(notFound.statusCode, 404);
  });
}
