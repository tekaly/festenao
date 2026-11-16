@TestOn('vm')
library;

import 'dart:io';

import 'package:festenao_firebase/festenao_firebase_tools.dart';
import 'package:path/path.dart';
import 'package:test/test.dart';

void main() {
  test('festenaoWriteGeneratedFile', () async {
    var dir = Directory.systemTemp.createTempSync('festenao_firebase_tools');
    addTearDown(() => dir.deleteSync(recursive: true));
    var path = join(dir.path, 'firestore.rules');
    // Missing: written.
    expect(await festenaoWriteGeneratedFile(path, 'a'), isTrue);
    expect(File(path).readAsStringSync(), 'a');
    // Same text: up to date.
    expect(await festenaoWriteGeneratedFile(path, 'a'), isFalse);
    // Check only: would change, nothing written.
    expect(await festenaoWriteGeneratedFile(path, 'b', check: true), isTrue);
    expect(File(path).readAsStringSync(), 'a');
    expect(await festenaoWriteGeneratedFile(path, 'b'), isTrue);
    expect(File(path).readAsStringSync(), 'b');
  });
}
