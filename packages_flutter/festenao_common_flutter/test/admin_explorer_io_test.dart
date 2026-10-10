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
}
