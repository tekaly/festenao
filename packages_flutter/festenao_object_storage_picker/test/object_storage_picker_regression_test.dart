import 'dart:async';

import 'package:festenao_common/data/object_storage.dart';
import 'package:festenao_object_storage_picker/festenao_object_storage_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

class _Meta implements ObjectStorageMeta {
  @override
  final String name;
  @override
  final String path;
  @override
  final bool isLocation;
  _Meta(this.path, {this.isLocation = false}) : name = path.split('/').last;
  @override
  String? get mimeType => isLocation ? null : 'image/png';
  @override
  DateTime? get modified => null;
  @override
  int? get size => isLocation ? null : 1024;
}

class _Response implements ObjectStorageListResponse {
  @override
  final List<ObjectStorageMeta> items;
  @override
  final String? nextPageToken;
  _Response(this.items, this.nextPageToken);
}

/// A storage whose listing is answered by [onList], one page per call.
class _FakeStorage implements ObjectStorage {
  final Future<ObjectStorageListResponse> Function(String path, String? token)
  onList;
  var listCount = 0;
  _FakeStorage(this.onList);
  @override
  Future<ObjectStorageListResponse> list(
    String path, {
    String? pageToken,
    int? maxResults,
  }) {
    listCount++;
    return onList(path, pageToken);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('a listing answered after the picker is gone', (tester) async {
    var completer = Completer<ObjectStorageListResponse>();
    var storage = _FakeStorage((_, _) => completer.future);
    await tester.pumpWidget(
      _app(
        ObjectStoragePicker(
          storage: storage,
          parentPath: 'root',
          onSelect: (_) {},
        ),
      ),
    );
    await tester.pumpWidget(_app(const Text('closed')));
    completer.complete(_Response([_Meta('root/a.png')], null));
    await tester.pump();
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('the last folder opened wins over a slower listing', (
    tester,
  ) async {
    var completers = <String, Completer<ObjectStorageListResponse>>{};
    var storage = _FakeStorage(
      (path, _) => (completers[path] = Completer()).future,
    );
    await tester.pumpWidget(
      _app(
        ObjectStoragePicker(
          storage: storage,
          parentPath: 'root',
          onSelect: (_) {},
        ),
      ),
    );
    completers['root']!.complete(
      _Response([_Meta('root/sub', isLocation: true)], null),
    );
    await tester.pump();
    await tester.tap(find.text('sub'));
    await tester.pump();
    // Back to the root before the sub folder answers
    await tester.tap(find.text('Root'));
    await tester.pump();
    completers['root']!.complete(
      _Response([_Meta('root/sub', isLocation: true)], null),
    );
    await tester.pump();
    completers['root/sub']!.complete(
      _Response([_Meta('root/sub/x.png')], null),
    );
    await tester.pump();
    expect(find.text('x.png'), findsNothing);
    expect(find.text('sub'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('a selection survives a folder reload', (tester) async {
    var storage = _FakeStorage(
      (path, _) async => path == 'root'
          ? _Response([
              _Meta('root/a.png'),
              _Meta('root/sub', isLocation: true),
            ], null)
          : _Response([_Meta('root/sub/b.png')], null),
    );
    List<ObjectStorageMeta>? selected;
    await tester.pumpWidget(
      _app(
        ObjectStoragePicker(
          storage: storage,
          parentPath: 'root',
          allowMultiSelect: true,
          onSelect: (items) => selected = items,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('a.png'));
    await tester.pump();
    expect(find.text('1 items selected'), findsOneWidget);
    await tester.tap(find.text('sub'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Root'));
    await tester.pumpAndSettle();
    // Still shown selected, a second tap unselects it
    expect(tester.widget<Checkbox>(find.byType(Checkbox).first).value, isTrue);
    await tester.tap(find.text('a.png'));
    await tester.pump();
    expect(find.text('0 items selected'), findsOneWidget);
    await tester.tap(find.text('a.png'));
    await tester.pump();
    await tester.tap(find.text('Select'));
    expect(selected?.map((item) => item.path), ['root/a.png']);
  }, timeout: const Timeout(Duration(seconds: 30)));

  testWidgets('every page of a folder is listed', (tester) async {
    var storage = _FakeStorage(
      (path, token) async => token == null
          ? _Response([_Meta('root/a.png')], 'page2')
          : _Response([_Meta('root/b.png')], null),
    );
    await tester.pumpWidget(
      _app(
        ObjectStoragePicker(
          storage: storage,
          parentPath: 'root',
          onSelect: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('a.png'), findsOneWidget);
    expect(find.text('b.png'), findsOneWidget);
  }, timeout: const Timeout(Duration(seconds: 30)));
}
