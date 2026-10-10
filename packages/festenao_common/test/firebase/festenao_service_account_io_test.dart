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

  test('write refuses a broken service account', () async {
    await expectLater(
      festenaoWriteServiceAccountFile({'project_id': 'p1'}, dirPath: dirPath),
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
}
