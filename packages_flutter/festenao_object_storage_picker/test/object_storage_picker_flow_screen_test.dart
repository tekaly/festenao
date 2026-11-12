import 'dart:async';

import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_object_storage_picker/festenao_object_storage_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

/// A history answered when the test says so.
class _SlowHistory extends FolderHistorySdb {
  final completer = Completer<List<String>>();
  _SlowHistory() : super.inMemory();

  @override
  Future<List<String>> getLatestFolderIds() => completer.future;
}

class _NoStorage implements ObjectStorage {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('a history answered after the flow screen is gone', (
    tester,
  ) async {
    var history = _SlowHistory();
    await tester.pumpWidget(
      MaterialApp(
        home: ObjectStoragePickerFlowScreen(
          storage: _NoStorage(),
          sdb: history,
        ),
      ),
    );
    await tester.pumpWidget(const MaterialApp(home: Text('closed')));
    history.completer.complete(['folder1']);
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
