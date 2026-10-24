@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:festenao_common/firebase/festenao_service_account_io.dart';
import 'package:festenao_common_flutter/admin_explorer_flutter.dart';
import 'package:festenao_common_flutter/admin_explorer_io.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idb_shim/sdb.dart';

Map<String, Object?> _serviceAccount(String projectId) => {
  'type': 'service_account',
  'project_id': projectId,
  'private_key_id': 'k-$projectId',
  'private_key':
      '-----BEGIN PRIVATE KEY-----\nnot-a-key\n-----END PRIVATE KEY-----\n',
  'client_email': 'admin@$projectId.iam.gserviceaccount.com',
};

var _dbIndex = 0;

void main() {
  late Directory tempDir;
  late String dirPath;
  late AdminCredentialsDb db;
  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('admin_explorer_io_');
    dirPath = '${tempDir.path}${Platform.pathSeparator}service_accounts';
    db = await AdminCredentialsDb.open(
      sdbFactoryMemory,
      name: 'admin_io_${_dbIndex++}.db',
    );
  });
  tearDown(() async {
    await db.close();
    await tempDir.delete(recursive: true);
  });

  test('nothing found', () async {
    var found = await adminCredentialsImportFound(
      db,
      environment: {},
      dirPath: dirPath,
    );
    expect(found.accounts, isEmpty);
    expect(await db.list(), isEmpty);
    expect(await db.currentId(), isNull);
  });

  test('the variable and the files, the variable selected', () async {
    await festenaoWriteServiceAccountFile(
      _serviceAccount('p1'),
      dirPath: dirPath,
    );
    var found = await adminCredentialsImportFound(
      db,
      environment: {
        festenaoServiceAccountEnvKey: jsonEncode(_serviceAccount('p2')),
      },
      dirPath: dirPath,
    );
    expect(found.errors, isEmpty);
    var list = await db.list();
    expect(list.map((credentials) => credentials.displayName), [
      'p1 (file)',
      'p2 (\$FESTENAO_SERVICE_ACCOUNT)',
    ]);
    expect(await db.currentId(), adminCredentialsEnvId);
    expect((await db.current())!.projectId.v, 'p2');

    // Imported again: rewritten, not added.
    await adminCredentialsImportFound(
      db,
      environment: {
        festenaoServiceAccountEnvKey: jsonEncode(_serviceAccount('p3')),
      },
      dirPath: dirPath,
    );
    list = await db.list();
    expect(list, hasLength(2));
    expect((await db.current())!.projectId.v, 'p3');
  });

  test('the files only, the first selected when none is', () async {
    await festenaoWriteServiceAccountFile(
      _serviceAccount('p1'),
      dirPath: dirPath,
    );
    await adminCredentialsImportFound(db, environment: {}, dirPath: dirPath);
    expect(await db.currentId(), adminCredentialsFileId('p1'));

    // A pasted one selected stays selected.
    var id = await db.add(
      label: 'pasted',
      serviceAccount: jsonEncode(_serviceAccount('p9')),
    );
    await db.setCurrentId(id);
    await adminCredentialsImportFound(db, environment: {}, dirPath: dirPath);
    expect(await db.currentId(), id);
  });

  test(
    'the local file, selected over the variable, kept per project',
    () async {
      var localPath = '${tempDir.path}${Platform.pathSeparator}sa_enc.json';
      await festenaoWriteServiceAccountEncFile(
        _serviceAccount('p1'),
        path: localPath,
      );
      var found = await adminCredentialsImportFound(
        db,
        environment: {
          festenaoServiceAccountEnvKey: jsonEncode(_serviceAccount('p2')),
        },
        dirPath: dirPath,
        localPath: localPath,
      );
      expect(found.errors, isEmpty);
      expect(found.fromLocal!.projectId, 'p1');
      var list = await db.list();
      expect(list.map((credentials) => credentials.displayName), [
        'p1 (.local/service_account_enc.json)',
        'p2 (\$FESTENAO_SERVICE_ACCOUNT)',
      ]);
      expect(await db.currentId(), adminCredentialsLocalId('p1'));
      var current = (await db.current())!;
      expect(current.projectId.v, 'p1');
      // Kept decoded: the json of the service account itself.
      expect(current.serviceAccountMap, _serviceAccount('p1'));
      expect(current.serviceAccount.v, contains('PRIVATE KEY'));

      // Started from another folder: its account added, the first one kept.
      await festenaoWriteServiceAccountEncFile(
        _serviceAccount('p3'),
        path: localPath,
      );
      await adminCredentialsImportFound(
        db,
        environment: {},
        dirPath: dirPath,
        localPath: localPath,
      );
      list = await db.list();
      expect(list.map((credentials) => credentials.displayName), [
        'p1 (.local/service_account_enc.json)',
        'p2 (\$FESTENAO_SERVICE_ACCOUNT)',
        'p3 (.local/service_account_enc.json)',
      ]);
      expect(await db.currentId(), adminCredentialsLocalId('p3'));

      // No local file: the previous selection stays.
      File(localPath).deleteSync();
      await adminCredentialsImportFound(
        db,
        environment: {},
        dirPath: dirPath,
        localPath: localPath,
      );
      expect(await db.currentId(), adminCredentialsLocalId('p3'));
    },
  );

  test('the obfuscated json pasted', () async {
    var enc = festenaoServiceAccountEncMap(_serviceAccount('p1'));
    expect(adminServiceAccountError(jsonEncode(enc)), isNull);
    expect(adminServiceAccountProjectId(jsonEncode(enc)), 'p1');
    expect(adminServiceAccountMap(jsonEncode(enc)), _serviceAccount('p1'));
    var damaged = jsonEncode({...enc, 'password': 'x' * 32});
    expect(adminServiceAccountError(damaged), contains('does not decrypt'));
    expect(adminServiceAccountMap(damaged), isNull);
  });

  test('the gcloud project, selected over the variable', () async {
    var adcPath = '${tempDir.path}${Platform.pathSeparator}adc.json';
    File(adcPath).writeAsStringSync('{"type": "authorized_user"}');
    var found = await adminCredentialsImportFound(
      db,
      environment: {
        festenaoGcloudProjectEnvKey: 'p1',
        'GOOGLE_APPLICATION_CREDENTIALS': adcPath,
        festenaoServiceAccountEnvKey: jsonEncode(_serviceAccount('p2')),
      },
      dirPath: dirPath,
    );
    expect(found.errors, isEmpty);
    expect(found.gcloudProjectId, 'p1');
    var list = await db.list();
    expect(list.map((credentials) => credentials.displayName), [
      'p1 (\$FESTENAO_GCLOUD_PROJECT)',
      'p2 (\$FESTENAO_SERVICE_ACCOUNT)',
    ]);
    expect(await db.currentId(), adminCredentialsGcloudEnvId);
    var current = (await db.current())!;
    expect(current.isGcloud, isTrue);
    expect(current.projectId.v, 'p1');
    expect(current.serviceAccount.v, isEmpty);
  });
}
