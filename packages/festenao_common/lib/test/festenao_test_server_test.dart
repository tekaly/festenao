import 'package:dev_test/test.dart';
import 'package:festenao_common/api/festenao_api_client.dart';
import 'package:festenao_common/server/festeano_server_app.dart';
import 'package:tekartik_firebase_functions/ff_server.dart';
import 'package:tkcms_common/tkcms_app.dart';
import 'package:tkcms_common/tkcms_common.dart';
import 'package:tkcms_common/tkcms_firebase.dart';
import 'package:tkcms_common/tkcms_firestore.dart';
import 'package:tkcms_common/tkcms_flavor.dart';
import 'package:tkcms_common/tkcms_server.dart';

class FestenaoTestApiContext {
  final FestenaoApiService apiService;

  FestenaoTestApiContext({required this.apiService});

  @mustCallSuper
  Future<void> close() async {
    await apiService.close();
  }
}

class FestenaoTestAmpContext {
  final FestenaoAmpService ampService;

  FestenaoTestAmpContext({required this.ampService});

  @mustCallSuper
  Future<void> close() async {
    await ampService.close();
  }
}

class FestenaoTestFfServerContext {
  final FfServer? ffServer;

  FestenaoTestFfServerContext({required this.ffServer});

  @mustCallSuper
  Future<void> close() async {
    await ffServer?.close();
  }
}

class FestenaoTestServerContext
    implements
        FestenaoTestApiContext,
        FestenaoTestAmpContext,
        FestenaoTestFfServerContext {
  @override
  final FestenaoApiService apiService;
  @override
  final FestenaoAmpService ampService;
  @override
  final FfServer? ffServer;

  FestenaoTestServerContext({
    required this.apiService,
    this.ffServer,
    required this.ampService,
  });

  @override
  Future<void> close() async {
    //await ffServer.close();
    await apiService.close();
    await ffServer?.close();
    await ampService.close();
  }
}

Future<FestenaoTestServerContext> initFestenaoAllMemory() async {
  var ffServicesContext = await initFirebaseServicesSimMemory();
  var ffServerContext = await ffServicesContext.initServer();

  var httpClientFactory = httpClientFactoryMemory;
  var ff = ffServerContext.functions;
  var serverAppContext = TkCmsServerAppContext(
    firebaseContext: ffServerContext,
    flavorContext: FlavorContext.test,
  );
  var ffServerApp = FestenaoServerApp(context: serverAppContext);

  ffServerApp.initFunctions();
  //var httpServer = await ff.serveHttp();
  //var ffServer = FfServerHttp(httpServer);
  var ffServer = await ff.serve();
  var ffContext = firebaseFunctionsContextSimOrNull = await ffServicesContext
      .init(
        firebaseApp: ffServerContext.firebaseApp,
        ffServer: ffServer,
        serverApp: ffServerApp,
      );
  var commandUri = ffServer.uri.replace(path: ffServerApp.command);
  var apiService = FestenaoApiService(
    callableApi: ffContext.functionsCall.callable(ffServerApp.callCommand),
    httpClientFactory: httpClientFactory,
    httpsApiUri: commandUri,
    app: tkCmsAppDev,
  );
  await apiService.initClient();
  var ampUri = ffServer.uri.replace(path: ffServerApp.ampCommand);
  var ampService = FestenaoAmpService(
    httpsAmpUri: ampUri,
    httpClientFactory: httpClientFactory,
  );
  await ampService.initClient();

  return FestenaoTestServerContext(
    apiService: apiService,
    ffServer: ffServer,
    ampService: ampService,
  );
}

Future<void> main() async {
  debugWebServices = true;
  testFestenaoServerGroup(initFestenaoAllMemory);
}

void testFestenaoServerGroup(
  Future<FestenaoTestServerContext> Function() initAllContext,
) {
  late FestenaoTestServerContext context;
  late FestenaoApiService apiService;
  late FestenaoAmpService ampService;
  setUpAll(() async {
    context = await initAllContext();
    apiService = context.apiService;
    ampService = context.ampService;
  });
  tearDownAll(() async {
    await context.close();
  });

  test('amp', () async {
    var response = await ampService.client.get(ampService.pathUri(''));
    expect(response.statusCode, 200);
    expect(response.headers['content-type'], 'text/html; charset=utf-8');
  });

  test('callTimestamp', () async {
    if (apiService.callableApi != null) {
      var timestamp = await apiService.callGetTimestamp();
      expect(Timestamp.tryParse(timestamp.timestamp.v!), isNotNull);
      // ignore: avoid_print
      print(timestamp);
    }
  });
  test('echo', () async {
    var timestamp = (await apiService.getTimestamp()).timestamp.v!;
    var result = await apiService.echo(
      ApiEchoQuery()
        ..data.v = {'message': 'hello'}
        ..timestamp.v = timestamp,
    );
    expect(result.data.v, {'message': 'hello'});
    expect(result.timestamp.v, timestamp);
  });

  test('timestamp', () async {
    var timestamp = await apiService.getTimestamp();
    expect(Timestamp.tryParse(timestamp.timestamp.v!), isNotNull);
    // ignore: avoid_print
    print(timestamp);
  });
  test('httpTimestamp', () async {
    var timestamp = await apiService.httpGetTimestamp();
    expect(Timestamp.tryParse(timestamp.timestamp.v!), isNotNull);
    // ignore: avoid_print
    print(timestamp);
  });
}
