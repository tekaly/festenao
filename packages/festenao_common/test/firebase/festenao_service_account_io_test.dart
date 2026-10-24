@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:festenao_common/firebase/festenao_service_account_io.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

Map<String, Object?> _serviceAccount(String projectId, {String key = 'k1'}) => {
  'type': 'service_account',
  'project_id': projectId,
  'private_key_id': key,
  'private_key':
      '-----BEGIN PRIVATE KEY-----\nfake\n-----END PRIVATE KEY-----\n',
  'client_email': 'admin@$projectId.iam.gserviceaccount.com',
};

void main() {
  late Directory tempDir;
  late String dirPath;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('festenao_sa_');
    dirPath = join(tempDir.path, 'service_accounts');
  });
  tearDown(() async {
    await tempDir.delete(recursive: true);
  });

  test('env json', () async {
    var account = await festenaoServiceAccountFromEnv(
      environment: {
        festenaoServiceAccountEnvKey: jsonEncode(_serviceAccount('p1')),
      },
    );
    expect(account!.projectId, 'p1');
    expect(account.origin, FestenaoServiceAccountOrigin.env);
    expect(account.path, isNull);
    expect(account.source, '\$FESTENAO_SERVICE_ACCOUNT (environment)');
    expect(account.toString(), isNot(contains('PRIVATE KEY')));
  });

  test('env not set', () async {
    expect(await festenaoServiceAccountFromEnv(environment: {}), isNull);
    expect(
      await festenaoServiceAccountFromEnv(
        environment: {festenaoServiceAccountEnvKey: ' '},
      ),
      isNull,
    );
  });

  test('env path', () async {
    var path = await festenaoWriteServiceAccountFile(
      _serviceAccount('p1'),
      dirPath: dirPath,
    );
    expect(path, join(dirPath, 'p1.json'));
    var account = await festenaoServiceAccountFromEnv(
      environment: {festenaoServiceAccountEnvKey: path},
    );
    expect(account!.projectId, 'p1');
    expect(account.path, path);
    expect(account.origin, FestenaoServiceAccountOrigin.env);
  });

  test('env errors never quote the key', () async {
    var map = _serviceAccount('p1')..remove('client_email');
    await expectLater(
      festenaoServiceAccountFromEnv(
        environment: {festenaoServiceAccountEnvKey: jsonEncode(map)},
      ),
      throwsA(
        isA<StateError>().having(
          (e) => e.message,
          'message',
          allOf(contains('no client_email'), isNot(contains('PRIVATE KEY'))),
        ),
      ),
    );
    await expectLater(
      festenaoServiceAccountFromEnv(
        environment: {festenaoServiceAccountEnvKey: join(dirPath, 'none.json')},
      ),
      throwsA(isA<StateError>()),
    );
  });

  test('write, find and delete', () async {
    var p1Path = await festenaoWriteServiceAccountFile(
      _serviceAccount('p1'),
      dirPath: dirPath,
    );
    await festenaoWriteServiceAccountFile(
      _serviceAccount('p2'),
      dirPath: dirPath,
    );
    await File(join(dirPath, 'broken.json')).writeAsString('{');
    if (!Platform.isWindows) {
      var mode = File(p1Path).statSync().modeString();
      expect(mode, 'rw-------');
    }

    // The variable points to p1: listed once, as the variable.
    var found = await festenaoFindServiceAccounts(
      environment: {festenaoServiceAccountEnvKey: p1Path},
      dirPath: dirPath,
    );
    expect(found.accounts.map((account) => account.projectId), ['p1', 'p2']);
    expect(found.fromEnv!.projectId, 'p1');
    expect(found.accounts.first.origin, FestenaoServiceAccountOrigin.env);
    expect(found.errors, [contains('broken.json')]);

    // The same key in the variable as json: listed once too.
    found = await festenaoFindServiceAccounts(
      environment: {
        festenaoServiceAccountEnvKey: jsonEncode(_serviceAccount('p2')),
      },
      dirPath: dirPath,
    );
    expect(found.accounts.map((account) => account.source), [
      '\$FESTENAO_SERVICE_ACCOUNT (environment)',
      p1Path,
    ]);

    expect(
      await festenaoDeleteServiceAccountFile('p1', dirPath: dirPath),
      isTrue,
    );
    expect(
      await festenaoDeleteServiceAccountFile('p1', dirPath: dirPath),
      isFalse,
    );
    found = await festenaoFindServiceAccounts(
      environment: {},
      dirPath: dirPath,
    );
    expect(found.accounts.map((account) => account.projectId), ['p2']);
    expect(found.fromEnv, isNull);
  });

  test('local obfuscated file', () async {
    var localPath = join(tempDir.path, 'checkout', '.local', 'sa_enc.json');
    expect(await festenaoServiceAccountFromLocal(localPath: localPath), isNull);

    var written = await festenaoWriteServiceAccountEncFile(
      _serviceAccount('p3'),
      path: localPath,
    );
    expect(written, localPath);
    var content = File(localPath).readAsStringSync();
    expect(content, isNot(contains('PRIVATE KEY')));
    expect(content, contains('"project_id": "p3"'));
    expect(content, endsWith('}\n'));
    if (!Platform.isWindows) {
      expect(File(localPath).statSync().modeString(), 'rw-------');
    }

    // Read back decoded, from the local file, as a file, through the variable.
    var account = (await festenaoServiceAccountFromLocal(
      localPath: localPath,
    ))!;
    expect(account.origin, FestenaoServiceAccountOrigin.local);
    expect(account.map, _serviceAccount('p3'));
    expect(account.source, localPath);
    expect(account.path, localPath);
    expect((await festenaoReadServiceAccountFile(localPath)).map, account.map);
    expect(
      (await festenaoServiceAccountFromEnv(
        environment: {festenaoServiceAccountEnvKey: content},
      ))!.map,
      account.map,
    );

    // Found first, once: the variable points to it, the directory holds the
    // same key.
    await festenaoWriteServiceAccountFile(
      _serviceAccount('p3'),
      dirPath: dirPath,
    );
    await festenaoWriteServiceAccountFile(
      _serviceAccount('p1'),
      dirPath: dirPath,
    );
    var found = await festenaoFindServiceAccounts(
      environment: {festenaoServiceAccountEnvKey: localPath},
      dirPath: dirPath,
      localPath: localPath,
    );
    expect(found.accounts.map((account) => account.projectId), ['p3', 'p1']);
    expect(found.fromLocal!.source, localPath);
    expect(found.fromEnv, isNull);
    expect(found.errors, isEmpty);

    // A damaged local file is an error, the others are still found.
    File(localPath).writeAsStringSync(
      content.replaceFirst('"password": "', '"password": "x'),
    );
    found = await festenaoFindServiceAccounts(
      environment: {},
      dirPath: dirPath,
      localPath: localPath,
    );
    expect(found.accounts.map((account) => account.projectId), ['p1', 'p3']);
    expect(found.fromLocal, isNull);
    expect(found.errors, [
      allOf(
        startsWith(localPath),
        contains('does not decrypt'),
        isNot(contains('PRIVATE KEY')),
      ),
    ]);
  });

  test('write refuses a broken service account', () async {
    await expectLater(
      festenaoWriteServiceAccountFile({'project_id': 'p1'}, dirPath: dirPath),
      throwsArgumentError,
    );
    await expectLater(
      festenaoWriteServiceAccountEncFile({
        'project_id': 'p1',
      }, path: join(tempDir.path, 'enc.json')),
      throwsArgumentError,
    );
  });

  test('ds env', () async {
    var envFilePath = join(tempDir.path, 'env.yaml');
    var environment = {'TEKARTIK_PROCESS_RUN_USER_ENV_FILE_PATH': envFilePath};
    var json = jsonEncode(_serviceAccount('p1'));
    await festenaoSetServiceAccountDsEnv(json, environment: environment);

    Map<Object?, Object?> vars() =>
        (loadYaml(File(envFilePath).readAsStringSync()) as Map)['var'] as Map;
    // The json stays a string for the yaml file.
    expect(vars()[festenaoServiceAccountEnvKey], json);
    var account = await festenaoServiceAccountFromEnv(
      environment: {
        festenaoServiceAccountEnvKey:
            vars()[festenaoServiceAccountEnvKey] as String,
      },
    );
    expect(account!.projectId, 'p1');

    await festenaoSetServiceAccountDsEnv('~/sa.json', environment: environment);
    expect(vars()[festenaoServiceAccountEnvKey], '~/sa.json');

    await festenaoSetServiceAccountDsEnv(null, environment: environment);
    var content = loadYaml(File(envFilePath).readAsStringSync()) as Map;
    expect((content['var'] as Map?)?[festenaoServiceAccountEnvKey], isNull);
  });

  test('home path', () {
    expect(festenaoExpandHomePath('/a/b'), '/a/b');
    expect(festenaoExpandHomePath('~/a'), isNot(startsWith('~')));
  });

  test('gcloud project', () async {
    expect(festenaoGcloudProjectFromEnv(environment: {}), isNull);
    expect(
      festenaoGcloudProjectFromEnv(
        environment: {festenaoGcloudProjectEnvKey: ' p1 '},
      ),
      'p1',
    );

    // No application default credentials: said, the project still found.
    var adcPath = join(tempDir.path, 'adc.json');
    var environment = {
      festenaoGcloudProjectEnvKey: 'p1',
      'GOOGLE_APPLICATION_CREDENTIALS': adcPath,
    };
    expect(
      festenaoApplicationDefaultCredentialsPath(environment: environment),
      adcPath,
    );
    var found = await festenaoFindServiceAccounts(
      environment: environment,
      dirPath: dirPath,
    );
    expect(found.gcloudProjectId, 'p1');
    expect(found.accounts, isEmpty);
    expect(found.errors, [contains('gcloud auth application-default login')]);

    File(adcPath).writeAsStringSync('{"type": "authorized_user"}');
    found = await festenaoFindServiceAccounts(
      environment: environment,
      dirPath: dirPath,
    );
    expect(found.gcloudProjectId, 'p1');
    expect(found.errors, isEmpty);

    found = await festenaoFindServiceAccounts(
      environment: {},
      dirPath: dirPath,
    );
    expect(found.gcloudProjectId, isNull);
  });
}
